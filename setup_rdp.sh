#!/usr/bin/env bash
# Turn on Remote Desktop (RDP) on an Arduino VENTUNO Q (Ubuntu 24.04, GNOME 46).
#
#   sudo ./setup_rdp.sh            ask the mode, show the plan, confirm, then set up
#   sudo ./setup_rdp.sh --status   show the current state only (changes nothing)
#   sudo ./setup_rdp.sh --fix      fix a black screen after RDP login
#   sudo ./setup_rdp.sh --disable  turn RDP off (both modes)
#
# Mode 1  No HDMI : "Remote Login". The laptop gets its own Ubuntu login
#                   screen. Works with no monitor at all.
# Mode 2  HDMI    : "Desktop Sharing". The laptop sees the same desktop that
#                   is on the monitor. Someone must be logged in on the monitor.
set -euo pipefail

FLAG=/var/lib/arduino-desktop-customization/distribution_terms_not_confirmed
SYS_DIR=/var/lib/gnome-remote-desktop

ok()   { printf '\e[32m[ OK ]\e[0m %s\n' "$*"; }
info() { printf '\e[36m[INFO]\e[0m %s\n' "$*"; }
warn() { printf '\e[33m[WARN]\e[0m %s\n' "$*"; }
die()  { printf '\e[31m[FAIL]\e[0m %s\n' "$*" >&2; exit 1; }
ask_yes() { local a; read -rp "$1 [y/N] " a; [[ ${a,,} == y* ]]; }

[[ $EUID -eq 0 ]] || exec sudo "$0" "$@"
command -v grdctl >/dev/null || die "grdctl not found (gnome-remote-desktop is not installed)"

DESK_USER=${SUDO_USER:-arduino}
DESK_UID=$(id -u "$DESK_USER")
DESK_HOME=$(getent passwd "$DESK_USER" | cut -d: -f6)
USER_DIR=$DESK_HOME/.local/share/gnome-remote-desktop

# run a command as the desktop user, inside their GNOME session
as_user() {
  sudo -u "$DESK_USER" XDG_RUNTIME_DIR=/run/user/$DESK_UID \
    DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$DESK_UID/bus "$@"
}

listening() { ss -ltn | grep -q ":$1 "; }

# /tmp/.X11-unix must belong to root. On a fresh board it can end up owned
# by gdm, and then the desktop crashes right after login over RDP
# (gnome-shell: "Wrong ownership for directory /tmp/.X11-unix").
fix_tmp_dirs() {
  local d fixed=0
  for d in /tmp/.X11-unix /tmp/.ICE-unix; do
    [[ -d $d ]] || continue
    if [[ $(stat -c %U "$d") != root ]]; then
      chown root:root "$d"; chmod 1777 "$d"; fixed=1
    fi
  done
  return $((1 - fixed))   # 0 = something was fixed
}

show_status() {
  . /etc/os-release
  echo "Ubuntu         : $PRETTY_NAME"
  echo "Terms          : $([[ -f $FLAG ]] && echo 'NOT accepted (desktop blocked)' || echo accepted)"
  echo "gdm            : $(systemctl is-active gdm || true)"
  echo "No-HDMI mode   : $(grdctl --system status 2>/dev/null | awk '/Status:/{print $2; exit}')"
  echo "HDMI mode      : $(as_user grdctl status 2>/dev/null | awk '/Status:/{print $2; exit}')"
  echo "Port 3389      : $(listening 3389 && echo listening || echo closed)"
  echo "Port 3390      : $(listening 3390 && echo listening || echo closed)"
  echo "/tmp/.X11-unix : owner $(stat -c %U /tmp/.X11-unix 2>/dev/null || echo missing) (must be root)"
  echo "Board IP       : $(hostname -I)"
}

case "${1:-}" in
  --status)  show_status; exit 0 ;;
  --fix)     if fix_tmp_dirs; then systemctl restart gdm; ok "fixed /tmp/.X11-unix owner, gdm restarted"; else ok "nothing to fix"; fi
             exit 0 ;;
  --disable) grdctl --system rdp disable 2>/dev/null || true
             as_user grdctl rdp disable 2>/dev/null || true
             systemctl restart gnome-remote-desktop || true
             ok "RDP disabled"; exit 0 ;;
  "")        ;;
  *)         die "unknown option: $1 (use --status, --fix or --disable)" ;;
esac

make_cert() {   # make_cert <dir> <owner>
  local d=$1 o=$2
  mkdir -p "$d"
  if [[ ! -s $d/rdp-tls.key || ! -s $d/rdp-tls.crt ]]; then
    openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
      -subj "/CN=$(hostname)" -keyout "$d/rdp-tls.key" -out "$d/rdp-tls.crt" 2>/dev/null
  fi
  chown -R "$o" "$d"
  chmod 600 "$d/rdp-tls.key"
}

# ---- choose mode ---------------------------------------------------------------
echo
echo "Remote Desktop setup for $(hostname)"
echo
echo "  1) No HDMI : no monitor on the board. The laptop gets its own login screen."
echo "  2) HDMI    : a monitor is plugged in and someone is logged in on it."
echo "               The laptop sees the same desktop as the monitor."
echo
read -rp "Choose 1 or 2: " MODE
[[ $MODE == 1 || $MODE == 2 ]] || die "please answer 1 or 2"

