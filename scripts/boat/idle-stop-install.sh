set -e
ID=$1; MIN=${2:-45}; DRY=${3:-0}
sudo install -m 755 /tmp/boat-idle-stop /usr/local/sbin/boat-idle-stop
sudo install -m 755 /tmp/vm-stay /usr/local/bin/vm-stay
sudo mkdir -p /var/lib/boat-idle
printf 'BOAT_ID=%s\nIDLE_MIN=%s\nCPU_MAX=40\nENABLED=1\nDRY_RUN=%s\n' "$ID" "$MIN" "$DRY" | sudo tee /etc/boat-idle.env >/dev/null
sudo tee /etc/systemd/system/boat-idle-stop.service >/dev/null <<U
[Unit]
Description=Stop this boat VM when it has been idle (see /etc/boat-idle.env)
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/boat-idle-stop
U
sudo tee /etc/systemd/system/boat-idle-stop.timer >/dev/null <<U
[Unit]
Description=Check every 5 minutes whether this boat VM is idle
[Timer]
OnBootSec=10min
OnUnitActiveSec=5min
[Install]
WantedBy=timers.target
U
date +%s | sudo tee /var/lib/boat-idle/last-active /var/lib/boat-idle/last-check >/dev/null
sudo systemctl daemon-reload && sudo systemctl enable --now boat-idle-stop.timer >/dev/null 2>&1
sudo systemctl start boat-idle-stop.service; sleep 1
echo "$(hostname): timer $(systemctl is-active boat-idle-stop.timer); last reason: $(sudo cat /var/lib/boat-idle/last-reason 2>/dev/null || echo none yet)"
