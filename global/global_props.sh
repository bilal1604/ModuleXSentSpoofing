#!/system/bin/sh
# XSent Spoof Global - Global System Properties Engine

apply_global_props() {
    PROP_FILE="$1"
    [ -z "$PROP_FILE" ] && PROP_FILE="/data/adb/xsent-spoof/system.prop"
    [ -f "$PROP_FILE" ] || return 0

    SYSTEM_SYNC_MODE="$(sed -n 's/^persist\.sys\.xsent\.system_sync_mode=//p' "$PROP_FILE" | tail -n 1 | tr '[:upper:]' '[:lower:]')"
    case "$SYSTEM_SYNC_MODE" in
        off|0|false|no) return 0 ;;
    esac

    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ''|\#*) continue ;;
        esac

        key="${line%%=*}"
        val="${line#*=}"
        key="$(printf '%s' "$key" | tr -d '[:space:]')"
        val="$(printf '%s' "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

        [ -z "$key" ] && continue

        # Ignore unsafe HAL, kernel, and SDK level overrides
        case "$key" in
            ro.board.platform|ro.hardware|ro.product.cpu.abi|ro.product.cpu.abilist|ro.zygote|ro.arch)
                continue
                ;;
            ro.build.version.sdk|ro.*.build.version.sdk|ro.os.sdk_int|*.sdk_int)
                # NEVER spoof SDK version globally ? prevents ART runtime crashes on newly launched apps
                continue
                ;;
        esac

        resetprop "$key" "$val" 2>/dev/null || true
    done < "$PROP_FILE"
}
