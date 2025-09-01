# Hak5 Cloud C2 – Distroless Docker Image (Multi-Stage, K8s-Friendly)

This project builds a **minimal, non-root, distroless** container for Hak5 Cloud C2 with a tiny Go entrypoint that maps **environment variables → Cloud C2 flags**. It’s designed for Docker/Podman and seamless Kubernetes deployment (Traefik v3 CRDs, probes, non-root, PVC for DB).

> ⚠️ You are responsible for complying with Hak5 Cloud C2 licensing and EULA. This image downloads the official archive **during build** from Hak5’s endpoint; no C2 binaries are stored in this repo.

---

## How it's built

- **Multi-stage build**
  - **fetch**: downloads & extracts the right `c2-*_{TARGET}` binary
  - **wrap**: compiles a tiny Go entrypoint that converts env vars to C2 flags
  - **final**: `distroless:nonroot` runtime (no shell, tiny attack surface)

- **Non-root** (uid 65532), **read-only-friendly**, **PVC-ready** via `/data`(or configurable location).

- **Kubernetes-friendly**
  - env→flag entrypoints placed in configmap.yaml(no wrapper script needed)
  - compatible with HTTP probes and Traefik v3 IngressRoute/IngressRouteTCP
  - single-replica guidance (SQLite DB on PVC)
  - Use secrets for secure variables (SSL/TLS keys, product licensing, initial user credentials)

---

## Build arguments

| Arg              | Example                  | Purpose                                                  |
|------------------|--------------------------|----------------------------------------------------------|
| `RELEASE`        | `latest` or `3.4.0-stable` | Which Cloud C2 archive to fetch                          |
| `TARGET`         | `amd64_linux`, `arm64_linux`, … | Which platform binary to copy                             |
| `ALPINE_MIRROR`  | `http://mirrors.ocf.berkeley.edu` | (fetch stage only) Faster APK mirror for reliability     |


## Runtime environment variables → C2 flags

Set these as container env vars; the entrypoint turns them into Cloud C2 install CLI arguments.

| Env var            | Maps to flag        | Type    | Default       | Notes                                                                                 |
| ------------------ | ------------------- | ------- | ------------- | ------------------------------------------------------------------------------------- |
| `fqdn`             | `-hostname`         | string  | (auto)        | Preferred host name; otherwise falls back to `POD_IP` → `POD_NAME` → system hostname. |
| `db`               | `-db`               | string  | `/data/c2.db` | SQLite DB path (PVC-backed in k8s examples).                                          |
| `certFile`         | `-certFile`         | string  | —             | Path to TLS cert **inside the container**.                                            |
| `keyFile`          | `-keyFile`          | string  | —             | Path to TLS key **inside the container**.                                             |
| `setEdition`       | `-setEdition`       | string  | —             | Optional; edition string if needed.                                                   |
| `listenip`         | `-listenip`         | string  | —             | e.g., `0.0.0.0`.                                                                      |
| `listenport`       | `-listenport`       | string  | —             | HTTP listener port (container exposes 8080).                                          |
| `sshport`          | `-sshport`          | string  | `2022`        | SSH relay port (container exposes 2022).                                              |
| `reverseProxy`     | `-reverseProxy`     | boolean | off           | Presence enables reverse-proxy mode (use when behind Traefik/NGINX).                  |
| `reverseProxyPort` | `-reverseProxyPort` | string  | —             | Only if your reverse proxy listens on a nonstandard port.                             |
| `https`            | `-https`            | boolean | off\*         | Auto-enabled if both `certFile` & `keyFile` exist and are readable.                   |
| `publicIP`         | `-publicIP`         | string  | —             | Optional public IP hint.                                                              |
| `publicHostname`   | `-publicHostname`   | string  | —             | Optional public hostname hint.                                                        |
| `bindInterface`    | `-bindInterface`    | string  | —             | Bind to a specific NIC.                                                               |
| `setLicenseKey`    | `-setLicenseKey`    | secret  | —             | **Sensitive**; masked in logs.                                                        |
| `recoverAccount`   | `-recoverAccount`   | secret  | —             | **Sensitive**; masked in logs.                                                        |
| `setPass`          | `-setPass`          | secret  | —             | **Sensitive**; masked in logs.                                                        |
| `debug`            | `-debug`            | boolean | off           | Presence enables debug.                                                               |
| `v` / `verbose`    | `-v`                | boolean | off           | Presence enables verbose logging.                                                     |
| `C2_EXTRA`         | (verbatim split)    | string  | —             | Space-separated flags appended as-is for future additions.                            |

Auto-https: if https is unset, but both certFile and keyFile exist, the entrypoint adds -https automatically.

## Local usage (Docker)

`
docker run -d --name cloudc2 \
  -p 8080:8080 -p 2022:2022 \
  -v c2-data:/data \
  -e fqdn=localhost \
  --restart unless-stopped \
  joshuapfritz/hak5c2:latest
`

### Run (HTTP only, no reverse proxy)

`
docker run -d --name cloudc2 \
  -p 8080:8080 -p 2022:2022 \
  -v c2-data:/data \
  -v $(pwd)/certs:/tls:ro \
  -e certFile=/tls/tls.crt \
  -e keyFile=/tls/tls.key \
  --restart unless-stopped \
  joshuapfritz/hak5c2:latest
`

Distroless has no shell. Change configuration via env vars and recreate the container.
If bind-mounting a host path for /data, ensure it’s writable by uid 65532.

#### Security notes

- The final image is distroless:nonroot (tiny surface, no shell, no package manager).
- Scanners may flag the builder stage. Use one of:
`FROM cgr.dev/chainguard/go:1.22 AS wrap (often 0 CVEs)`
or pin a patched tag:
`golang:1.22.7-alpine3.21 / golang:1.22.7-bookworm`

You can emit SBOM/provenance on build:

```bash
docker buildx build --sbom=true --provenance=true -t yourrepo/cloudc2:dev .
```
