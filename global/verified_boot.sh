#!/system/bin/sh
# XSent Spoof Global - Verified Boot & State Cloaking Engine

apply_verified_boot() {
    # Bootloader & VBMeta State
    resetprop ro.boot.vbmeta.device_state "locked" 2>/dev/null
    resetprop vendor.boot.vbmeta.device_state "locked" 2>/dev/null
    resetprop ro.boot.verifiedbootstate "green" 2>/dev/null
    resetprop vendor.boot.verifiedbootstate "green" 2>/dev/null
    resetprop ro.boot.flash.locked "1" 2>/dev/null
    resetprop ro.boot.veritymode "enforcing" 2>/dev/null
    resetprop sys.oem_unlock_allowed "0" 2>/dev/null

    # Xiaomi / Redmi / Poco / MIUI / HyperOS
    resetprop ro.secureboot.lockstate "locked" 2>/dev/null
    resetprop ro.boot.secureboot "1" 2>/dev/null

    # Realme / Oppo / OnePlus
    resetprop ro.boot.realmebootstate "green" 2>/dev/null
    resetprop ro.boot.realme.lockstate "1" 2>/dev/null
    resetprop ro.boot.oppobootstate "green" 2>/dev/null
    resetprop ro.boot.oppo.lockstate "1" 2>/dev/null
    resetprop ro.is_ever_orange "0" 2>/dev/null
    resetprop ro.boot.orange_state "0" 2>/dev/null

    # Vivo / iQOO
    resetprop ro.boot.vivobootstate "green" 2>/dev/null
    resetprop ro.boot.vivo.lockstate "1" 2>/dev/null
}