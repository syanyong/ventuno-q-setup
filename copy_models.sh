#!/bin/bash
# copy_models.sh - copy Brick models (installed with arduino-app-cli) between
# VENTUNO Q boards without internet: over the LAN, or through a flash drive.
#
#   ./copy_models.sh list                         installed models you can copy
#   ./copy_models.sh send   <board-ip> [ID ...]   board -> board over LAN (rsync + ssh)
#   ./copy_models.sh export <dir>      [ID ...]   board -> flash drive
#   ./copy_models.sh import <dir>      [ID ...]   flash drive -> board
#
# No ID = every installed genie:/llamacpp: model. Built-in models (YoloX, Face ...)
# ship with the board and are skipped. Run as user arduino, no sudo needed.
# Flash drive: use exFAT (some model files are bigger than 4 GB-FAT32 allows),
#   mount it with:  udisksctl mount -b /dev/sda1   -> /media/arduino/<name>
set -euo pipefail

M=/var/lib/arduino-app-cli/models
INI=llamacpp/models.ini
SSH_OPTS=(-o ConnectTimeout=10)

die()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*"; }

# --- model id -> folder (relative to $M) -----------------------------------
# genie:<name>          -> genai/<name>-genie-*
# llamacpp:<section>    -> llamacpp/<publisher>/<repo>  (from models.ini, /models = llamacpp/)
model_dir() {  # $1 = id, $2 = models root
  local id=$1 root=$2 name=${1#*:}
  case $id in
    genie:*)
      local d; d=$(cd "$root" && ls -d genai/"$name"-genie-* 2>/dev/null | head -1)
      [ -n "$d" ] && echo "$d" ;;
    llamacpp:*)
      [ -f "$root/$INI" ] || return 0
      awk -v s="[$name]" '$0==s{f=1;next} /^\[/{f=0} f && /^model *=/{sub(/^model *= */,"");print;exit}' "$root/$INI" \
        | sed -E 's#^/models/#llamacpp/#; s#/[^/]+$##' ;;
  esac
}

ini_section() {  # print [name] block from an ini file
  awk -v s="[$1]" '$0==s{f=1;print;next} /^\[/{f=0} f' "$2"
}

# installed, non-built-in genie:/llamacpp: ids on THIS board
installed_ids() {
  arduino-app-cli model list --format json \
    | jq -r '.models[] | select(.Status=="installed" and (.IsBuiltIn|not)) | .ID' \
    | grep -E '^(genie|llamacpp):' || true
}

