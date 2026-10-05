#!/system/bin/sh
# XSent Spoof Runtime Endpoint - XSent Hook Layer + SoC Compatibility Mirror

export PATH="/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:/data/adb/mksu/bin:/data/adb/sukisu/bin:/data/adb/ksud:/data/adb/bin:/sbin:/debug_ramdisk:/system/bin:/system/xbin:/vendor/bin:$PATH"

MODDIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="/data/adb/xsent-spoof"
CONFIG_PROP="$CONFIG_DIR/system.prop"

command -v resetprop >/dev/null 2>&1 || exit 127
[ -s "$CONFIG_PROP" ] || exit 1

validate_identity_snapshot() {
    PROP_FILE="$1"
    for KEY in brand manufacturer marketing marketing_name device_name tech_model model device product board platform soc_model soc_manufacturer fingerprint os release sdk security_patch; do
        grep -q "^persist\.sys\.xsent\.identity\.$KEY=." "$PROP_FILE" 2>/dev/null || return 1
    done
    OS_VALUE="$(sed -n 's/^persist\.sys\.xsent\.identity\.os=//p' "$PROP_FILE" | tail -n 1)"
    RELEASE_VALUE="$(sed -n 's/^persist\.sys\.xsent\.identity\.release=//p' "$PROP_FILE" | tail -n 1)"
    [ "$OS_VALUE" = "$RELEASE_VALUE" ]
}

validate_identity_snapshot "$CONFIG_PROP" || exit 2

# Strip legacy global verified-boot props from the snapshot unless the user
# opted in. A global boot-state spoof crashes Tencent SOTER on KernelSU/APatch
# because the service reads the spoofed value while its TEE attestation
# certificate still carries the physical unlocked state. Target apps still get
# spoofed boot state per-process via the XSent hook layer.
if [ "$(sed -n 's/^persist\.sys\.xsent\.spoof_verified_boot=//p' "$CONFIG_PROP" | tail -n 1 | tr '[:upper:]' '[:lower:]')" != "on" ]; then
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
    # Do not delete the live ro.boot properties here. `resetprop --delete`
    # removes them from Android's property area; it does not restore the value
    # supplied by the bootloader. On a clean boot the lines above are already
    # absent, so leaving the live properties untouched preserves the physical
    # values for SOTER and every non-target process.
fi

# A previous System sync can leave Settings-backed identifiers behind even
# after read-only properties return to the physical ROM values. Restore those
# globals before publishing the scoped Fast snapshot.
if [ -r "$MODDIR/scripts/restore_fast_baseline.sh" ]; then
    . "$MODDIR/scripts/restore_fast_baseline.sh"
    restore_fast_baseline
fi

# Remove the obsolete experimental gate from upgraded installations. Profile OS
# identity is always published to every XSent-scoped target.
sed -i '/^persist\.sys\.xsent\.experimental_sdk_spoof=/d' "$CONFIG_PROP" 2>/dev/null || true
resetprop --delete persist.sys.xsent.experimental_sdk_spoof 2>/dev/null || true

# Clear stale GMS-facing GSF ID props left behind by older XSent versions.
# These used to be set globally to the per-profile spoofed GSF ID, which made
# the real GMS process see a different device identity on every profile switch
# and drop the Google account from the system AccountManager. Deleting them lets
# GMS fall back to the stable GSF ID in gservices.db, preserving the account.
# Target apps still receive the spoofed GSF ID via the Xposed hook layer.
resetprop --delete persist.com.google.services.id 2>/dev/null || true
resetprop --delete android.gsf.gservicesid 2>/dev/null || true

# Publish XSent's private configuration namespace as one deterministic
# transaction. A narrow four-property SoC mirror is applied below because apps
# such as DevCheck may read Build.SOC_* before the deferred XSent hook attaches.
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
        persist.sys.xsent.*=*) ;;
        *) continue ;;
    esac
    KEY="${line%%=*}"
    VALUE="${line#*=}"
    resetprop "$KEY" "$VALUE" 2>/dev/null || exit 1
done < "$CONFIG_PROP"

cp -f "$CONFIG_PROP" /data/local/tmp/XSent_runtime.prop 2>/dev/null || exit 1
cp -f "$CONFIG_PROP" "$MODDIR/runtime.prop" 2>/dev/null || true
cp -f "$CONFIG_PROP" "$MODDIR/defaults.prop" 2>/dev/null || true
[ -f "$CONFIG_DIR/target.txt" ] && cp -f "$CONFIG_DIR/target.txt" /data/local/tmp/xsent_targets.list 2>/dev/null || true
[ -f "$CONFIG_DIR/shield_blacklist.txt" ] && cp -f "$CONFIG_DIR/shield_blacklist.txt" /data/local/tmp/xsent_hide.list 2>/dev/null || true
chmod 666 /data/local/tmp/XSent_runtime.prop /data/local/tmp/xsent_targets.list /data/local/tmp/xsent_hide.list 2>/dev/null || true
chcon u:object_r:shell_data_file:s0 /data/local/tmp/XSent_runtime.prop /data/local/tmp/xsent_targets.list /data/local/tmp/xsent_hide.list 2>/dev/null || true

EXPECTED_MODEL="$(sed -n 's/^persist\.sys\.xsent\.identity\.tech_model=//p' "$CONFIG_PROP" | tail -n 1)"
EXPECTED_SOC_MODEL="$(sed -n 's/^persist\.sys\.xsent\.identity\.soc_model=//p' "$CONFIG_PROP" | tail -n 1)"
EXPECTED_SOC_MANUFACTURER="$(sed -n 's/^persist\.sys\.xsent\.identity\.soc_manufacturer=//p' "$CONFIG_PROP" | tail -n 1)"
[ -n "$EXPECTED_MODEL" ] || exit 2
[ -n "$EXPECTED_SOC_MODEL" ] || exit 2
[ -n "$EXPECTED_SOC_MANUFACTURER" ] || exit 2
[ "$(resetprop persist.sys.xsent.identity.tech_model 2>/dev/null)" = "$EXPECTED_MODEL" ] || exit 2
[ "$(resetprop persist.sys.xsent.identity.soc_model 2>/dev/null)" = "$EXPECTED_SOC_MODEL" ] || exit 2
[ "$(resetprop persist.sys.xsent.identity.soc_manufacturer 2>/dev/null)" = "$EXPECTED_SOC_MANUFACTURER" ] || exit 2

# Keep Fast Sync and System Sync on the same authoritative SoC snapshot. This
# intentionally does not publish the remaining global identity properties.
resetprop ro.soc.model "$EXPECTED_SOC_MODEL" 2>/dev/null || exit 2
resetprop ro.vendor.soc.model "$EXPECTED_SOC_MODEL" 2>/dev/null || exit 2
resetprop ro.soc.manufacturer "$EXPECTED_SOC_MANUFACTURER" 2>/dev/null || exit 2
resetprop ro.vendor.soc.manufacturer "$EXPECTED_SOC_MANUFACTURER" 2>/dev/null || exit 2
[ "$(resetprop ro.soc.model 2>/dev/null)" = "$EXPECTED_SOC_MODEL" ] || exit 2
[ "$(resetprop ro.vendor.soc.model 2>/dev/null)" = "$EXPECTED_SOC_MODEL" ] || exit 2
[ "$(resetprop ro.soc.manufacturer 2>/dev/null)" = "$EXPECTED_SOC_MANUFACTURER" ] || exit 2
[ "$(resetprop ro.vendor.soc.manufacturer 2>/dev/null)" = "$EXPECTED_SOC_MANUFACTURER" ] || exit 2

exit 0
