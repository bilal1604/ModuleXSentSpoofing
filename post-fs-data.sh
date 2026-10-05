#!/system/bin/sh
# XSent Spoof v1.0 - Master Early Boot Orchestrator (post-fs-data)

export PATH="/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:/data/adb/mksu/bin:/data/adb/sukisu/bin:/data/adb/ksud:/data/adb/bin:/sbin:/debug_ramdisk:/system/bin:/system/xbin:/vendor/bin:$PATH"

MODDIR=${0%/*}
CONFIG_DIR="/data/adb/xsent-spoof"
CONFIG_PROP="$CONFIG_DIR/system.prop"
RUNTIME_PROP="$MODDIR/runtime.prop"
DEFAULT_PROP="$MODDIR/defaults.prop"

command -v resetprop >/dev/null 2>&1 || exit 0

AUTH_GUARD="$MODDIR/scripts/auth_guard.sh"
[ -r "$AUTH_GUARD" ] || exit 0
. "$AUTH_GUARD"
xsent_require_auth "$CONFIG_DIR" "$MODDIR" || exit 0

validate_identity_snapshot() {
    PROP_FILE="$1"
    [ -s "$PROP_FILE" ] || return 1
    for KEY in brand manufacturer marketing marketing_name device_name tech_model model device product board platform soc_model soc_manufacturer fingerprint os release sdk security_patch; do
        # A literal dot followed by any value is portable across toybox/busybox.
        # Some Android toybox grep builds do not implement the GNU BRE \+ token.
        grep -q "^persist\.sys\.xsent\.identity\.$KEY=." "$PROP_FILE" 2>/dev/null || return 1
    done
    OS_VALUE="$(sed -n 's/^persist\.sys\.xsent\.identity\.os=//p' "$PROP_FILE" | tail -n 1)"
    RELEASE_VALUE="$(sed -n 's/^persist\.sys\.xsent\.identity\.release=//p' "$PROP_FILE" | tail -n 1)"
    [ "$OS_VALUE" = "$RELEASE_VALUE" ]
}

clear_stale_identity() {
    PROP_FILE="$1"
    resetprop 2>/dev/null | sed -n 's/^\[\(persist\.sys\.xsent\.identity\.[^]]*\)\]:.*/\1/p' | while IFS= read -r KEY; do
        case "$KEY" in
            persist.sys.xsent.identity.physical_*) continue ;;
        esac
        grep -Fq "$KEY=" "$PROP_FILE" 2>/dev/null || resetprop --delete "$KEY" 2>/dev/null || true
    done
}

get_id() { resetprop "persist.sys.xsent.identity.$1" 2>/dev/null; }
get_flag() { resetprop "persist.sys.xsent.$1" 2>/dev/null; }

system_sync_enabled() {
    case "$(get_flag system_sync_mode | tr '[:upper:]' '[:lower:]')" in
        off|0|false|no) return 1 ;;
        *) return 0 ;;
    esac
}

purge_legacy_sdk_flag() {
    for PROP_FILE in "$CONFIG_PROP" "$RUNTIME_PROP" /data/local/tmp/XSent_runtime.prop; do
        [ -f "$PROP_FILE" ] || continue
        sed -i '/^persist\.sys\.xsent\.experimental_sdk_spoof=/d' "$PROP_FILE" 2>/dev/null || true
    done
    resetprop --delete persist.sys.xsent.experimental_sdk_spoof 2>/dev/null || true
}

# Older builds wrote verified-boot / lock-state props into system.prop, which
# `resetprop -f` then applied GLOBALLY. That global spoof crashes Tencent SOTER
# on KernelSU/APatch because the service reads the spoofed value while its TEE
# attestation certificate still carries the physical unlocked state. Strip
# those lines from upgraded installations unless the user explicitly opted in.
purge_legacy_boot_state() {
    # Read the opt-in flag from the snapshot files directly: at this point in
    # early boot the live resetprop value may not be loaded yet.
    for PROP_FILE in "$CONFIG_PROP" "$RUNTIME_PROP" "$DEFAULT_PROP"; do
        [ -f "$PROP_FILE" ] || continue
        if [ "$(sed -n 's/^persist\.sys\.xsent\.spoof_verified_boot=//p' "$PROP_FILE" | tail -n 1 | tr '[:upper:]' '[:lower:]')" = "on" ]; then
            return 0
        fi
    done
    for PROP_FILE in "$CONFIG_PROP" "$RUNTIME_PROP" "$DEFAULT_PROP" /data/local/tmp/XSent_runtime.prop; do
        [ -f "$PROP_FILE" ] || continue
        sed -i \
            -e '/^ro\.boot\.vbmeta\.device_state=/d' \
            -e '/^vendor\.boot\.vbmeta\.device_state=/d' \
            -e '/^ro\.boot\.verifiedbootstate=/d' \
            -e '/^vendor\.boot\.verifiedbootstate=/d' \
            -e '/^ro\.boot\.flash\.locked=/d' \
            -e '/^ro\.boot\.veritymode=/d' \
            -e '/^sys\.oem_unlock_allowed=/d' \
            -e '/^ro\.secureboot\.lockstate=/d' \
            -e '/^ro\.boot\.secureboot=/d' \
            -e '/^ro\.boot\.realmebootstate=/d' \
            -e '/^ro\.boot\.realme\.lockstate=/d' \
            -e '/^ro\.boot\.oppobootstate=/d' \
            -e '/^ro\.boot\.oppo\.lockstate=/d' \
            -e '/^ro\.is_ever_orange=/d' \
            -e '/^ro\.boot\.orange_state=/d' \
            -e '/^ro\.boot\.vivobootstate=/d' \
            -e '/^ro\.boot\.vivo\.lockstate=/d' \
            "$PROP_FILE" 2>/dev/null || true
    done
    # Do not touch the live bootloader properties. At post-fs-data they still
    # contain the physical values; resetprop deletion would make the keys empty
    # and can be just as inconsistent for TEE/SOTER as spoofed values.
}

