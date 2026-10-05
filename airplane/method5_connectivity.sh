#!/system/bin/sh
# Airplane Mode Method 5 - Direct ConnectivityService Binder Call
# Calls IConnectivityManager.setAirplaneMode(boolean) directly through the
# connectivity service binder. This bypasses the shell `cmd connectivity`
# wrapper (missing on several vendor ROMs) and the protected broadcast path
# (which ConnectivityService may reject when it does not originate from
# ConnectivityManager.setAirplaneMode()).
#
# The binder transaction number for setAirplaneMode() differs across Android
# versions, so we probe a range of known transaction ids and verify the actual
# airplane state after each attempt.
#
# Usage: method5_connectivity.sh <enable|disable>

ACTION="$1" # "enable" or "disable"
[ -z "$ACTION" ] && ACTION="enable"

case "$ACTION" in
    enable)  VALUE=1; WANT=1 ;;
    disable) VALUE=0; WANT=0 ;;
    *) exit 2 ;;
esac

read_airplane_state() {
    state="$(cmd connectivity airplane-mode 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    case "$state" in
        *enabled*) echo "1"; return ;;
        *disabled*) echo "0"; return ;;
    esac
    prop="$(getprop sys.airplane_mode_on 2>/dev/null)"
    case "$prop" in
        1|true) echo "1"; return ;;
        0|false) echo "0"; return ;;
    esac
    settings get global airplane_mode_on 2>/dev/null || echo "0"
}

# Probe known setAirplaneMode() transaction ids across Android 8-14.
# The transaction id drifts as IConnectivityManager gains methods, so we pick
# the most likely id for the running SDK first, then fall back to a small
# neighbourhood of ids around it. This keeps the probe fast (no full sweep).
SDK="$(getprop ro.build.version.sdk 2>/dev/null | tr -dc '0-9')"
case "$SDK" in
    26|27) TXNS="39 40 41 42 43" ;;          # Android 8.0 / 8.1
    28)    TXNS="40 41 42 43 44" ;;          # Android 9
    29)    TXNS="44 45 46 47 48" ;;          # Android 10
    30)    TXNS="45 46 47 48 49" ;;          # Android 11
    31)    TXNS="46 47 48 49 50" ;;          # Android 12
    32)    TXNS="47 48 49 50 51" ;;          # Android 12L
    33)    TXNS="48 49 50 51 52" ;;          # Android 13
    34)    TXNS="49 50 51 52 53" ;;          # Android 14
    35)    TXNS="50 51 52 53 54" ;;          # Android 15
    *)     TXNS="44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60" ;;
esac

for txn in $TXNS; do
    service call connectivity "$txn" i32 "$VALUE" >/dev/null 2>&1 || continue
    # Give the connectivity stack a moment to apply the change.
    sleep 1
    if [ "$(read_airplane_state)" = "$WANT" ]; then
        exit 0
    fi
done

exit 1