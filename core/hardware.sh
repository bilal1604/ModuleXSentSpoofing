#!/system/bin/sh
# XSent Spoof Core - Hardware (Bootloader & Radio / Baseband) Engine

apply_hardware() {
    MODEL="$(get_id tech_model)"
    [ -z "$MODEL" ] && MODEL="$(get_id model)"
    DEVICE="$(get_id device)"
    INCREMENTAL="$(get_id incremental)"
    BOOTLOADER="$(get_id bootloader)"
    BASEBAND="$(get_id baseband)"

    [ -z "$BOOTLOADER" ] && [ -n "$MODEL" ] && BOOTLOADER="${MODEL}_${INCREMENTAL:-BOOTLOADER}"
    [ -z "$BASEBAND" ] && [ -n "$DEVICE" ] && BASEBAND="${DEVICE}_GEN_PACK-1.${INCREMENTAL:-240106}"

    if [ -n "$BOOTLOADER" ]; then
        resetprop ro.bootloader "$BOOTLOADER" 2>/dev/null
        resetprop ro.boot.bootloader "$BOOTLOADER" 2>/dev/null
        resetprop ro.build.bootloader "$BOOTLOADER" 2>/dev/null
        resetprop sys.bootloader "$BOOTLOADER" 2>/dev/null
        resetprop gsm.version.bootloader "$BOOTLOADER" 2>/dev/null
    fi

    if [ -n "$BASEBAND" ]; then
        resetprop gsm.version.baseband "$BASEBAND" 2>/dev/null
        resetprop gsm.version.baseband1 "$BASEBAND" 2>/dev/null
        resetprop gsm.version.baseband2 "$BASEBAND" 2>/dev/null
        resetprop ro.boot.radio "$BASEBAND" 2>/dev/null
        resetprop ro.boot.baseband "$BASEBAND" 2>/dev/null
        resetprop ro.baseband "$BASEBAND" 2>/dev/null
        resetprop gsm.baseband.version "$BASEBAND" 2>/dev/null
        resetprop persist.radio.version "$BASEBAND" 2>/dev/null
        resetprop ril.baseband.version "$BASEBAND" 2>/dev/null
    fi
}