#!/system/bin/sh
# XSent Spoof Runtime Endpoint - Immediate RAM Identity Injection
# Called by XSent APK on Sync or Apply Profile

export PATH="/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:/data/adb/mksu/bin:/data/adb/sukisu/bin:/data/adb/ksud:/data/adb/bin:/sbin:/debug_ramdisk:/system/bin:/system/xbin:/vendor/bin:$PATH"

MODDIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="/data/adb/xsent-spoof"
CONFIG_PROP="$CONFIG_DIR/system.prop"

command -v resetprop >/dev/null 2>&1 || exit 127

validate_identity_snapshot() {
    PROP_FILE="$1"
    [ -s "$PROP_FILE" ] || return 1
    for KEY in brand manufacturer marketing marketing_name device_name tech_model model device product board platform soc_model soc_manufacturer fingerprint os release sdk security_patch; do
        # Keep validation compatible with Android toybox grep. Requiring one
        # character after '=' rejects empty identity fields without GNU \+.
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

# Strip legacy global verified-boot props from the snapshot unless the user
# opted in. A global boot-state spoof crashes Tencent SOTER on KernelSU/APatch
# because the service reads the spoofed value while its TEE attestation
# certificate still carries the physical unlocked state. Target apps still get
# spoofed boot state per-process via the XSent hook layer.
purge_legacy_boot_state() {
    # Read the opt-in flag from the snapshot file directly so the decision does
    # not depend on a possibly-stale live resetprop value.
    if [ "$(sed -n 's/^persist\.sys\.xsent\.spoof_verified_boot=//p' "$CONFIG_PROP" | tail -n 1 | tr '[:upper:]' '[:lower:]')" = "on" ]; then
        return 0
    fi
    for PROP_FILE in "$CONFIG_PROP" "$MODDIR/runtime.prop" "$MODDIR/defaults.prop" /data/local/tmp/XSent_runtime.prop; do
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
    # Never delete live bootloader properties. Magisk resetprop deletion makes
    # these keys empty instead of restoring their physical boot values. If a
    # global spoof was active earlier in this boot, the original values return
    # on the required full reboot.
}

[ -f "$CONFIG_PROP" ] || exit 1
validate_identity_snapshot "$CONFIG_PROP" || exit 2
purge_legacy_boot_state

SYSTEM_SYNC_MODE="$(sed -n 's/^persist\.sys\.xsent\.system_sync_mode=//p' "$CONFIG_PROP" | tail -n 1 | tr '[:upper:]' '[:lower:]')"
case "$SYSTEM_SYNC_MODE" in
    off|0|false|no)
        [ -f "$MODDIR/scripts/apply_xsent_runtime.sh" ] || exit 1
        exec sh "$MODDIR/scripts/apply_xsent_runtime.sh"
        ;;
esac

clear_stale_identity "$CONFIG_PROP"
resetprop -f "$CONFIG_PROP" 2>/dev/null || true

# Clear stale GMS-facing GSF ID props left behind by older XSent versions.
# These props (persist.com.google.services.id, android.gsf.gservicesid) used to
# be set globally to the per-profile spoofed GSF ID, which made the real GMS
# process see a different device identity on every profile switch and drop the
# Google account from the system AccountManager. Deleting them lets GMS fall
# back to the real GSF ID stored in gservices.db, preserving the logged-in
# account. Target apps still receive the spoofed GSF ID via the Xposed hook
# layer (XSentModule.hookGsfId), which intercepts SystemProperties.get for
# these keys in target processes only.
resetprop --delete persist.com.google.services.id 2>/dev/null || true
resetprop --delete android.gsf.gservicesid 2>/dev/null || true

# Some root implementations (notably KernelSU) partially apply `resetprop -f`.
# Always publish the complete private snapshot one property at a time so a
# correct model marker cannot hide a stale SoC (or any other stale field).
EXPECTED_MODEL="$(sed -n 's/^persist\.sys\.xsent\.identity\.tech_model=//p' "$CONFIG_PROP" 2>/dev/null | tail -n 1)"
[ -z "$EXPECTED_MODEL" ] && EXPECTED_MODEL="$(sed -n 's/^persist\.sys\.xsent\.identity\.model=//p' "$CONFIG_PROP" 2>/dev/null | tail -n 1)"
while IFS= read -r LINE || [ -n "$LINE" ]; do
    case "$LINE" in
        persist.sys.xsent.*=*) ;;
        *) continue ;;
    esac
    KEY="${LINE%%=*}"
    VALUE="${LINE#*=}"
    resetprop "$KEY" "$VALUE" 2>/dev/null || exit 2
done < "$CONFIG_PROP"

# Apply SoC identity explicitly. Some resetprop implementations accept `-f`
# while leaving read-only SoC keys unchanged, and Build.SOC_* caches these keys
# very early. The XSent layer handles scoped processes; this block owns the
# global values used by Synchronize System.
SOC_MODEL="$(sed -n 's/^persist\.sys\.xsent\.identity\.soc_model=//p' "$CONFIG_PROP" 2>/dev/null | tail -n 1)"
SOC_MANUFACTURER="$(sed -n 's/^persist\.sys\.xsent\.identity\.soc_manufacturer=//p' "$CONFIG_PROP" 2>/dev/null | tail -n 1)"
if [ -n "$SOC_MODEL" ]; then
    resetprop ro.soc.model "$SOC_MODEL" 2>/dev/null || true
    resetprop ro.vendor.soc.model "$SOC_MODEL" 2>/dev/null || true
fi
if [ -n "$SOC_MANUFACTURER" ]; then
    resetprop ro.soc.manufacturer "$SOC_MANUFACTURER" 2>/dev/null || true
    resetprop ro.vendor.soc.manufacturer "$SOC_MANUFACTURER" 2>/dev/null || true
