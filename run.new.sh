#!/usr/bin/env bash
set -euo pipefail

: "${db:=/data/c2.db}"

args=()

# Hostname: prefer $fqdn, else pod info, else system hostname
if [[ -n "${fqdn:-}" ]]; then
  args+=("-hostname" "$fqdn")
elif [[ -n "${POD_IP:-}" ]]; then
  args+=("-hostname" "$POD_IP")
elif [[ -n "${POD_NAME:-}" ]]; then
  args+=("-hostname" "$POD_NAME")
else
  args+=("-hostname" "$(hostname -f 2>/dev/null || hostname)")
fi

# Regular (non-secret) flags
[[ -n "${certFile:-}"         ]] && args+=("-certFile"         "$certFile")
[[ -n "${keyFile:-}"          ]] && args+=("-keyFile"          "$keyFile")
[[ -n "${db:-}"               ]] && args+=("-db"               "$db")
[[ -n "${setEdition:-}"       ]] && args+=("-setEdition"       "$setEdition")
[[ -n "${listenip:-}"         ]] && args+=("-listenip"         "$listenip")
[[ -n "${listenport:-}"       ]] && args+=("-listenport"       "$listenport")
[[ -n "${sshport:-}"          ]] && args+=("-sshport"          "$sshport")
[[ -n "${reverseProxy:-}"     ]] && args+=("-reverseProxy")
[[ -n "${reverseProxyPort:-}" ]] && args+=("-reverseProxyPort" "$reverseProxyPort")
[[ -n "${https:-}"            ]] && args+=("-https")

# Secrets / sensitive flags
# - License key (program license)
if [[ -n "${setLicenseKey:-}" ]]; then
  args+=("-setLicenseKey" "$setLicenseKey")
fi
# - Account recovery flow (username + new password)
if [[ -n "${recoverAccount:-}" ]]; then
  args+=("-recoverAccount" "$recoverAccount")
fi
if [[ -n "${setPass:-}" ]]; then
  args+=("-setPass" "$setPass")
fi

# Verbose/debug controls
[[ -n "${debug:-}"   ]] && args+=("-debug")
[[ -n "${v:-}"       ]] && args+=("-v")           # set env v=1 to enable -v
[[ -n "${verbose:-}" ]] && args+=("-v")           # or verbose=1

# Print a sanitized summary (don’t leak secrets)
masked_args=()
skip_next_val=""
for ((i=0; i<${#args[@]}; i++)); do
  tok="${args[$i]}"
  case "$tok" in
    -setLicenseKey|-setPass|-recoverAccount)
      masked_args+=("$tok" "****")
      ((i++)) || true
      ;;
    *)
      masked_args+=("$tok")
      ;;
  esac
done
echo "using following settings:" "${masked_args[@]}"

# Exec for proper signal handling in k8s
exec /app/c2_community-linux-64 "${args[@]}"