# ids found in an exported folder (for import)
ids_in_dir() {
  local d=$1
  for g in "$d"/genai/*-genie-*; do [ -d "$g" ] && { b=$(basename "$g"); echo "genie:${b%%-genie-*}"; }; done
  [ -f "$d/$INI" ] && grep -oE '^\[[^]]+\]' "$d/$INI" | tr -d '[]' | sed 's/^/llamacpp:/'
  return 0
}

pick() {  # $1 = default list, rest = user ids
  local all=$1; shift
  if [ $# -eq 0 ]; then echo "$all"; else printf '%s\n' "$@"; fi
}

status_here() {
  arduino-app-cli model list --format json \
    | jq -r '.models[] | select(.ID|test("^(genie|llamacpp):")) | "\(.Status)\t\(.ID)"'
}

# append missing llamacpp sections to a target ini (local file or via ssh)
merge_ini_local() {  # $1 = id list, $2 = src root, $3 = dst root
  local dst="$3/$INI"; mkdir -p "$(dirname "$dst")"; touch "$dst"
  for id in $1; do
    [[ $id == llamacpp:* ]] || continue
    local n=${id#llamacpp:}
    grep -qxF "[$n]" "$dst" || { [ -s "$dst" ] && echo >> "$dst"; ini_section "$n" "$2/$INI" >> "$dst"; info "models.ini += [$n]"; }
  done
}

# --- commands ------------------------------------------------------------------
cmd=${1:-}; shift || true
case $cmd in
  list)
    info "Installed models you can copy (from $M):"
    for id in $(installed_ids); do
      d=$(model_dir "$id" "$M"); printf '  %-40s %6s  %s\n' "$id" "$(du -sh "$M/$d" | cut -f1)" "$d"
    done ;;

  send)
    host=${1:-}; [ -n "$host" ] || die "usage: $0 send <board-ip> [ID ...]"; shift
    ids=$(pick "$(installed_ids)" "$@"); [ -n "$ids" ] || die "no installed models to send"
    ssh "${SSH_OPTS[@]}" "arduino@$host" true || die "cannot ssh to arduino@$host"
    for id in $ids; do
      d=$(model_dir "$id" "$M"); [ -n "$d" ] && [ -d "$M/$d" ] || die "$id is not installed here"
      info "send $id ($(du -sh "$M/$d" | cut -f1)) -> $host"
      ssh "${SSH_OPTS[@]}" "arduino@$host" "mkdir -p '$M/$(dirname "$d")'"
      rsync -a --partial --info=progress2 -e "ssh ${SSH_OPTS[*]}" "$M/$d/" "arduino@$host:$M/$d/"
    done
    # merge models.ini on the other board (append missing sections only)
    for id in $ids; do
      [[ $id == llamacpp:* ]] || continue; n=${id#llamacpp:}
      ini_section "$n" "$M/$INI" | ssh "${SSH_OPTS[@]}" "arduino@$host" \
        "f='$M/$INI'; touch \"\$f\"; grep -qxF '[$n]' \"\$f\" || { [ -s \"\$f\" ] && echo >> \"\$f\"; cat >> \"\$f\"; echo '==> models.ini += [$n]'; }"
    done
    info "status on $host:"
    ssh "${SSH_OPTS[@]}" "arduino@$host" \
      "arduino-app-cli model list --format json | jq -r '.models[] | select(.ID|test(\"^(genie|llamacpp):\")) | \"\(.Status)\t\(.ID)\"'" ;;

  export)
    dst=${1:-}; [ -n "$dst" ] || die "usage: $0 export <dir> [ID ...]"; shift
    mkdir -p "$dst"; [ -w "$dst" ] || die "$dst is not writable (flash drive mounted?)"
    ids=$(pick "$(installed_ids)" "$@"); [ -n "$ids" ] || die "no installed models to export"
    for id in $ids; do
      d=$(model_dir "$id" "$M"); [ -n "$d" ] && [ -d "$M/$d" ] || die "$id is not installed here"
      need=$(du -sk "$M/$d" | cut -f1); free=$(df -Pk "$dst" | awk 'NR==2{print $4}')
      [ "$need" -lt "$free" ] || die "not enough space on $dst for $id"
      info "export $id ($(du -sh "$M/$d" | cut -f1)) -> $dst/$d"
      mkdir -p "$dst/$d"
      rsync -rt --partial --info=progress2 "$M/$d/" "$dst/$d/"   # -rt: exFAT has no owners/perms
    done
    merge_ini_local "$ids" "$M" "$dst"
    sync; info "done. now: udisksctl unmount -b /dev/sda1  (then unplug)" ;;

  import)
    src=${1:-}; [ -n "$src" ] || die "usage: $0 import <dir> [ID ...]"; shift
    [ -d "$src/genai" ] || [ -d "$src/llamacpp" ] || die "$src has no genai/ or llamacpp/ (wrong folder?)"
    ids=$(pick "$(ids_in_dir "$src")" "$@"); [ -n "$ids" ] || die "no models found in $src"
    for id in $ids; do
      d=$(model_dir "$id" "$src"); [ -n "$d" ] && [ -d "$src/$d" ] || die "$id not found in $src"
      info "import $id ($(du -sh "$src/$d" | cut -f1)) -> $M/$d"
      mkdir -p "$M/$d"
      rsync -rt --partial --info=progress2 "$src/$d/" "$M/$d/"
      chmod -R u+rwX,go+rX "$M/$d"
    done
    merge_ini_local "$ids" "$src" "$M"
    info "status:"; status_here ;;

  *)
    sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
