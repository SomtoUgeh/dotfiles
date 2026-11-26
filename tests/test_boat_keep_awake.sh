#!/usr/bin/env bash
# Runs scripts/boat/boat-keep-awake and the T3 launcher from vm-setup against stand-ins for boat,
# who, top and findmnt. Checks when the VM counts as busy (boat's deadline moves) and when it does
# not, and that the launcher waits for boat's disk swap outside of the home folder.
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
# Runs the command with no time limit, and records that the limit was asked for.
cat >"$bin/timeout" <<S
#!/bin/sh
echo "\$*" >>"$fixture/timeouts"
while [ "\${1#-}" != "\$1" ]; do shift 2; done
shift; exec "\$@"
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

# <runs that work> <seconds since a client connected, or -> <seconds since a linked T3 server connected, or ->
# [seconds since the runs started, default 60] [client type, default mobile]
# [minutes until a scheduled task is due, or -; a disabled task is always due in 5 minutes]
make_db() {
  rm -f "$fixture/t3.sqlite"
  python3 - "$fixture/t3.sqlite" "$1" "$2" "$3" "${4:-60}" "${5:-mobile}" "${6:--}" <<'P'
import datetime, sqlite3, sys
db = sqlite3.connect(sys.argv[1])
db.execute("create table orchestration_v2_projection_runs (status text, requested_at text)")
db.execute("create table auth_sessions (client_device_type text, last_connected_at text, revoked_at text)")
def ago(seconds):
    t = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(seconds=int(seconds))
    return t.strftime("%Y-%m-%dT%H:%M:%S.000Z")
rows = [("running", ago(sys.argv[5]))] * int(sys.argv[2]) + [("completed", ago(60)), ("queued", ago(60))]
db.executemany("insert into orchestration_v2_projection_runs values (?, ?)", rows)
if sys.argv[3] != "-": db.execute("insert into auth_sessions values (?, ?, null)", (sys.argv[6], ago(sys.argv[3])))
if sys.argv[4] != "-": db.execute("insert into auth_sessions values ('bot', ?, null)", (ago(sys.argv[4]),))
db.execute("create table scheduled_tasks (title text, enabled integer, next_run_at text)")
db.execute("insert into scheduled_tasks values ('off', 0, ?), ('webhook', 1, null)", (ago(-300),))
if sys.argv[7] != "-": db.execute("insert into scheduled_tasks values ('weekly', 1, ?)", (ago(-60 * int(sys.argv[7])),))
db.commit()
P
}

