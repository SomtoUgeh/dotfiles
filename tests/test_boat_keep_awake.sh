#!/usr/bin/env bash
# Runs scripts/boat/boat-keep-awake and the T3 launcher from vm-setup against stand-ins for boat,
# logind, who, top and findmnt. Checks when the VM counts as busy (boat's deadline moves) and when
# it does not, and that the launcher waits for boat's disk swap outside of the home folder.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd -P)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
bin=$fixture/bin; mkdir -p "$bin" "$fixture/state"
now=$(date +%s)

# Stand-ins. Each reads its answer from a file in $fixture, so a case sets only what it needs.
cat >"$bin/runuser" <<'S'
#!/bin/sh
while [ "$1" != -- ]; do shift; done; shift; exec "$@"
S
cat >"$bin/logger" <<S
#!/bin/sh
shift 2; echo "\$*" >>"$fixture/log"
S
cat >"$bin/systemd-inhibit" <<S
#!/bin/sh
cat "$fixture/inhibitors" 2>/dev/null
S
cat >"$bin/who" <<S
#!/bin/sh
cat "$fixture/who" 2>/dev/null
S
cat >"$bin/top" <<S
#!/bin/sh
printf '    PID USER      PR  NI    VIRT    RES    SHR S  %%CPU\n      1 user      20   0       0      0      0 S   0.0\n'
printf '    PID USER      PR  NI    VIRT    RES    SHR S  %%CPU\n      1 user      20   0       0      0      0 S  %s\n' "\$(cat "$fixture/cpu" 2>/dev/null || echo 0.0)"
S
cat >"$bin/boat" <<S
#!/bin/sh
echo "\$BOAT_ID \$*" >>"$fixture/boat-calls"
[ -e "$fixture/boat-fails" ] && { echo '{"error":"sandbox_not_ready"}'; exit 1; }
case "\$1" in info) printf '{"sandbox":{"ttlSeconds":%s}}\n' "\$(cat "$fixture/ttl")";; esac
S
chmod +x "$bin"/*

make_db() { # <active runs> <seconds since a phone connected, or -> <seconds since a linked T3 server connected, or ->
  rm -f "$fixture/t3.sqlite"
  python3 - "$fixture/t3.sqlite" "$1" "$2" "$3" <<'P'
import datetime, sqlite3, sys
db = sqlite3.connect(sys.argv[1])
db.execute("create table orchestration_v2_projection_runs (status text)")
db.execute("create table auth_sessions (client_device_type text, last_connected_at text, revoked_at text)")
db.executemany("insert into orchestration_v2_projection_runs values (?)", [("running",)] * int(sys.argv[2]) + [("completed",), ("queued",)])
def ago(seconds):
    t = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(seconds=int(seconds))
    return t.strftime("%Y-%m-%dT%H:%M:%S.000Z")
if sys.argv[3] != "-": db.execute("insert into auth_sessions values ('mobile', ?, null)", (ago(sys.argv[3]),))
if sys.argv[4] != "-": db.execute("insert into auth_sessions values ('bot', ?, null)", (ago(sys.argv[4]),))
db.commit()
P
}

# A quiet VM with a deadline, up for two hours. Each case changes one thing.
quiet() {
  rm -f "$fixture"/{inhibitors,who,cpu,boat-calls,boat-fails,log,env} "$fixture/state"/*
  echo 3600 >"$fixture/ttl"; echo "7200.00 1.00" >"$fixture/uptime"
  printf 'BOAT_ID=bx_test\n' >"$fixture/env"
  make_db 0 - -
}
check() {
  PATH="$bin:$PATH" BOAT="$bin/boat" BOAT_IDLE_ENV="$fixture/env" BOAT_IDLE_STATE="$fixture/state" \
    T3_DB="$fixture/t3.sqlite" PROC_UPTIME="$fixture/uptime" bash "$root/scripts/boat/boat-keep-awake"
}
extended() { grep -qx 'bx_test extend self --ttl 3600 --json' "$fixture/boat-calls" 2>/dev/null; }
fail() { echo "FAIL: $*" >&2; exit 1; }
busy() { check; extended || fail "$1: boat's deadline did not move"; grep -q "$2" "$fixture/state/last-reason" || fail "$1: reason is '$(cat "$fixture/state/last-reason")'"; }
idle() { check; ! extended || fail "$1: boat's deadline moved ($(cat "$fixture/state/last-reason"))"; }

quiet; idle "a quiet VM"
grep -qx 'bx_test info self --json' "$fixture/boat-calls" || fail "a quiet VM: did not check that auto-stop is on"
[ ! -e "$fixture/state/last-active" ] || fail "a quiet VM: recorded as busy"

quiet; echo null >"$fixture/ttl"; busy "auto-stop off" "auto-stop was off"
quiet; touch "$fixture/boat-fails"; idle "a quiet VM that boat does not answer for"

quiet; echo $(( now + 7200 )) >"$fixture/state/hold-until"; busy "a hold" "hold for"
quiet; echo $(( now - 60 )) >"$fixture/state/hold-until"; idle "a hold that ended"
quiet; echo "120.50 1.00" >"$fixture/uptime"; busy "a start 2 minutes ago" "started 2 min ago"

quiet; echo "T3 Code       1000 user 4242 systemd-inhibit sleep Agents are working block" >"$fixture/inhibitors"
busy "T3's inhibitor" "T3 agents are working"
quiet; echo "UPower        0    root 121  upowerd         sleep Pause device polling delay" >"$fixture/inhibitors"
idle "another program's inhibitor"
quiet; make_db 1 - -; busy "a T3 run without the inhibitor" "without T3's sleep inhibitor"

quiet; make_db 0 120 -; busy "a phone that opened T3 2 minutes ago" "opened T3 2 min ago"
quiet; make_db 0 1800 -; idle "a phone that opened T3 30 minutes ago"
quiet; make_db 0 - 60; idle "a linked T3 server that connected a minute ago"
quiet; rm "$fixture/t3.sqlite"; idle "no T3 database"
quiet; python3 -c 'import sqlite3,sys; sqlite3.connect(sys.argv[1]).execute("drop table orchestration_v2_projection_runs")' "$fixture/t3.sqlite"
idle "a T3 database without the runs table"

quiet; echo "user     pts/0        2026-11-24 10:01   .         4242 (100.84.82.24)" >"$fixture/who"; busy "a terminal in use" "terminal session"
quiet; echo "user     pts/0        2026-11-24 10:01 00:45       4242 (100.84.82.24)" >"$fixture/who"; idle "a terminal idle for 45 minutes"
quiet; echo "user     tty7         2026-11-24 09:06 01:34       2301 (:0)" >"$fixture/who"; idle "boat's desktop login"
quiet; echo 85.0 >"$fixture/cpu"; busy "user CPU at 85%" "user CPU 85%"
quiet; echo 12.0 >"$fixture/cpu"; idle "user CPU at 12%"

quiet; echo ENABLED=0 >>"$fixture/env"; echo null >"$fixture/ttl"; idle "ENABLED=0"
[ ! -e "$fixture/boat-calls" ] || fail "ENABLED=0: called boat"
quiet; echo TTL_MIN=90 >>"$fixture/env"; echo "60.0 1.0" >"$fixture/uptime"; check
grep -qx 'bx_test extend self --ttl 5400 --json' "$fixture/boat-calls" || fail "TTL_MIN=90: wrong deadline"

# A failed extend is logged with boat's answer, and the next check tries again.
quiet; echo "60.0 1.0" >"$fixture/uptime"; touch "$fixture/boat-fails"; check
grep -q 'boat extend failed.*sandbox_not_ready' "$fixture/log" || fail "a failed extend: not logged"

# The same reason twice is logged once.
quiet; echo "T3 Code       1000 user 4242 systemd-inhibit sleep Agents are working block" >"$fixture/inhibitors"
check; check
[ "$(grep -c 'awake: T3 agents are working' "$fixture/log")" = 1 ] || fail "the same reason was logged twice"
[ "$(grep -c 'extend self' "$fixture/boat-calls")" = 2 ] || fail "the second busy check did not move the deadline"

# The T3 launcher: while /home is boat's temporary mount it waits outside of it, then starts T3 from home.
home=$fixture/home; mkdir -p "$home/.t3/runtime/versions/1.2.3" "$home/.local/bin"
sed -n "/^  put \"\$HOME\/.local\/bin\/t3-service-launcher\" <<'L' || true\$/,/^L\$/p" "$root/scripts/boat/vm-setup" | sed '1d;$d' >"$fixture/launcher"
grep -q '^main "\$@"$' "$fixture/launcher" || fail "launcher: not found in vm-setup"
echo '{"activeVersion":"1.2.3"}' >"$home/.t3/runtime/service-state.json"
cat >"$home/.t3/runtime/versions/1.2.3/t3" <<S
#!/bin/sh
echo "t3 \$* in \$(pwd -P)" >"$fixture/t3-started"
S
cat >"$bin/findmnt" <<S
#!/bin/sh
pwd -P >>"$fixture/waited-in"
n=\$(cat "$fixture/swap-in" 2>/dev/null || echo 0)
if [ "\$n" -gt 0 ]; then echo \$(( n - 1 )) >"$fixture/swap-in"; echo ascii-lazyfs; else echo /dev/vda1; fi
S
chmod +x "$bin/findmnt" "$home/.t3/runtime/versions/1.2.3/t3"
echo 2 >"$fixture/swap-in"
started=$(date +%s)
(cd "$home" && HOME=$home PATH="$bin:$PATH" bash "$fixture/launcher" --flag)
[ $(( $(date +%s) - started )) -ge 3 ] || fail "launcher: did not wait for the swap"
[ "$(sort -u "$fixture/waited-in")" = / ] || fail "launcher: waited inside $(sort -u "$fixture/waited-in" | tr '\n' ' ')"
grep -qx "t3 __service-launcher --flag in $(cd "$home" && pwd -P)" "$fixture/t3-started" || fail "launcher: started '$(cat "$fixture/t3-started")'"
[ "$(readlink "$home/.local/bin/t3")" = "$home/.t3/runtime/versions/1.2.3/t3" ] || fail "launcher: ~/.local/bin/t3 is not the active version"
# No temporary mount (a new VM, or a resume on the same machine): no wait.
rm -f "$fixture/waited-in" "$fixture/t3-started"; echo 0 >"$fixture/swap-in"; started=$(date +%s)
(cd "$home" && HOME=$home PATH="$bin:$PATH" bash "$fixture/launcher")
[ $(( $(date +%s) - started )) -le 1 ] || fail "launcher: waited with no temporary mount"
[ -s "$fixture/t3-started" ] || fail "launcher: did not start T3 with no temporary mount"

echo "ok"