if [[ $MODE == 2 ]]; then
  loginctl list-sessions --no-legend | awk -v u="$DESK_USER" '$3==u' | \
    while read -r sid _; do loginctl show-session "$sid" -p Type --value; done | \
    grep -qE 'x11|wayland' || die "No desktop session for '$DESK_USER'. Log in on the monitor first, or use mode 1."
fi

# ---- show the plan and confirm -----------------------------------------------------
echo
echo "This will:"
[[ -f $FLAG ]] && echo "  - accept the Ubuntu distribution terms (same as pressing Confirm on a monitor)"
echo "  - create a TLS certificate for GNOME Remote Desktop"
echo "  - set an RDP user and password (you type them next)"
if [[ $MODE == 1 ]]; then
  echo "  - turn on Remote Login (system mode), port 3389"
else
  echo "  - turn on Desktop Sharing for user '$DESK_USER' (port 3389, or 3390 if 3389 is taken)"
fi
echo
ask_yes "Continue?" || die "Stopped. Nothing was changed."

# ---- step 1: distribution terms ---------------------------------------------------
echo
echo "== Step 1/3: distribution terms =="
if [[ -f $FLAG ]]; then
  echo
  echo "  This device is preloaded with the Ubuntu operating system,"
  echo "  which is provided by Canonical Ltd."
  echo
  ask_yes "  Accept?" || die "Not accepted. Nothing was changed."
  rm -f "$FLAG"
  ok "terms accepted"
  info "waiting for the login screen (gdm) to start..."
  for _ in $(seq 1 20); do systemctl is-active --quiet gdm && break; sleep 1; done
  systemctl is-active --quiet gdm || { systemctl restart gdm; sleep 5; }
else
  ok "terms already accepted"
fi
if fix_tmp_dirs; then
  ok "fixed owner of /tmp/.X11-unix (was not root), restarting gdm"
  systemctl restart gdm; sleep 5
fi
if systemctl is-active --quiet gdm; then ok "gdm is running"; else warn "gdm is not running: check 'systemctl status gdm'"; fi

# ---- step 2: RDP login --------------------------------------------------------
echo
echo "== Step 2/3: RDP login =="
echo "  This is the first login box on the laptop (Remote Desktop Connection)."
read -rp "  RDP user [$DESK_USER]: " U
U=${U:-$DESK_USER}
while true; do
  read -rsp "  RDP password: " P; echo
  read -rsp "  Again: " P2; echo
  [[ -n $P && $P == "$P2" ]] && break
  warn "empty or not the same, try again"
done

# ---- step 3: turn on RDP ----------------------------------------------------------
echo
echo "== Step 3/3: turn on RDP =="
if [[ $MODE == 1 ]]; then
  make_cert "$SYS_DIR" gnome-remote-desktop:gnome-remote-desktop
  grdctl --system rdp set-tls-key  "$SYS_DIR/rdp-tls.key"
  grdctl --system rdp set-tls-cert "$SYS_DIR/rdp-tls.crt"
  grdctl --system rdp set-credentials "$U" "$P"
  grdctl --system rdp enable
  systemctl enable gnome-remote-desktop >/dev/null 2>&1 || true
  systemctl restart gnome-remote-desktop
else
  make_cert "$USER_DIR" "$DESK_USER:$DESK_USER"
  as_user grdctl rdp set-tls-key  "$USER_DIR/rdp-tls.key"
  as_user grdctl rdp set-tls-cert "$USER_DIR/rdp-tls.crt"
  as_user grdctl rdp set-credentials "$U" "$P"
  as_user grdctl rdp disable-view-only
  as_user grdctl rdp enable
  as_user systemctl --user enable gnome-remote-desktop >/dev/null 2>&1 || true
  as_user systemctl --user restart gnome-remote-desktop
fi
unset P P2
ok "RDP turned on"

if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  ufw allow 3389:3390/tcp >/dev/null && ok "firewall: ports 3389-3390 opened"
fi

PORT=""
for _ in $(seq 1 10); do
  if [[ $MODE == 2 ]] && listening 3390; then PORT=3390; break; fi
  if listening 3389; then PORT=3389; break; fi
  sleep 1
done

echo
if [[ -n $PORT ]]; then ok "listening on port $PORT"; else warn "no RDP port yet: run 'sudo ./setup_rdp.sh --status' in a few seconds"; fi
echo
echo "Connect from your laptop to:"
for ip in $(hostname -I); do
  [[ $ip == *:* ]] && continue
  if [[ ${PORT:-3389} == 3389 ]]; then echo "    $ip"; else echo "    $ip:$PORT"; fi
done
echo "  Windows: Remote Desktop Connection (mstsc) | macOS: Windows App | Linux: Remmina"
echo "  1) RDP login: $U and the password you just set"
if [[ $MODE == 1 ]]; then
  echo "  2) then the Ubuntu login screen: your normal Ubuntu user"
else
  echo "  2) you will see the same desktop as the monitor"
fi
