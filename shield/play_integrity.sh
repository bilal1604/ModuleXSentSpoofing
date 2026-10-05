#!/system/bin/sh
# XSent Spoof Shield - Play Integrity & Keybox Engine

export PATH="/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:/data/adb/mksu/bin:/data/adb/sukisu/bin:/data/adb/ksud:/data/adb/bin:/sbin:/debug_ramdisk:/system/bin:/system/xbin:/vendor/bin:$PATH"

CONFIG_DIR="/data/adb/xsent-spoof"
ACTIVE_KEYBOX="$CONFIG_DIR/keybox.xml"
MANUAL_KEYBOX="$CONFIG_DIR/manual_keybox.xml"
DEFAULT_KEYBOX="$MODPATH/keybox.xml"

command -v resetprop >/dev/null 2>&1 || exit 0
get_flag() { resetprop "persist.sys.xsent.$1" 2>/dev/null; }
get_id() { resetprop "persist.sys.xsent.identity.$1" 2>/dev/null; }

apply_play_integrity() {
    PI_MANAGED="$(get_flag manage_play_integrity)"
    FP="$(get_id fingerprint)"

    # 1. Native XSent Fingerprint Sync (For PIF/FP readers)
    if [ -n "$FP" ]; then
        mkdir -p "$CONFIG_DIR"
        printf '%s\n' "$FP" > "$CONFIG_DIR/fp.txt" 2>/dev/null
    fi

    # 2. Keybox Management & Protection
    if [ -f "$MANUAL_KEYBOX" ]; then
        # User has imported a custom keybox: Lock and activate it
        cp -f "$MANUAL_KEYBOX" "$ACTIVE_KEYBOX" 2>/dev/null
        resetprop persist.sys.xsent.keybox_source "local" 2>/dev/null || true
        resetprop persist.sys.xsent.keybox_locked "1" 2>/dev/null || true
    elif [ ! -f "$ACTIVE_KEYBOX" ] && [ -f "$DEFAULT_KEYBOX" ]; then
        cp -f "$DEFAULT_KEYBOX" "$ACTIVE_KEYBOX" 2>/dev/null
    fi
    chmod 0600 "$ACTIVE_KEYBOX" "$MANUAL_KEYBOX" 2>/dev/null

    # 3. Handle Manage Play Integrity State
    if [ "$PI_MANAGED" = "on" ]; then
        # When ON: XSent manages Play Integrity independently.
        # Disconnect external Tricky Store conflict targets
        for td in /data/adb/tricky_store /data/adb/trickystore /data/adb/modules/tricky_store; do
            if [ -d "$td" ]; then
                rm -f "$td/pif.json" "$td/spoof_build_vars" 2>/dev/null || true
                : > "$td/target.txt" 2>/dev/null || true
            fi
        done

        # Clean GMS Clearcut logs & caches
        for d in /data/data/com.google.android.gms/files/clearcut /data/user/0/com.google.android.gms/files/clearcut; do
            rm -rf "$d"/* 2>/dev/null || true
        done
    fi
}

apply_play_integrity