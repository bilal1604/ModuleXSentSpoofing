#!/system/bin/sh
# XSent Spoof Telephony - Network & Device IDs Engine

apply_network_ids() {
    GSF_ID="$(get_id gsf_id)"
    WIFI_MAC="$(get_id wifi_mac)"
    BT_MAC="$(get_id bt_mac)"
    ADVERTISING_ID="$(get_id advertising_id)"
    APP_SET_ID="$(get_id app_set_id)"
    WIDEVINE_ID="$(get_id widevine_id)"
    USER_AGENT="$(get_id user_agent)"
    ANDROID_ID="$(get_id android_id)"

    [ -n "$GSF_ID" ] && resetprop persist.sys.xsent.identity.gsf_id "$GSF_ID" 2>/dev/null
    [ -n "$WIFI_MAC" ] && resetprop persist.sys.xsent.identity.wifi_mac "$WIFI_MAC" 2>/dev/null
    [ -n "$BT_MAC" ] && resetprop persist.sys.xsent.identity.bt_mac "$BT_MAC" 2>/dev/null
    [ -n "$ADVERTISING_ID" ] && resetprop persist.sys.xsent.identity.advertising_id "$ADVERTISING_ID" 2>/dev/null
    [ -n "$APP_SET_ID" ] && resetprop persist.sys.xsent.identity.app_set_id "$APP_SET_ID" 2>/dev/null
    [ -n "$WIDEVINE_ID" ] && resetprop persist.sys.xsent.identity.widevine_id "$WIDEVINE_ID" 2>/dev/null
    [ -n "$USER_AGENT" ] && resetprop persist.sys.xsent.identity.user_agent "$USER_AGENT" 2>/dev/null

    if [ -n "$ANDROID_ID" ]; then
        settings put secure android_id "$ANDROID_ID" 2>/dev/null || true
    fi

    # Device Name
    MODEL="$(get_id tech_model)"
    [ -z "$MODEL" ] && MODEL="$(get_id model)"
    MARKETING="$(get_id marketing_name)"
    [ -z "$MARKETING" ] && MARKETING="$(get_id marketing)"
    DEVICE_NAME="${MARKETING:-$MODEL}"
    if [ -n "$DEVICE_NAME" ]; then
        settings put global device_name "$DEVICE_NAME" 2>/dev/null || true
        settings put secure bluetooth_name "$DEVICE_NAME" 2>/dev/null || true
        settings put global bluetooth_name "$DEVICE_NAME" 2>/dev/null || true
        resetprop persist.sys.xsent.identity.device_name "$DEVICE_NAME" 2>/dev/null || true
    fi
}