# --- fetch stage: download & extract Cloud C2 archive ---
FROM alpine:3.21.3 AS fetch
ARG RELEASE=latest
ARG TARGET=amd64_linux
# let you override at build: --build-arg ALPINE_MIRROR=http://mirrors.ocf.berkeley.edu
ARG ALPINE_MIRROR=http://dl-cdn.alpinelinux.org

# cache apk + set repos explicitly (HTTP is fine; apk verifies signatures)
RUN --mount=type=cache,target=/var/cache/apk set -eux; \
    printf '%s/alpine/v3.21/main\n%s/alpine/v3.21/community\n' \
      "${ALPINE_MIRROR}" "${ALPINE_MIRROR}" > /etc/apk/repositories; \
    apk add --no-cache ca-certificates wget unzip

# robust download (progress + retries)
ARG URL="https://downloads.hak5.org/api/devices/cloudc2/firmwares/${RELEASE}"
ARG WGET_OPTS="--server-response --progress=dot:giga --tries=20 --timeout=30 \
               --waitretry=5 --read-timeout=300 --retry-connrefused --continue"
RUN set -eux; echo "Downloading: ${URL}"; wget ${WGET_OPTS} -O /tmp/cloudc2.zip "${URL}"

RUN set -eux; \
    unzip -d /tmp /tmp/cloudc2.zip; \
    C2_BIN="$(find /tmp -maxdepth 1 -type f -name "c2-*_${TARGET}" | head -n1)"; \
    test -n "$C2_BIN"; \
    cp "$C2_BIN" /tmp/c2; \
    chmod +x /tmp/c2

# --- build stage: compile a tiny entrypoint (env -> flags, then exec /app/c2) ---
# --- secure builder ---
FROM cgr.dev/chainguard/go:latest AS wrap
WORKDIR /src
COPY <<'EOF' /src/main.go
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
)

func getenv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func add(args *[]string, flag, val string) {
	if val != "" {
		*args = append(*args, flag, val)
	}
}

func main() {
	// Defaults
	db := getenv("db", "/data/c2.db")

	// Hostname selection: fqdn > POD_IP > POD_NAME > system hostname
	hostname := os.Getenv("fqdn")
	if hostname == "" {
		hostname = os.Getenv("POD_IP")
	}
	if hostname == "" {
		hostname = os.Getenv("POD_NAME")
	}
	if hostname == "" {
		if h, err := os.Hostname(); err == nil && h != "" {
			hostname = h
		} else {
			hostname = "localhost"
		}
	}

	// Ensure DB dir exists
	_ = os.MkdirAll(filepath.Dir(db), 0o700)

	args := []string{"-hostname", hostname}

	// Regular (value) flags
	add(&args, "-certFile", os.Getenv("certFile"))
	add(&args, "-keyFile", os.Getenv("keyFile"))
	add(&args, "-db", db)
	add(&args, "-setEdition", os.Getenv("setEdition"))
	add(&args, "-listenip", os.Getenv("listenip"))
	add(&args, "-listenport", os.Getenv("listenport"))
	add(&args, "-sshport", os.Getenv("sshport"))
	add(&args, "-reverseProxyPort", os.Getenv("reverseProxyPort"))
	add(&args, "-publicIP", os.Getenv("publicIP"))
	add(&args, "-publicHostname", os.Getenv("publicHostname"))
	add(&args, "-bindInterface", os.Getenv("bindInterface"))

	// Booleans (presence → enabled)
	if os.Getenv("reverseProxy") != "" { args = append(args, "-reverseProxy") }
	if os.Getenv("https") != ""       { args = append(args, "-https") }
	if os.Getenv("debug") != ""       { args = append(args, "-debug") }
	if os.Getenv("v") != "" || os.Getenv("verbose") != "" { args = append(args, "-v") }

	// Auto-enable https when both files exist and https not explicitly set
	if os.Getenv("https") == "" {
		if cf, kf := os.Getenv("certFile"), os.Getenv("keyFile"); cf != "" && kf != "" {
			if _, err1 := os.Stat(cf); err1 == nil {
				if _, err2 := os.Stat(kf); err2 == nil {
					args = append(args, "-https")
				}
			}
		}
	}

	// Secrets
	if v := os.Getenv("setLicenseKey"); v != "" { args = append(args, "-setLicenseKey", v) }
	if v := os.Getenv("recoverAccount"); v != "" { args = append(args, "-recoverAccount", v) }
	if v := os.Getenv("setPass"); v != "" { args = append(args, "-setPass", v) }

	// Escape hatch for new upstream flags
	if extra := strings.TrimSpace(os.Getenv("C2_EXTRA")); extra != "" {
		args = append(args, strings.Fields(extra)...)
	}

	// Masked log (don’t leak secrets)
	masked := []string{}
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "-setLicenseKey", "-setPass", "-recoverAccount":
			masked = append(masked, args[i], "****")
			i++
		default:
			masked = append(masked, args[i])
		}
	}
	fmt.Println("Starting Cloud C2 with:", strings.Join(masked, " "))

	// Exec /app/c2 with inherited env
	c2 := "/app/c2"
	if err := syscall.Exec(c2, append([]string{c2}, args...), os.Environ()); err != nil {
		// Fallback via exec.Command to capture error
		cmd := exec.Command(c2, args...)
		cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
		_ = cmd.Run()
		os.Exit(1)
	}
}
EOF
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /entrypoint /src/main.go

# --- final stage: distroless (no shell, non-root) ---
FROM gcr.io/distroless/static:nonroot
WORKDIR /app
# copy binaries
COPY --from=fetch --chown=65532:65532 /tmp/c2 /app/c2
COPY --from=wrap  --chown=65532:65532 /entrypoint /app/entrypoint
# declare data volume (db default path)
VOLUME ["/data"]
EXPOSE 8080 2022
ENTRYPOINT ["/app/entrypoint"]
