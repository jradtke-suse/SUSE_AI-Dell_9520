#!/usr/bin/env bash
# Bootstrap a fresh SLES 16 install so Ansible can take over.
# Usage: sudo REGCODE=xxxx [EMAIL=you@example.com] ./scripts/00-bootstrap.sh
set -euo pipefail

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root (sudo)."

# --- Sanity check: SLES 16 ---
. /etc/os-release
[[ "${ID:-}" == "sles" && "${VERSION_ID%%.*}" == "16" ]] \
  || die "Expected SLES 16, found ${PRETTY_NAME:-unknown}."
log "Running on ${PRETTY_NAME}"

# --- Registration ---
if SUSEConnect --status-text 2>/dev/null | grep -q 'Registered'; then
  log "Already registered with SCC"
elif [[ -n "${REGCODE:-}" ]]; then
  log "Registering with SCC"
  SUSEConnect -r "${REGCODE}" ${EMAIL:+-e "$EMAIL"}
else
  log "REGCODE not set, so registration is skipped (repos may be unavailable)"
fi

# --- Update + prerequisites ---
log "Refreshing repos and updating system"
zypper --non-interactive --gpg-auto-import-keys refresh
zypper --non-interactive update -y

log "Installing bootstrap packages"
zypper --non-interactive install -y git python3 ansible

log "Done. Next steps:"
cat <<'EOF'
  cd ansible
  ansible-galaxy collection install -r requirements.yml
  ansible-playbook site.yml --tags base
  ansible-playbook site.yml --tags nvidia   # then reboot
EOF

[[ -f /run/reboot-needed ]] && log "A reboot is recommended (kernel/core updates applied)."
exit 0
