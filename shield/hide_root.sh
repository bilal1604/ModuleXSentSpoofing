#!/system/bin/sh
# XSent Spoof Shield - Hide Root & Anti-Detection Engine

export PATH="/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:/data/adb/mksu/bin:/data/adb/sukisu/bin:/data/adb/ksud:/data/adb/bin:/sbin:/debug_ramdisk:/system/bin:/system/xbin:/vendor/bin:$PATH"

command -v resetprop >/dev/null 2>&1 || exit 0

CONFIG_DIR="/data/adb/xsent-spoof"

shamiko_active() {
    for dir in /data/adb/modules/*; do
        [ -d "$dir" ] || continue
        [ -f "$dir/disable" ] && continue
        [ -f "$dir/remove" ] && continue
        base="$(basename "$dir" | tr '[:upper:]' '[:lower:]')"
        meta="$(grep -iE '^(id|name)=' "$dir/module.prop" 2>/dev/null | tr '[:upper:]' '[:lower:]')"
        case "$base $meta" in *shamiko*) return 0 ;; esac
    done
    return 1
}

publish_concealment_scope() {
    OUTPUT="$1"
    : > "$OUTPUT"
    cat "$CONFIG_DIR/shield_blacklist.txt" 2>/dev/null >> "$OUTPUT"
    sort -u "$OUTPUT" -o "$OUTPUT"
}

sync_magisk_denylist() {
    command -v magisk >/dev/null 2>&1 || [ -x /data/adb/magisk/magisk ] || return 0
    shamiko_active && return 0
    magisk --denylist enable >/dev/null 2>&1 || return 0

    LIVE_SCOPE="/data/local/tmp/xsent_denylist_scope.$$"
    publish_concealment_scope "$LIVE_SCOPE"
    while IFS= read -r pkg || [ -n "$pkg" ]; do
        case "$pkg" in
            ''|*[!A-Za-z0-9._:]*|io.xsent.spoof|*magisk*|*kernelsu*|*lsposed*|*xposed*|*zygisksu*) continue ;;
        esac
        pkg="${pkg%%:*}"
        pm path "$pkg" >/dev/null 2>&1 || continue
        magisk --denylist add "$pkg" "$pkg" >/dev/null 2>&1 || \
            magisk --denylist add "$pkg" >/dev/null 2>&1 || true
        dumpsys package "$pkg" 2>/dev/null | grep -oE 'processName=[^ ]+' | cut -d= -f2- | sort -u | \
        while IFS= read -r proc; do
            [ -n "$proc" ] || continue
            case "$proc" in :*) proc="$pkg$proc" ;; esac
            magisk --denylist add "$pkg" "$proc" >/dev/null 2>&1 || true
        done
    done < "$LIVE_SCOPE"
    rm -f "$LIVE_SCOPE"
}

apply_hide_root() {
    HIDE_ROOT="$(resetprop persist.sys.xsent.hide_root 2>/dev/null)"
    case "$HIDE_ROOT" in
        off|0|false|no) return 0 ;;
    esac

    if [ -f "$CONFIG_DIR/shield_blacklist.txt" ]; then
        cp -f "$CONFIG_DIR/shield_blacklist.txt" /data/local/tmp/xsent_hide.list 2>/dev/null || true
        chmod 0666 /data/local/tmp/xsent_hide.list 2>/dev/null || true
        chcon u:object_r:shell_data_file:s0 /data/local/tmp/xsent_hide.list 2>/dev/null || true
    fi

    # 1. Production Security Properties
    resetprop ro.debuggable "0" 2>/dev/null
    resetprop ro.secure "1" 2>/dev/null
    resetprop ro.adb.secure "1" 2>/dev/null
    resetprop ro.build.type "user" 2>/dev/null
    resetprop ro.build.tags "release-keys" 2>/dev/null
    resetprop ro.vendor.build.type "user" 2>/dev/null
    resetprop ro.vendor.build.tags "release-keys" 2>/dev/null
    resetprop ro.system.build.type "user" 2>/dev/null
    resetprop ro.system.build.tags "release-keys" 2>/dev/null

    # 2. SELinux Enforcing Cloak
    resetprop ro.boot.selinux "enforcing" 2>/dev/null
    resetprop persist.sys.selinux "enforcing" 2>/dev/null

    # 3. ADB status is concealed only inside scoped target processes by the
    # XSent hook. Never mutate adbd lifecycle or the host USB state here.

    # 4. Hide Sensitive Magisk / KSU Strings
    for key in $(resetprop 2>/dev/null | grep -iE 'magisk|kernelsu|apatch|test-keys' | awk -F'[][]' '{print $2}'); do
        case "$key" in
            persist.sys.xsent.*) continue ;;
            ro.build.tags|*.build.tags) resetprop "$key" "release-keys" 2>/dev/null ;;
            ro.build.type|*.build.type) resetprop "$key" "user" 2>/dev/null ;;
            *) resetprop --delete "$key" 2>/dev/null || true ;;
        esac
    done

    # Mount concealment follows the list owned by XSent Concealment. Identity
    # targets from XSent Manager are intentionally not imported here.
    sync_magisk_denylist
}

apply_hide_root
