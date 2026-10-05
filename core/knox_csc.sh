#!/system/bin/sh
# XSent Spoof Core - Samsung Knox Warranty & CSC Engine

apply_knox_csc() {
    BRAND="$(get_id brand)"
    MODEL="$(get_id tech_model)"
    [ -z "$MODEL" ] && MODEL="$(get_id model)"
    CSC="$(get_id csc)"
    [ -z "$CSC" ] && [ "$BRAND" = "Samsung" ] && CSC="XID"
    KNOX="$(get_id knox)"
    [ -z "$KNOX" ] && [ "$BRAND" = "Samsung" ] && KNOX="3.10"
    PCODE="$(get_id product_code)"
    [ -z "$PCODE" ] && [ "$BRAND" = "Samsung" ] && [ -n "$MODEL" ] && PCODE="${MODEL}ZAXID"

    # Samsung Knox Warranty 0x0 (Valid)
    resetprop ro.boot.warranty_bit "0" 2>/dev/null
    resetprop ro.warranty_bit "0" 2>/dev/null
    resetprop ro.vendor.boot.warranty_bit "0" 2>/dev/null
    resetprop ro.vendor.warranty_bit "0" 2>/dev/null
    resetprop ro.boot.knox.active "0" 2>/dev/null
    resetprop ro.config.knox "v30" 2>/dev/null
    resetprop ro.knox.version "$KNOX" 2>/dev/null

    # Samsung CSC
    if [ -n "$CSC" ]; then
        resetprop ro.csc.sales_code "$CSC" 2>/dev/null
        resetprop ro.csc.country_code "$CSC" 2>/dev/null
        resetprop ro.csc.countryiso_code "ID" 2>/dev/null
        resetprop ril.sales_code "$CSC" 2>/dev/null
        resetprop persist.sys.csc.code "$CSC" 2>/dev/null
        resetprop ro.omc.sales_code "$CSC" 2>/dev/null
    fi

    if [ -n "$PCODE" ]; then
        resetprop ro.boot.product_code "$PCODE" 2>/dev/null
        resetprop ro.product_code "$PCODE" 2>/dev/null
        resetprop ril.product_code "$PCODE" 2>/dev/null
        resetprop ro.ril.product_code "$PCODE" 2>/dev/null
    fi
}