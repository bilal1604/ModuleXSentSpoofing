#!/system/bin/sh
# XSent Spoof Location - Mock Location & Timezone Engine

export PATH="/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:/data/adb/mksu/bin:/data/adb/sukisu/bin:/data/adb/ksud:/data/adb/bin:/sbin:/debug_ramdisk:/system/bin:/system/xbin:/vendor/bin:$PATH"

CONFIG_DIR="/data/adb/xsent-spoof"
TARGET_FILE="$CONFIG_DIR/target.txt"

command -v resetprop >/dev/null 2>&1 || exit 0

LAT="$(resetprop persist.sys.xsent.location.lat 2>/dev/null)"
LNG="$(resetprop persist.sys.xsent.location.lng 2>/dev/null)"
[ -z "$LAT" ] && LAT="$(resetprop persist.sys.location.gps.lat 2>/dev/null)"
[ -z "$LNG" ] && LNG="$(resetprop persist.sys.location.gps.lng 2>/dev/null)"

SPOOF_LOC="$(resetprop persist.sys.xsent.spoof_location 2>/dev/null)"

apply_location() {
    if [ "$SPOOF_LOC" = "on" ] || { [ -n "$LAT" ] && [ "$LAT" != "0.0" ]; }; then
        settings put secure mock_location 1 2>/dev/null || true

        if [ -n "$LAT" ] && [ -n "$LNG" ]; then
            resetprop persist.sys.location.gps.lat "$LAT" 2>/dev/null || true
            resetprop persist.sys.location.gps.lng "$LNG" 2>/dev/null || true
            resetprop persist.sys.xsent.location.lat "$LAT" 2>/dev/null || true
            resetprop persist.sys.xsent.location.lng "$LNG" 2>/dev/null || true
        fi

        if [ -f "$TARGET_FILE" ]; then
            while IFS= read -r pkg || [ -n "$pkg" ]; do
                case "$pkg" in
                    ''|\#*) continue ;;
                esac
                pkg="$(printf '%s' "$pkg" | tr -d '[:space:]')"
                [ -z "$pkg" ] && continue
                appops set "$pkg" android:mock_location allow 2>/dev/null || true
            done < "$TARGET_FILE"
        fi
    fi

    # Timezone
    TZ="$(resetprop persist.sys.xsent.identity.timezone_id 2>/dev/null)"
    if [ -n "$TZ" ]; then
        setprop persist.sys.timezone "$TZ" 2>/dev/null || true
        resetprop persist.sys.timezone "$TZ" 2>/dev/null || true
    fi
}

apply_location
sync
exit 0