#!/system/bin/sh
# XSent Spoof v1.0 - Master Late Boot Orchestrator (service.sh)

export PATH="/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:/data/adb/mksu/bin:/data/adb/sukisu/bin:/data/adb/ksud:/data/adb/bin:/sbin:/debug_ramdisk:/system/bin:/system/xbin:/vendor/bin:$PATH"

MODDIR=${0%/*}
CONFIG_DIR="/data/adb/xsent-spoof"

get_id() { resetprop "persist.sys.xsent.identity.$1" 2>/dev/null; }
get_flag() { resetprop "persist.sys.xsent.$1" 2>/dev/null; }

system_sync_enabled() {
    case "$(get_flag system_sync_mode | tr '[:upper:]' '[:lower:]')" in
        off|0|false|no) return 1 ;;
        *) return 0 ;;
    esac
}

i=0
while [ "$i" -lt 180 ]; do
    [ "$(getprop sys.boot_completed 2>/dev/null)" = "1" ] && break
    sleep 1
    i=$((i + 1))
done
sleep 3

# Complete a fresh install/update that could not run while the module ZIP was
# flashed. The helper is idempotent and skips an APK already installed by this
# module version.
if [ -x "$MODDIR/scripts/install_xsent_apk.sh" ]; then
    "$MODDIR/scripts/install_xsent_apk.sh" >> /data/local/tmp/xsent_apk_install.log 2>&1 || true
fi

command -v resetprop >/dev/null 2>&1 || exit 0

AUTH_GUARD="$MODDIR/scripts/auth_guard.sh"
[ -r "$AUTH_GUARD" ] || exit 0
. "$AUTH_GUARD"
xsent_require_auth "$CONFIG_DIR" "$MODDIR" || exit 0

# post-fs-data can run before the device clock is restored. In that case the
# authorization lease is intentionally rejected there and no identity snapshot
# reaches resetprop. Re-load the authoritative snapshot after boot, when the
# lease has just been validated, so System mode cannot fall back to a stale
# runtime.prop value.
ACTIVE_PROP=""
if [ -s "$CONFIG_DIR/system.prop" ]; then
    ACTIVE_PROP="$CONFIG_DIR/system.prop"
elif [ -s "$MODDIR/runtime.prop" ]; then
    ACTIVE_PROP="$MODDIR/runtime.prop"
elif [ -s "$MODDIR/defaults.prop" ]; then
    ACTIVE_PROP="$MODDIR/defaults.prop"
fi

if [ -n "$ACTIVE_PROP" ]; then
    SNAPSHOT_MODE="$(sed -n 's/^persist\.sys\.xsent\.system_sync_mode=//p' "$ACTIVE_PROP" | tail -n 1 | tr '[:upper:]' '[:lower:]')"
    case "$SNAPSHOT_MODE" in
        off|0|false|no)
            while IFS= read -r line || [ -n "$line" ]; do
                case "$line" in persist.sys.xsent.*=*) ;; *) continue ;; esac
                resetprop "${line%%=*}" "${line#*=}" 2>/dev/null || true
            done < "$ACTIVE_PROP"
            if [ -r "$MODDIR/scripts/restore_fast_baseline.sh" ]; then
                . "$MODDIR/scripts/restore_fast_baseline.sh"
                restore_fast_baseline
            fi
            ;;
        *) resetprop -f "$ACTIVE_PROP" 2>/dev/null || true ;;
    esac

    if [ "$ACTIVE_PROP" = "$CONFIG_DIR/system.prop" ]; then
        cp -f "$ACTIVE_PROP" "$MODDIR/runtime.prop" 2>/dev/null || true
        cp -f "$ACTIVE_PROP" "$MODDIR/defaults.prop" 2>/dev/null || true
    fi
    cp -f "$ACTIVE_PROP" /data/local/tmp/XSent_runtime.prop 2>/dev/null || true
    [ -f "$CONFIG_DIR/target.txt" ] && cp -f "$CONFIG_DIR/target.txt" /data/local/tmp/xsent_targets.list 2>/dev/null || true
    chmod 0666 /data/local/tmp/XSent_runtime.prop /data/local/tmp/xsent_targets.list 2>/dev/null || true
    chcon u:object_r:shell_data_file:s0 /data/local/tmp/XSent_runtime.prop /data/local/tmp/xsent_targets.list 2>/dev/null || true
fi

[ "$(get_flag safe_test_mode)" = "on" ] && exit 0

if system_sync_enabled; then
    # 1. Hardware Re-Lock (Lock Bootloader & Radio/Baseband against RIL override)
    [ -f "$MODDIR/core/hardware.sh" ] && . "$MODDIR/core/hardware.sh" && apply_hardware

    # 2. Core Identity Re-Apply after system_server is ready.
    [ -f "$MODDIR/core/identity.sh" ] && . "$MODDIR/core/identity.sh" && apply_identity

    # 3. SIM & Carrier Operator Telephony Lock
    [ -f "$MODDIR/telephony/sim_spoof.sh" ] && . "$MODDIR/telephony/sim_spoof.sh" && apply_sim_spoof

    # 4. Network & Device IDs
    [ -f "$MODDIR/telephony/network_ids.sh" ] && . "$MODDIR/telephony/network_ids.sh" && apply_network_ids
fi

# 5. Shield & Anti-Detection Late Lock
[ -f "$MODDIR/shield/hide_root.sh" ] && . "$MODDIR/shield/hide_root.sh"

# 6. Native Mock Location & Timezone
system_sync_enabled && [ -f "$MODDIR/location/apply_location.sh" ] && . "$MODDIR/location/apply_location.sh"

# 7. Play Integrity & Keybox Sync
[ -f "$MODDIR/shield/play_integrity.sh" ] && . "$MODDIR/shield/play_integrity.sh"

sync
exit 0
