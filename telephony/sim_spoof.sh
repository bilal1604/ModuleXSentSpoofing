#!/system/bin/sh
# XSent Spoof Telephony - SIM & Carrier Spoofing Engine

apply_sim_spoof() {
    # Capture physical carrier before overriding
    for slot in 0 1; do
        physical="$(getprop "gsm.sim.operator.numeric.$slot" 2>/dev/null)"
        case "$physical" in
            510[0-9][0-9])
                key="persist.sys.xsent.identity.physical_sim_operator$slot"
                [ -z "$(resetprop "$key" 2>/dev/null)" ] && resetprop "$key" "$physical" 2>/dev/null || true
                ;;
        esac
    done

    IMEI1="$(get_id imei1)"
    IMEI2="$(get_id imei2)"
    if [ -n "$IMEI1" ]; then
        resetprop persist.radio.imei1 "$IMEI1" 2>/dev/null
        resetprop persist.radio.imei "$IMEI1" 2>/dev/null
        resetprop gsm.sim.imei "$IMEI1" 2>/dev/null
        resetprop gsm.sim.imei1 "$IMEI1" 2>/dev/null
        resetprop gsm.baseband.imei "$IMEI1" 2>/dev/null
        resetprop gsm.baseband.imei1 "$IMEI1" 2>/dev/null
        resetprop persist.vendor.radio.imei "$IMEI1" 2>/dev/null
        resetprop persist.vendor.radio.imei1 "$IMEI1" 2>/dev/null
        resetprop ril.imei "$IMEI1" 2>/dev/null
        resetprop ril.imei1 "$IMEI1" 2>/dev/null
        resetprop ro.ril.oem.imei "$IMEI1" 2>/dev/null
        resetprop ro.ril.oem.imei1 "$IMEI1" 2>/dev/null
        if [ -n "$IMEI2" ]; then
            resetprop persist.radio.imei2 "$IMEI2" 2>/dev/null
            resetprop gsm.sim.imei2 "$IMEI2" 2>/dev/null
            resetprop gsm.baseband.imei2 "$IMEI2" 2>/dev/null
            resetprop persist.vendor.radio.imei2 "$IMEI2" 2>/dev/null
            resetprop ril.imei2 "$IMEI2" 2>/dev/null
            resetprop ro.ril.oem.imei2 "$IMEI2" 2>/dev/null
        fi
    fi

    # MEID & IMEISV
    MEID1="$(get_id meid1)"
    [ -z "$MEID1" ] && MEID1="$(get_id meid)"
    MEID2="$(get_id meid2)"
    IMEISV1="$(get_id imeisv1)"
    IMEISV2="$(get_id imeisv2)"

    if [ -n "$MEID1" ]; then
        resetprop persist.sys.xsent.identity.meid "$MEID1" 2>/dev/null
        resetprop persist.sys.xsent.identity.meid1 "$MEID1" 2>/dev/null
        resetprop ril.meid "$MEID1" 2>/dev/null
        resetprop ril.meid1 "$MEID1" 2>/dev/null
        resetprop gsm.sim.meid "$MEID1" 2>/dev/null
        resetprop gsm.sim.meid1 "$MEID1" 2>/dev/null
    fi
    if [ -n "$MEID2" ]; then
        resetprop persist.sys.xsent.identity.meid2 "$MEID2" 2>/dev/null
        resetprop ril.meid2 "$MEID2" 2>/dev/null
        resetprop gsm.sim.meid2 "$MEID2" 2>/dev/null
    fi

    if [ -n "$IMEISV1" ]; then
        resetprop persist.sys.xsent.identity.imeisv1 "$IMEISV1" 2>/dev/null
        resetprop gsm.sim.imeisv "$IMEISV1" 2>/dev/null
        resetprop gsm.sim.imeisv1 "$IMEISV1" 2>/dev/null
        resetprop gsm.baseband.imeisv "$IMEISV1" 2>/dev/null
        resetprop gsm.baseband.imeisv1 "$IMEISV1" 2>/dev/null
        resetprop ril.imeisv "$IMEISV1" 2>/dev/null
        resetprop ril.imeisv1 "$IMEISV1" 2>/dev/null
    fi
    if [ -n "$IMEISV2" ]; then
        resetprop persist.sys.xsent.identity.imeisv2 "$IMEISV2" 2>/dev/null
        resetprop gsm.sim.imeisv2 "$IMEISV2" 2>/dev/null
        resetprop gsm.baseband.imeisv2 "$IMEISV2" 2>/dev/null
        resetprop ril.imeisv2 "$IMEISV2" 2>/dev/null
    fi

    # SIM / Telephony
    IMSI="$(get_id imsi)"
    IMSI2="$(get_id imsi2)"
    SIM_SERIAL="$(get_id sim_serial)"
    SIM_SERIAL2="$(get_id sim_serial2)"
    PHONE_NUMBER="$(get_id phone_number)"
    PHONE_NUMBER2="$(get_id phone_number2)"
    SIM_OPERATOR="$(get_id sim_operator)"
    SIM_OPERATOR_NAME="$(get_id sim_operator_name)"
    SIM_OPERATOR2="$(get_id sim_operator2)"
    SIM_OPERATOR_NAME2="$(get_id sim_operator_name2)"
    SIM_COUNTRY="$(get_id sim_country)"
    [ -z "$SIM_COUNTRY" ] && SIM_COUNTRY="id"

    # Slot 1
    [ -n "$IMSI" ] && resetprop persist.sys.xsent.identity.imsi "$IMSI" 2>/dev/null
    [ -n "$SIM_SERIAL" ] && resetprop persist.sys.xsent.identity.sim_serial "$SIM_SERIAL" 2>/dev/null
    [ -n "$PHONE_NUMBER" ] && resetprop persist.sys.xsent.identity.phone_number "$PHONE_NUMBER" 2>/dev/null
    if [ -n "$SIM_OPERATOR" ]; then
        resetprop persist.sys.xsent.identity.sim_operator "$SIM_OPERATOR" 2>/dev/null
        resetprop gsm.sim.operator.numeric "$SIM_OPERATOR,$SIM_OPERATOR2" 2>/dev/null
        resetprop gsm.sim.operator.numeric.0 "$SIM_OPERATOR" 2>/dev/null
        resetprop gsm.operator.numeric "$SIM_OPERATOR" 2>/dev/null
    fi
    if [ -n "$SIM_OPERATOR_NAME" ]; then
        resetprop persist.sys.xsent.identity.sim_operator_name "$SIM_OPERATOR_NAME" 2>/dev/null
        resetprop gsm.sim.operator.alpha "$SIM_OPERATOR_NAME,$SIM_OPERATOR_NAME2" 2>/dev/null
        resetprop gsm.sim.operator.alpha.0 "$SIM_OPERATOR_NAME" 2>/dev/null
        resetprop gsm.operator.alpha "$SIM_OPERATOR_NAME" 2>/dev/null
    fi
    resetprop persist.sys.xsent.identity.sim_country "$SIM_COUNTRY" 2>/dev/null
    resetprop gsm.sim.operator.iso-country "$SIM_COUNTRY,$SIM_COUNTRY" 2>/dev/null
    resetprop gsm.sim.operator.iso-country.0 "$SIM_COUNTRY" 2>/dev/null
    resetprop gsm.operator.iso-country "$SIM_COUNTRY" 2>/dev/null

    # Slot 2
    if [ -n "$SIM_OPERATOR2" ]; then
        resetprop persist.sys.xsent.identity.sim_operator2 "$SIM_OPERATOR2" 2>/dev/null
        resetprop gsm.sim.operator.numeric.1 "$SIM_OPERATOR2" 2>/dev/null
    fi
    if [ -n "$SIM_OPERATOR_NAME2" ]; then
        resetprop persist.sys.xsent.identity.sim_operator_name2 "$SIM_OPERATOR_NAME2" 2>/dev/null
        resetprop gsm.sim.operator.alpha.1 "$SIM_OPERATOR_NAME2" 2>/dev/null
    fi
    [ -n "$IMSI2" ] && resetprop persist.sys.xsent.identity.imsi2 "$IMSI2" 2>/dev/null
    [ -n "$SIM_SERIAL2" ] && resetprop persist.sys.xsent.identity.sim_serial2 "$SIM_SERIAL2" 2>/dev/null
    [ -n "$PHONE_NUMBER2" ] && resetprop persist.sys.xsent.identity.phone_number2 "$PHONE_NUMBER2" 2>/dev/null
    resetprop gsm.sim.operator.iso-country.1 "$SIM_COUNTRY" 2>/dev/null
    resetprop gsm.sim.state "READY,READY" 2>/dev/null
    resetprop gsm.sim.state.0 "READY" 2>/dev/null
    resetprop gsm.sim.state.1 "READY" 2>/dev/null
}
