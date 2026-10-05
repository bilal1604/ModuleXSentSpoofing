#!/system/bin/sh

MODDIR=${0%/*}
CONFIG_DIR="/data/adb/xsent-spoof"
CONFIG_PROP_FILE="$CONFIG_DIR/system.prop"
TARGET_FILE="$CONFIG_DIR/target.txt"

type ui_print >/dev/null 2>&1 || ui_print() {
    echo "$*"
}

read_config_prop() {
    key="$1"
    grep "^${key}=" "$CONFIG_PROP_FILE" 2>/dev/null | tail -n 1 | cut -d= -f2-
}

AUTH_GUARD="$MODDIR/scripts/auth_guard.sh"
if [ ! -r "$AUTH_GUARD" ]; then
    ui_print "Authorization guard is missing. Reinstall the official module."
    exit 1
fi
. "$AUTH_GUARD"
if ! xsent_require_auth "$CONFIG_DIR" "$MODDIR"; then
    ui_print "Authorization expired. Open XSent and verify your token again."
    exit 1
fi

ui_print "*******************************"
ui_print "* XSent Spoof v1.0.0       *"
ui_print "*******************************"
ui_print "Config    : $CONFIG_PROP_FILE"
ui_print "Targets   : $TARGET_FILE"
ui_print "Mode      : Safe global build spoof + XSent Full target-app hooks"
ui_print ""

if [ -f "$TARGET_FILE" ]; then
    ui_print "Target packages:"
    grep -Ev '^[[:space:]]*($|#)' "$TARGET_FILE" 2>/dev/null | while IFS= read -r pkg; do
        ui_print " - $pkg"
    done
else
    ui_print "Target packages: none"
fi

ui_print ""
ui_print "IMEI 1    : $(read_config_prop persist.sys.xsent.identity.imei1)"
ui_print "IMEI 2    : $(read_config_prop persist.sys.xsent.identity.imei2)"
ui_print "IMEI flag : $(read_config_prop persist.sys.xsent.spoof_imei)"
ui_print "PI manager: $(read_config_prop persist.sys.xsent.manage_play_integrity)"
ui_print "GSF ID    : $(read_config_prop persist.sys.xsent.identity.gsf_id)"
ui_print "WiFi MAC  : $(read_config_prop persist.sys.xsent.identity.wifi_mac)"
ui_print "WiFi SSID : $(read_config_prop persist.sys.xsent.identity.wifi_ssid)"
ui_print "WiFi BSSID: $(read_config_prop persist.sys.xsent.identity.wifi_bssid)"
ui_print "BT MAC    : $(read_config_prop persist.sys.xsent.identity.bt_mac)"
ui_print "Nearby BT : $(read_config_prop persist.sys.xsent.identity.nearby_bt_name)"
ui_print "Ad ID     : $(read_config_prop persist.sys.xsent.identity.advertising_id)"
ui_print "AppSet ID : $(read_config_prop persist.sys.xsent.identity.app_set_id)"
ui_print "Widevine  : $(read_config_prop persist.sys.xsent.identity.widevine_id)"
ui_print "UserAgent : $(read_config_prop persist.sys.xsent.identity.user_agent)"
ui_print "Keyboard  : $(read_config_prop persist.sys.xsent.identity.virtual_default_ime)"
ui_print "Timezone  : $(read_config_prop persist.sys.xsent.identity.timezone_id)"
ui_print "SIM       : $(read_config_prop persist.sys.xsent.identity.sim_operator_name) / $(read_config_prop persist.sys.xsent.identity.phone_number)"
ui_print ""
ui_print "Apply a profile from the XSent app, then reboot for a full synchronization."