fi

# Copy world-readable runtime prop and target lists for non-root app process hooks
[ -f "$CONFIG_PROP" ] && cp -f "$CONFIG_PROP" /data/local/tmp/XSent_runtime.prop 2>/dev/null || true
[ -f "$CONFIG_PROP" ] && cp -f "$CONFIG_PROP" "$MODDIR/runtime.prop" 2>/dev/null || true
[ -f "$CONFIG_PROP" ] && cp -f "$CONFIG_PROP" "$MODDIR/defaults.prop" 2>/dev/null || true
[ -f "$CONFIG_DIR/target.txt" ] && cp -f "$CONFIG_DIR/target.txt" /data/local/tmp/xsent_targets.list 2>/dev/null || true
[ -f "$CONFIG_DIR/shield_blacklist.txt" ] && cp -f "$CONFIG_DIR/shield_blacklist.txt" /data/local/tmp/xsent_hide.list 2>/dev/null || true
chmod 666 /data/local/tmp/XSent_runtime.prop /data/local/tmp/xsent_targets.list /data/local/tmp/xsent_hide.list 2>/dev/null || true
chcon u:object_r:shell_data_file:s0 /data/local/tmp/XSent_runtime.prop /data/local/tmp/xsent_targets.list /data/local/tmp/xsent_hide.list 2>/dev/null || true

# A successful resetprop process is not enough: some root implementations can
# accept the file while leaving its values unapplied. Verify XSent's marker;
# the APK checks the global ro.product value after target processes are stopped.
EXPECTED_MODEL="$(sed -n 's/^persist\.sys\.xsent\.identity\.tech_model=//p' "$CONFIG_PROP" 2>/dev/null | tail -n 1)"
[ -z "$EXPECTED_MODEL" ] && EXPECTED_MODEL="$(sed -n 's/^persist\.sys\.xsent\.identity\.model=//p' "$CONFIG_PROP" 2>/dev/null | tail -n 1)"
[ -n "$EXPECTED_MODEL" ] || exit 2
# If the per-property fallback above still could not apply the value, the
# identity cannot be injected on this root implementation. Report failure so
# the APK can surface a clear message instead of silently succeeding.
[ "$(resetprop persist.sys.xsent.identity.tech_model 2>/dev/null)" = "$EXPECTED_MODEL" ] || exit 2
[ -n "$SOC_MODEL" ] || exit 2
[ -n "$SOC_MANUFACTURER" ] || exit 2
[ "$(resetprop ro.soc.model 2>/dev/null)" = "$SOC_MODEL" ] || exit 2
[ "$(resetprop ro.vendor.soc.model 2>/dev/null)" = "$SOC_MODEL" ] || exit 2
[ "$(resetprop ro.soc.manufacturer 2>/dev/null)" = "$SOC_MANUFACTURER" ] || exit 2
[ "$(resetprop ro.vendor.soc.manufacturer 2>/dev/null)" = "$SOC_MANUFACTURER" ] || exit 2

# Apply native side effects that cannot be represented in system.prop.
DEVICE_NAME="$(get_id marketing_name)"
[ -z "$DEVICE_NAME" ] && DEVICE_NAME="$(get_id tech_model)"
if [ -n "$DEVICE_NAME" ]; then
    settings put global device_name "$DEVICE_NAME" 2>/dev/null || true
    settings put secure bluetooth_name "$DEVICE_NAME" 2>/dev/null || true
    settings put global bluetooth_name "$DEVICE_NAME" 2>/dev/null || true
    settings put global synced_device_name "$DEVICE_NAME" 2>/dev/null || true
    settings put global market_name "$DEVICE_NAME" 2>/dev/null || true
    settings put system device_name "$DEVICE_NAME" 2>/dev/null || true
fi

ANDROID_ID="$(get_id android_id)"
if [ -n "$ANDROID_ID" ]; then
    settings put secure android_id "$ANDROID_ID" 2>/dev/null || true
    settings put global android_id "$ANDROID_ID" 2>/dev/null || true
    settings put system android_id "$ANDROID_ID" 2>/dev/null || true
fi

GAID="$(get_id advertising_id)"
if [ -n "$GAID" ]; then
    for gms_dir in /data/data/com.google.android.gms /data/user/0/com.google.android.gms /data/user_de/0/com.google.android.gms; do
        [ -d "$gms_dir/shared_prefs" ] || continue
        printf '<?xml version="1.0" encoding="utf-8" standalone="yes" ?>\n<map>\n    <string name="adid_key">%s</string>\n    <boolean name="enable_limit_ad_tracking" value="false" />\n</map>\n' "$GAID" > "$gms_dir/shared_prefs/adid_settings.xml" 2>/dev/null || true
        chmod 660 "$gms_dir/shared_prefs/adid_settings.xml" 2>/dev/null || true
        chown "$(stat -c '%u:%g' "$gms_dir" 2>/dev/null || echo '1000:1000')" "$gms_dir/shared_prefs/adid_settings.xml" 2>/dev/null || true
    done
fi

# GSF ID: intentionally NOT injected into gservices.db or the GMS-facing
# system properties. The GSF ID stored in gservices.db is the real device
# identity that GMS uses to bind the Google account. Overwriting it on every
# profile switch makes GMS see a "different device" and drop the account from
# the system AccountManager. Target apps receive the spoofed GSF ID via the
# Xposed hook layer (XSentModule.hookGsfId), which intercepts
# SystemProperties.get for the GMS-facing keys in target processes only.
# The XSent-specific prop (persist.sys.xsent.identity.gsf_id) is already
# applied by the resetprop -f call above and is read by the hook layer.

exit 0
