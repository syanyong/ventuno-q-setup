#!/usr/bin/env bash
# Read-only check: is this VENTUNO Q ready for the short course?
# Changes nothing and needs no sudo.  Usage: ./check_board.sh
set -uo pipefail

pass=0; fail=0
ok()   { printf '\e[32m[ OK ]\e[0m %s\n' "$*"; pass=$((pass + 1)); }
bad()  { printf '\e[31m[MISS]\e[0m %s\n' "$*"; fail=$((fail + 1)); }
hint() { printf '       -> %s\n' "$*"; }
port() { ss -ltn | grep -qE ":$1\s"; }

echo "== $(hostname)  ($(. /etc/os-release; echo "$PRETTY_NAME"))  IP: $(hostname -I | awk '{print $1}')"

echo; echo "-- Part 2: App Lab, Bridge, Remote Desktop"
zv=$(arduino-cli core list 2>/dev/null | awk '$1=="arduino:zephyr"{print $2}')
if [[ -n $zv ]] && printf '1.1.0\n%s\n' "$zv" | sort -V -C; then ok "arduino:zephyr $zv"
else bad "arduino:zephyr ${zv:-missing} (need 1.1.0+)"; hint "App Lab -> Settings -> Update"; fi
systemctl is-active --quiet arduino-router && ok "arduino-router running" || bad "arduino-router not running"
[[ -f /var/lib/arduino-desktop-customization/distribution_terms_not_confirmed ]] \
  && { bad "distribution terms not accepted"; hint "sudo ./setup_rdp.sh"; } || ok "distribution terms accepted"
port 3389 && ok "Remote Desktop listening (3389)" || { bad "Remote Desktop off"; hint "sudo ./setup_rdp.sh"; }
[[ $(stat -c %U /tmp/.X11-unix 2>/dev/null) == root ]] && ok "/tmp/.X11-unix owned by root" \
  || { bad "/tmp/.X11-unix not owned by root (black screen after RDP login)"; hint "sudo ./setup_rdp.sh --fix"; }

echo; echo "-- Part 3: camera"
ls /dev/video* >/dev/null 2>&1 && ok "camera device present" || { bad "no /dev/video*"; hint "plug in the USB camera"; }

echo; echo "-- Part 4: ROS 2"
[[ -d /opt/ros/jazzy ]] && ok "ROS 2 Jazzy installed" || { bad "ROS 2 Jazzy missing"; hint "Part 4 slides 'If not installed'"; }
python3 -c "import msgpack" 2>/dev/null && ok "python3-msgpack" || { bad "python3-msgpack missing"; hint "sudo apt install python3-msgpack"; }
id -nG | grep -qw arduino-router && ok "user in group arduino-router" \
  || { bad "user not in group arduino-router (ROS node cannot reach Bridge)"; hint "sudo usermod -aG arduino-router $USER, then log out and in"; }
[[ -d ~/ArduinoApps/ros2-matrix-led-bridge ]] && ok "App ros2-matrix-led-bridge present" \
  || { bad "App ros2-matrix-led-bridge missing"; hint "cd ~/ArduinoApps && git clone https://github.com/syanyong/ros2-matrix-led-bridge.git"; }

echo; echo "-- Part 3 + 5: models"
status_json=$(arduino-app-cli model list --format json 2>/dev/null)
model_status() {   # prints installed / downloading / not-installed
  echo "$status_json" | python3 -c '
import json, sys
d = json.load(sys.stdin)
m = d.get("models") or next(v for v in d.values() if isinstance(v, list))
print(next((x.get("Status") for x in m if x.get("ID") == sys.argv[1]), "unknown"))' "$1"
}
for m in yolox-qnn-object-detection face-detection-qnn genie:qwen3_4b_instruct_2507 llamacpp:Qwen3.5-0.8B-Q4_0 genie:qwen3_vl_4b_instruct; do
  st=$(model_status "$m")
  if [[ $st == installed ]]; then ok "model $m"
  else bad "model $m: $st"; hint "arduino-app-cli model install $m"; fi
done

echo; echo "-- Part 5: llama.cpp (Workshop 5)"
[[ -x ~/dev/llm/llama.cpp/build/bin/llama-server ]] && ok "llama.cpp built" || { bad "llama.cpp not built"; hint "Part 5 'If not prepared: build llama.cpp'"; }
[[ -f ~/dev/llm/qwen2.5-1.5b-instruct-q4_0-pure.gguf ]] && ok "qwen2.5-1.5b q4_0-pure model" || bad "q4_0-pure model missing"
dpkg -s qcom-adreno-cl1 >/dev/null 2>&1 && ok "Adreno OpenCL driver" || { bad "qcom-adreno-cl1 missing"; hint "sudo apt install qcom-adreno-cl1 qcom-adreno-cl-dev"; }

echo; echo "-- Disk"
free_gb=$(df -BG / | awk 'NR==2{gsub("G","",$4); print $4}')
(( free_gb >= 10 )) && ok "${free_gb} GB free" || bad "only ${free_gb} GB free (need 10+)"

echo; echo "== $pass OK, $fail missing"
