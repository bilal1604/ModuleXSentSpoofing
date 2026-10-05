#!/system/bin/sh
# XSent Spoof Framework - Scope Synchronization Engine

CONFIG_DIR="/data/adb/xsent-spoof"
TARGET_FILE="$CONFIG_DIR/target.txt"

sync_lsposed_scope() {
    [ -f "$TARGET_FILE" ] || return 0

    # Sync to XSent runtime target marker
    cp "$TARGET_FILE" /data/local/tmp/xsent_targets.list 2>/dev/null
    chmod 0644 /data/local/tmp/xsent_targets.list 2>/dev/null

    # Sync to module directory
    [ -n "$MODDIR" ] && cp "$TARGET_FILE" "$MODDIR/target.txt" 2>/dev/null
}
