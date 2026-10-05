#!/system/bin/sh
# XSent Spoof Airplane - Master Disable & Restore Engine (Multi-Method Fallback)

export PATH="/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:/data/adb/mksu/bin:/data/adb/sukisu/bin:/data/adb/ksud:/data/adb/bin:/sbin:/debug_ramdisk:/system/bin:/system/xbin:/vendor/bin:$PATH"

DIR="$(cd "$(dirname "$0")" && pwd)"

read_airplane_state() {
    state="$(cmd connectivity airplane-mode 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    case "$state" in
        *enabled*) echo "1"; return ;;
        *disabled*) echo "0"; return ;;
    esac
    # Some vendor ROMs keep the authoritative state in the runtime property
    # instead of the global setting. Check both before falling back.
    prop="$(getprop sys.airplane_mode_on 2>/dev/null)"
    case "$prop" in
        1|true) echo "1"; return ;;
        0|false) echo "0"; return ;;
    esac
    settings get global airplane_mode_on 2>/dev/null || echo "0"
}

# 1. Try Method 1 (cmd connectivity)
[ -f "$DIR/method1_cmd.sh" ] && sh "$DIR/method1_cmd.sh" "disable"

# 2. Try Method 2 (settings + broadcast)
if [ "$(read_airplane_state)" != "0" ]; then
    [ -f "$DIR/method2_broadcast.sh" ] && sh "$DIR/method2_broadcast.sh" "disable"
fi

# 3. Try Method 5 (direct ConnectivityService binder call) - most reliable on
#    vendor ROMs where `cmd connectivity` is missing and the protected
#    broadcast is rejected by ConnectivityService.
if [ "$(read_airplane_state)" != "0" ]; then
    [ -f "$DIR/method5_connectivity.sh" ] && sh "$DIR/method5_connectivity.sh" "disable"
fi

# Verification
for i in 1 2 3 4 5; do
    if [ "$(read_airplane_state)" = "0" ]; then
        # KernelSU/vendor ROMs may leave mobile data disabled even though the
        # global Airplane Mode state already reports off.
        svc data enable 2>/dev/null || true
        cmd phone data enable 2>/dev/null || true
        sleep 1
        svc data enable 2>/dev/null || true
        exit 0
    fi
    sleep 1
done

exit 1