# A quiet VM with a deadline, on the machine of its last check. Each case changes one thing.
quiet() {
  rm -f "$fixture"/{who,cpu,boat-calls,boat-fails,timeouts,log,env} "$fixture/state"/*
  echo 3600 >"$fixture/ttl"; echo boot-1 >"$fixture/boot-id"; echo boot-1 >"$fixture/state/boot-id"
  printf 'BOAT_ID=bx_test\n' >"$fixture/env"
  make_db 0 - -
}
check() {
  PATH="$bin:$PATH" BOAT="$bin/boat" BOAT_IDLE_ENV="$fixture/env" BOAT_IDLE_STATE="$fixture/state" \
    T3_DB="$fixture/t3.sqlite" BOOT_ID_FILE="$fixture/boot-id" bash "$root/scripts/boat/boat-keep-awake"
}
extended() { grep -qx 'bx_test extend self --ttl 3600 --json' "$fixture/boat-calls" 2>/dev/null; }
fail() { echo "FAIL: $*" >&2; exit 1; }
busy() { check; extended || fail "$1: boat's deadline did not move"; grep -q "$2" "$fixture/state/last-reason" || fail "$1: reason is '$(cat "$fixture/state/last-reason")'"; }
idle() { check; ! extended || fail "$1: boat's deadline moved ($(cat "$fixture/state/last-reason"))"; }

quiet; idle "a quiet VM"
grep -qx 'bx_test info self --json' "$fixture/boat-calls" || fail "a quiet VM: did not check that auto-stop is on"
[ ! -e "$fixture/state/last-active" ] || fail "a quiet VM: recorded as busy"
grep -q 'boat info self' "$fixture/timeouts" || fail "a quiet VM: the boat call has no time limit"

quiet; echo null >"$fixture/ttl"; busy "auto-stop off" "auto-stop was off"
quiet; touch "$fixture/boat-fails"; idle "a quiet VM that boat does not answer for"

quiet; echo $(( now + 7200 )) >"$fixture/state/hold-until"; busy "a hold" "hold for"
quiet; echo $(( now - 60 )) >"$fixture/state/hold-until"; idle "a hold that ended"
# A resume on a new machine is busy once. A resume that boat did not answer for is tried again.
quiet; echo boot-2 >"$fixture/boot-id"; busy "a resume on a new machine" "resumed on a new machine"
rm "$fixture/boat-calls"; idle "the check after a resume"
quiet; echo boot-2 >"$fixture/boot-id"; touch "$fixture/boat-fails"; check; rm "$fixture/boat-fails" "$fixture/boat-calls"
busy "a resume after a failed extend" "resumed on a new machine"
quiet; rm "$fixture/state/boot-id"; busy "the first check on a VM" "resumed on a new machine"

quiet; make_db 2 - -; busy "T3 runs that work" "2 T3 run(s) working"
quiet; make_db 1 - - 39600; busy "a T3 run that started 11 hours ago" "1 T3 run(s) working"
quiet; make_db 1 - - 46800; idle "a T3 run stuck for 13 hours"

# A scheduled task keeps the VM awake from TTL_MIN (60 here) minutes before it is due.
quiet; make_db 0 - - 60 mobile 45; busy "a scheduled task due in 45 minutes" "scheduled task is due in 45 min"
quiet; make_db 0 - - 60 mobile -5; busy "a scheduled task due 5 minutes ago" "scheduled task is due in 0 min"
quiet; make_db 0 - - 60 mobile 90; idle "a scheduled task due in 90 minutes"
quiet; make_db 0 - - 60 mobile -30; idle "a scheduled task that T3 missed 30 minutes ago"
quiet; echo TTL_MIN=120 >>"$fixture/env"; make_db 0 - - 60 mobile 90; check
grep -qx 'bx_test extend self --ttl 7200 --json' "$fixture/boat-calls" || fail "a scheduled task due in 90 minutes, TTL_MIN=120: not busy"

quiet; make_db 0 120 -; busy "a phone that connected 2 minutes ago" "connected to T3 2 min ago"
quiet; make_db 0 120 - 60 tablet; busy "a tablet that connected 2 minutes ago" "connected to T3 2 min ago"
quiet; make_db 0 1800 -; idle "a phone that connected 30 minutes ago"
quiet; make_db 0 - 60; idle "a linked T3 server that connected a minute ago"
quiet; rm "$fixture/t3.sqlite"; idle "no T3 database"
quiet; python3 -c 'import sqlite3,sys; sqlite3.connect(sys.argv[1]).execute("drop table orchestration_v2_projection_runs")' "$fixture/t3.sqlite"
idle "a T3 database without the runs table"

# `who -u` in the C locale, which the script asks for: the login time is three columns.
quiet; echo "user     pts/0        Nov 24 10:01   .         4242 (100.84.82.24)" >"$fixture/who"; busy "a terminal in use" "terminal session"
quiet; echo "user     pts/0        Nov  4 00:10 00:10       4242 (100.84.82.24)" >"$fixture/who"; busy "a terminal used 10 minutes ago" "terminal session"
quiet; echo "user     pts/0        Nov 24 00:10 00:45       4242 (100.84.82.24)" >"$fixture/who"; idle "a terminal idle for 45 minutes"
quiet; echo "user     tty7         Nov 24 09:06 00:02       2301 (:0)" >"$fixture/who"; idle "boat's desktop login"
quiet; echo 85.0 >"$fixture/cpu"; busy "user CPU at 85%" "user CPU 85%"
quiet; echo 12.0 >"$fixture/cpu"; idle "user CPU at 12%"

# ENABLED=0 is always on: boat keeps the last lifetime across resumes, so its auto-stop goes off.
quiet; echo ENABLED=0 >>"$fixture/env"; make_db 1 - -; check
grep -qx 'bx_test extend self --no-auto-stop --json' "$fixture/boat-calls" || fail "ENABLED=0: boat's auto-stop stayed on"
! grep -q -- '--ttl' "$fixture/boat-calls" || fail "ENABLED=0: set a deadline"
quiet; echo ENABLED=0 >>"$fixture/env"; echo null >"$fixture/ttl"; check
! grep -q 'extend' "$fixture/boat-calls" || fail "ENABLED=0 with auto-stop off: called boat extend"
quiet; echo TTL_MIN=90 >>"$fixture/env"; make_db 1 - -; check
grep -qx 'bx_test extend self --ttl 5400 --json' "$fixture/boat-calls" || fail "TTL_MIN=90: wrong deadline"

# A failed extend is logged with boat's answer, and the next check tries again.
quiet; make_db 1 - -; touch "$fixture/boat-fails"; check
grep -q 'boat extend failed.*sandbox_not_ready' "$fixture/log" || fail "a failed extend: not logged"

# The same reason twice is logged once.
quiet; make_db 1 - -
check; check
[ "$(grep -c 'awake: 1 T3 run(s) working' "$fixture/log")" = 1 ] || fail "the same reason was logged twice"
[ "$(grep -c 'extend self' "$fixture/boat-calls")" = 2 ] || fail "the second busy check did not move the deadline"

# The T3 launcher: while /home is boat's temporary mount it waits outside of it, then starts T3 from home.
home=$fixture/home; mkdir -p "$home/.t3/runtime/versions/1.2.3" "$home/.local/bin"
sed -n "/^  put \"\$HOME\/.local\/bin\/t3-service-launcher\" <<'L' || true\$/,/^L\$/p" "$root/scripts/boat/vm-setup" | sed '1d;$d' >"$fixture/launcher"
grep -q '^main "\$@"$' "$fixture/launcher" || fail "launcher: not found in vm-setup"
echo '{"activeVersion":"1.2.3"}' >"$home/.t3/runtime/service-state.json"
cat >"$home/.t3/runtime/versions/1.2.3/t3" <<S
#!/bin/sh
echo "t3 \$* in \$(pwd -P)" >"$fixture/t3-started"
echo "t3 says hello"
S
# The swap: the temporary mount goes away, with the log that systemd opened on it.
cat >"$bin/findmnt" <<S
#!/bin/sh
pwd -P >>"$fixture/waited-in"
n=\$(cat "$fixture/swap-in" 2>/dev/null || echo 0)
if [ "\$n" -gt 0 ]; then echo \$(( n - 1 )) >"$fixture/swap-in"; echo ascii-lazyfs; exit; fi
[ ! -e "$home/boot.log" ] || [ -e "$home/boot.log.retired" ] || { mv "$home/boot.log" "$home/boot.log.retired"; : >"$home/boot.log"; }
echo /dev/vda1
S
chmod +x "$bin/findmnt" "$home/.t3/runtime/versions/1.2.3/t3"
echo 2 >"$fixture/swap-in"
started=$(date +%s)
(cd "$home" && HOME=$home PATH="$bin:$PATH" bash "$fixture/launcher" --flag >>"$home/boot.log" 2>&1)
[ $(( $(date +%s) - started )) -ge 3 ] || fail "launcher: did not wait for the swap"
[ "$(sort -u "$fixture/waited-in")" = / ] || fail "launcher: waited inside $(sort -u "$fixture/waited-in" | tr '\n' ' ')"
grep -qx "t3 __service-launcher --flag in $(cd "$home" && pwd -P)" "$fixture/t3-started" || fail "launcher: started '$(cat "$fixture/t3-started")'"
[ "$(readlink "$home/.local/bin/t3")" = "$home/.t3/runtime/versions/1.2.3/t3" ] || fail "launcher: ~/.local/bin/t3 is not the active version"
# Needs /proc to see where the output goes, so on Linux only.
if [ -e "/proc/$$/fd/1" ]; then
  grep -qx "t3 says hello" "$home/boot.log" || fail "launcher: T3's output went to the log on the temporary mount"
fi
# No temporary mount (a new VM, or a resume on the same machine): no wait.
rm -f "$fixture/waited-in" "$fixture/t3-started"; echo 0 >"$fixture/swap-in"; started=$(date +%s)
(cd "$home" && HOME=$home PATH="$bin:$PATH" bash "$fixture/launcher" >/dev/null)
[ $(( $(date +%s) - started )) -le 1 ] || fail "launcher: waited with no temporary mount"
[ -s "$fixture/t3-started" ] || fail "launcher: did not start T3 with no temporary mount"

echo "ok"
