#!/system/bin/sh
# XSent Spoof Framework - Zygisk Controller Engine

get_zygisk_daemon() {
    for candidate in /data/adb/modules/zygisksu/bin/zygiskd /data/adb/zygisksu/bin/zygiskd $(command -v znctl 2>/dev/null); do
        if [ -n "$candidate" ] && [ -x "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

zygisk_action() {
    ACTION="$1"
    DAEMON="$(get_zygisk_daemon)"
    [ -z "$DAEMON" ] && return 1
    "$DAEMON" "$ACTION" 2>/dev/null
}
