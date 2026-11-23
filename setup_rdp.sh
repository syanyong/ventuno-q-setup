#!/usr/bin/env bash
# Turn on Remote Desktop (RDP) on an Arduino VENTUNO Q, no monitor needed.
# Usage:  sudo ./setup_rdp.sh            set up (asks before each change)
#         sudo ./setup_rdp.sh --status   show current state only
#         sudo ./setup_rdp.sh --disable  turn RDP off again
set -euo pipefail

FLAG=/var/lib/arduino-desktop-customization/distribution_terms_not_confirmed
GRD_DIR=/var/lib/gnome-remote-desktop
KEY=$GRD_DIR/rdp-tls.key
CRT=$GRD_DIR/rdp-tls.crt

ok()   { printf '\e[32m[ OK ]\e[0m %s\n' "$*"; }
info() { printf '\e[36m[INFO]\e[0m %s\n' "$*"; }
warn() { printf '\e[33m[WARN]\e[0m %s\n' "$*"; }
die()  { printf '\e[31m[FAIL]\e[0m %s\n' "$*" >&2; exit 1; }

if [[ $EUID -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

command -v grdctl >/dev/null || die "grdctl not found (gnome-remote-desktop is not installed)"

show_status() {
  echo "---- Ubuntu ----"; . /etc/os-release; echo "$PRETTY_NAME"
  echo "---- distribution terms ----"
  [[ -f $FLAG ]] && echo "NOT accepted (desktop is blocked)" || echo "accepted"
  echo "---- gdm ----"; systemctl is-active gdm || true
  echo "---- RDP ----"; grdctl --system status 2>/dev/null | sed -n '1,6p'
  echo "---- port 3389 ----"
  ss -ltn | grep -q ':3389 ' && echo "listening" || echo "not listening"
  echo "---- board IP ----"; hostname -I
}

case "${1:-}" in
  --status)  show_status; exit 0 ;;
  --disable) grdctl --system rdp disable
             systemctl restart gnome-remote-desktop
             ok "RDP disabled"; exit 0 ;;
  "")        ;;
  *)         die "unknown option: $1 (use --status or --disable)" ;;
esac

# ---- Step 1: distribution terms --------------------------------------------
# Before the login screen starts, Arduino shows a "Confirm" page.
# With no monitor it can never be clicked, so the desktop never starts.
# The Confirm button only deletes the flag file below.
echo
echo "== Step 1/3: distribution terms =="
if [[ -f $FLAG ]]; then
  echo
  echo "  This device is preloaded with the Ubuntu operating system,"
  echo "  which is provided by Canonical Ltd."
  echo
  read -rp "  Accept (same as pressing Confirm on a monitor)? [y/N] " a
  [[ ${a,,} == y* ]] || die "Not accepted. Nothing was changed."
  rm -f "$FLAG"
  ok "terms accepted"
  info "waiting for the login screen (gdm) to start..."
  for _ in $(seq 1 20); do
    systemctl is-active --quiet gdm && break
    sleep 1
  done
  systemctl is-active --quiet gdm || { systemctl restart gdm; sleep 5; }
else
  ok "terms already accepted"
fi
systemctl is-active --quiet gdm && ok "gdm is running" || warn "gdm is not running yet: check 'systemctl status gdm'"

# ---- Step 2: TLS certificate -------------------------------------------------
echo
echo "== Step 2/3: TLS certificate =="
if [[ -s $KEY && -s $CRT ]]; then
  ok "certificate already exists"
else
  mkdir -p "$GRD_DIR"
  openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj "/CN=$(hostname)" -keyout "$KEY" -out "$CRT" 2>/dev/null
  ok "certificate created"
fi
chown gnome-remote-desktop:gnome-remote-desktop "$KEY" "$CRT"
chmod 600 "$KEY"
grdctl --system rdp set-tls-key "$KEY"
grdctl --system rdp set-tls-cert "$CRT"

# ---- Step 3: RDP user and password -------------------------------------------
echo
echo "== Step 3/3: RDP login =="
echo "  This is the first login box on the laptop (Remote Desktop Connection)."
echo "  After it, you still log in to Ubuntu as usual."
default_user=${SUDO_USER:-arduino}
read -rp "  RDP user [$default_user]: " U
U=${U:-$default_user}
while true; do
  read -rsp "  RDP password: " P; echo
  read -rsp "  Again: " P2; echo
  [[ -n $P && $P == "$P2" ]] && break
  warn "empty or not the same, try again"
done
grdctl --system rdp set-credentials "$U" "$P"
unset P P2

grdctl --system rdp enable
systemctl enable gnome-remote-desktop >/dev/null 2>&1 || true
systemctl restart gnome-remote-desktop

if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  ufw allow 3389/tcp >/dev/null && ok "firewall: port 3389 opened"
fi

for _ in $(seq 1 10); do
  ss -ltn | grep -q ':3389 ' && break
  sleep 1
done

echo
if ss -ltn | grep -q ':3389 '; then
  ok "RDP is on (port 3389)"
else
  warn "port 3389 is not listening yet: run 'sudo ./setup_rdp.sh --status' in a few seconds"
fi
echo
echo "Connect from your laptop:"
for ip in $(hostname -I); do
  [[ $ip == *:* ]] || echo "    $ip"
done
echo "  Windows: Remote Desktop Connection (mstsc)"
echo "  macOS:   Windows App (App Store)"
echo "  Linux:   Remmina"
echo "  1) RDP login: $U and the password you just set"
echo "  2) Ubuntu login screen: your normal Ubuntu user"
