#!/system/bin/sh
# Restore mutable global settings when leaving Synchronize System.
# Fast mode must publish identity only through XSent-scoped processes.

restore_fast_baseline() {
    ORIGINAL_FILE="/data/adb/xsent-spoof/original_identity.prop"
    [ -s "$ORIGINAL_FILE" ] || return 0

    original_value() {
        sed -n "s/^$1=//p" "$ORIGINAL_FILE" 2>/dev/null | tail -n 1
    }

    ORIGINAL_ANDROID_ID="$(original_value android_id)"
    case "$ORIGINAL_ANDROID_ID" in
        ""|null|unknown) ;;
        *)
            settings put secure android_id "$ORIGINAL_ANDROID_ID" 2>/dev/null || true
            settings put global android_id "$ORIGINAL_ANDROID_ID" 2>/dev/null || true
            settings put system android_id "$ORIGINAL_ANDROID_ID" 2>/dev/null || true
            ;;
    esac

    ORIGINAL_NAME="$(original_value marketing_name)"
    [ -n "$ORIGINAL_NAME" ] || ORIGINAL_NAME="$(original_value model)"
    if [ -n "$ORIGINAL_NAME" ]; then
        settings put global device_name "$ORIGINAL_NAME" 2>/dev/null || true
        settings put secure bluetooth_name "$ORIGINAL_NAME" 2>/dev/null || true
        settings put global bluetooth_name "$ORIGINAL_NAME" 2>/dev/null || true
        settings put global synced_device_name "$ORIGINAL_NAME" 2>/dev/null || true
        settings put global market_name "$ORIGINAL_NAME" 2>/dev/null || true
        settings put system device_name "$ORIGINAL_NAME" 2>/dev/null || true
    fi
}
