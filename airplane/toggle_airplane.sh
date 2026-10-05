#!/system/bin/sh
# Cycle network connectivity without applying identity or stopping apps.
DIR="$(cd "$(dirname "$0")" && pwd)"
DURATION="${1:-3}"
case "$DURATION" in ''|*[!0-9]*) exit 2;; esac
[ "$DURATION" -le 60 ] || exit 2
restore_network() { sh "$DIR/disable_airplane.sh"; }
trap 'restore_network' EXIT
trap 'exit 1' HUP INT TERM
sh "$DIR/enable_airplane.sh" || exit 1
sleep "$DURATION"
restore_network || exit 1
trap - EXIT HUP INT TERM
exit 0