load_xsent_props() {
    PROP_FILE="$1"
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            persist.sys.xsent.*=*) ;;
            *) continue ;;
        esac
        KEY="${line%%=*}"
        VALUE="${line#*=}"
        resetprop "$KEY" "$VALUE" 2>/dev/null || true
    done < "$PROP_FILE"
}

purge_legacy_sdk_flag
purge_legacy_boot_state
[ "$(get_flag safe_test_mode)" = "on" ] && exit 0

# Seed the selected synchronization layer from the active snapshot.
ACTIVE_PROP=""
if [ -f "$CONFIG_PROP" ]; then
    ACTIVE_PROP="$CONFIG_PROP"
elif [ -f "$RUNTIME_PROP" ]; then
    ACTIVE_PROP="$RUNTIME_PROP"
elif [ -f "$DEFAULT_PROP" ]; then
    ACTIVE_PROP="$DEFAULT_PROP"
fi

[ -n "$ACTIVE_PROP" ] || exit 0
validate_identity_snapshot "$ACTIVE_PROP" || exit 0
clear_stale_identity "$ACTIVE_PROP"

FILE_SYNC_MODE="$(sed -n 's/^persist\.sys\.xsent\.system_sync_mode=//p' "$ACTIVE_PROP" | tail -n 1 | tr '[:upper:]' '[:lower:]')"
case "$FILE_SYNC_MODE" in
    off|0|false|no)
        load_xsent_props "$ACTIVE_PROP"
        if [ -r "$MODDIR/scripts/restore_fast_baseline.sh" ]; then
            . "$MODDIR/scripts/restore_fast_baseline.sh"
            restore_fast_baseline
        fi
        ;;
    *) resetprop -f "$ACTIVE_PROP" 2>/dev/null || true ;;
esac

# XSent reads this world-readable mirror from every scoped app process.
cp -f "$ACTIVE_PROP" /data/local/tmp/XSent_runtime.prop 2>/dev/null || true
[ -f "$CONFIG_DIR/target.txt" ] && cp -f "$CONFIG_DIR/target.txt" /data/local/tmp/xsent_targets.list 2>/dev/null || true
[ -f "$CONFIG_DIR/shield_blacklist.txt" ] && cp -f "$CONFIG_DIR/shield_blacklist.txt" /data/local/tmp/xsent_hide.list 2>/dev/null || true
chmod 666 /data/local/tmp/XSent_runtime.prop /data/local/tmp/xsent_targets.list /data/local/tmp/xsent_hide.list 2>/dev/null || true
chcon u:object_r:shell_data_file:s0 /data/local/tmp/XSent_runtime.prop /data/local/tmp/xsent_targets.list /data/local/tmp/xsent_hide.list 2>/dev/null || true

# Native property layer is active only in Synchronize System mode.
if system_sync_enabled; then
    # 1. Global Props (for OS < 15 / Global resetprop)
    [ -f "$MODDIR/global/global_props.sh" ] && . "$MODDIR/global/global_props.sh" && apply_global_props "$ACTIVE_PROP"

    # 2. Core Identity & Treble Partitions
    [ -f "$MODDIR/core/identity.sh" ] && . "$MODDIR/core/identity.sh" && apply_identity

    # 3. Core Hardware (Bootloader & Radio/Baseband)
    [ -f "$MODDIR/core/hardware.sh" ] && . "$MODDIR/core/hardware.sh" && apply_hardware

    # 4. Samsung Knox & CSC
    [ -f "$MODDIR/core/knox_csc.sh" ] && . "$MODDIR/core/knox_csc.sh" && apply_knox_csc
fi

# 5. Verified Boot & Lock State Cloak
# Global boot-state spoofing is DISABLED by default. Applying
# ro.boot.verifiedbootstate / ro.boot.flash.locked / ro.boot.vbmeta.device_state
# globally makes Tencent SOTER (com.tencent.soter.soterserver) read spoofed
# values while its TEE attestation certificate still carries the physical
# unlocked state, which crashes the service on KernelSU/APatch. Target apps
# still receive these values per-process via the XSent hook
# (XSentModule.hookBootStateProps). Opt back in only if a specific app
# requires a global value and you accept the SOTER risk.
if [ "$(resetprop persist.sys.xsent.spoof_verified_boot 2>/dev/null)" = "on" ]; then
    [ -f "$MODDIR/global/verified_boot.sh" ] && . "$MODDIR/global/verified_boot.sh" && apply_verified_boot
fi

# 6. Shield & Hide Root / Anti-Detection
[ -f "$MODDIR/shield/hide_root.sh" ] && . "$MODDIR/shield/hide_root.sh"

# 7. Framework Scope Synchronization
[ -f "$MODDIR/framework/scope_sync.sh" ] && . "$MODDIR/framework/scope_sync.sh" && sync_lsposed_scope

# 8. Play Integrity & Keybox Isolation
[ -f "$MODDIR/shield/play_integrity.sh" ] && . "$MODDIR/shield/play_integrity.sh"

if [ -f "$CONFIG_DIR/target.txt" ]; then
    TARGET_COUNT="$(grep -Ev '^[[:space:]]*($|#)' "$CONFIG_DIR/target.txt" 2>/dev/null | wc -l)"
    [ "$TARGET_COUNT" -gt 0 ] && resetprop persist.sys.xsent.active_targets "$TARGET_COUNT" 2>/dev/null
fi

sync
exit 0
