#!/system/bin/sh
# XSent Spoof Core - Native Identifiers (Android ID, GAID, GSF ID, MAC) Engine

apply_identifiers() {
    ANDROID_ID="$(get_id android_id)"
    GAID="$(get_id advertising_id)"
    [ -z "$GAID" ] && GAID="$(get_id gaid)"
    GSF_ID="$(get_id gsf_id)"
    WIFI_MAC="$(get_id wifi_mac)"
    BT_MAC="$(get_id bt_mac)"

    # 1. Android ID (SSAID / System Settings)
    if [ -n "$ANDROID_ID" ]; then
        settings put secure android_id "$ANDROID_ID" 2>/dev/null || true
        settings put global android_id "$ANDROID_ID" 2>/dev/null || true
        settings put system android_id "$ANDROID_ID" 2>/dev/null || true
    fi

    # 2. Google Advertising ID (GAID / AAID)
    if [ -n "$GAID" ]; then
        resetprop persist.sys.xsent.identity.advertising_id "$GAID" 2>/dev/null
        resetprop persist.sys.xsent.identity.gaid "$GAID" 2>/dev/null

        # Native GMS adid_settings.xml injection
        for gms_dir in /data/data/com.google.android.gms /data/user/0/com.google.android.gms /data/user_de/0/com.google.android.gms; do
            if [ -d "$gms_dir/shared_prefs" ]; then
                cat <<EOF > "$gms_dir/shared_prefs/adid_settings.xml"
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name="adid_key">$GAID</string>
    <boolean name="enable_limit_ad_tracking" value="false" />
</map>
EOF
                chmod 660 "$gms_dir/shared_prefs/adid_settings.xml" 2>/dev/null || true
                chown $(stat -c '%u:%g' "$gms_dir" 2>/dev/null || echo "1000:1000") "$gms_dir/shared_prefs/adid_settings.xml" 2>/dev/null || true
            fi
        done
    fi

    # 3. Google Services Framework ID (GSF ID)
    # Only the XSent-specific prop is set here. The GMS-facing props
    # (persist.com.google.services.id, android.gsf.gservicesid) and the
    # gservices.db injection are intentionally NOT applied globally: doing so
    # makes the real GMS process see a different device identity on every
    # profile switch, which causes GMS to drop the Google account from the
    # system AccountManager. Target apps receive the spoofed GSF ID via the
    # Xposed hook layer (XSentModule.hookGsfId), which intercepts
    # SystemProperties.get for the GMS-facing keys in target processes only.
    if [ -n "$GSF_ID" ]; then
        resetprop persist.sys.xsent.identity.gsf_id "$GSF_ID" 2>/dev/null
    fi

    # 4. WiFi & Bluetooth MAC
    if [ -n "$WIFI_MAC" ]; then
        resetprop persist.sys.xsent.identity.wifi_mac "$WIFI_MAC" 2>/dev/null
    fi
    if [ -n "$BT_MAC" ]; then
        resetprop persist.sys.xsent.identity.bt_mac "$BT_MAC" 2>/dev/null
    fi
}
