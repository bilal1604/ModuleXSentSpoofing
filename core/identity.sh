#!/system/bin/sh
# XSent Spoof Core - Identity & Treble Partition Engine

apply_identity() {
    BRAND="$(get_id brand)"
    MANUFACTURER="$(get_id manufacturer)"
    [ -z "$MANUFACTURER" ] && MANUFACTURER="$BRAND"
    MODEL="$(get_id tech_model)"
    [ -z "$MODEL" ] && MODEL="$(get_id model)"
    PRODUCT="$(get_id product)"
    DEVICE="$(get_id device)"
    BOARD="$(get_id board)"
    PLATFORM="$(get_id platform)"
    [ -z "$PLATFORM" ] && PLATFORM="$BOARD"
    SOC_MODEL="$(get_id soc_model)"
    [ -z "$SOC_MODEL" ] && SOC_MODEL="$(printf '%s' "$PLATFORM" | tr '[:lower:]' '[:upper:]')"
    SOC_MANUFACTURER="$(get_id soc_manufacturer)"
    FINGERPRINT="$(get_id fingerprint)"
    BUILD_ID="$(get_id build_id)"
    INCREMENTAL="$(get_id incremental)"
    OS_VERSION="$(get_id os)"
    [ -z "$OS_VERSION" ] && OS_VERSION="$(get_id release)"
    SDK_VERSION="$(get_id sdk)"
    SECURITY_PATCH="$(get_id security_patch)"
    MARKETING="$(get_id marketing_name)"
    [ -z "$MARKETING" ] && MARKETING="$(get_id marketing)"
    SERIAL="$(get_id serial)"

    [ -z "$MODEL" ] && [ -z "$FINGERPRINT" ] && return 0

    [ -n "$BRAND" ] && resetprop ro.product.brand "$BRAND" 2>/dev/null
    [ -n "$MANUFACTURER" ] && resetprop ro.product.manufacturer "$MANUFACTURER" 2>/dev/null
    [ -n "$MODEL" ] && resetprop ro.product.model "$MODEL" 2>/dev/null
    [ -n "$PRODUCT" ] && resetprop ro.product.name "$PRODUCT" 2>/dev/null
    [ -n "$DEVICE" ] && resetprop ro.product.device "$DEVICE" 2>/dev/null
    [ -n "$BOARD" ] && resetprop ro.product.board "$BOARD" 2>/dev/null
    # SoC properties are safe identity surfaces. ro.board.platform/ro.hardware
    # remain physical globally because changing them can select the wrong HAL.
    [ -n "$SOC_MODEL" ] && resetprop ro.soc.model "$SOC_MODEL" 2>/dev/null
    [ -n "$SOC_MODEL" ] && resetprop ro.vendor.soc.model "$SOC_MODEL" 2>/dev/null
    [ -n "$SOC_MANUFACTURER" ] && resetprop ro.soc.manufacturer "$SOC_MANUFACTURER" 2>/dev/null
    [ -n "$SOC_MANUFACTURER" ] && resetprop ro.vendor.soc.manufacturer "$SOC_MANUFACTURER" 2>/dev/null
    [ -n "$DEVICE" ] && resetprop ro.build.product "$DEVICE" 2>/dev/null
    if [ -n "$MARKETING" ]; then
        resetprop ro.product.marketname "$MARKETING" 2>/dev/null
        resetprop ro.config.marketing_name "$MARKETING" 2>/dev/null
        settings put global device_name "$MARKETING" 2>/dev/null || true
        settings put secure bluetooth_name "$MARKETING" 2>/dev/null || true
        settings put global bluetooth_name "$MARKETING" 2>/dev/null || true
        settings put global synced_device_name "$MARKETING" 2>/dev/null || true
        settings put global market_name "$MARKETING" 2>/dev/null || true
        settings put system device_name "$MARKETING" 2>/dev/null || true
    fi

    if [ -n "$SERIAL" ]; then
        resetprop ro.serialno "$SERIAL" 2>/dev/null
        resetprop ro.boot.serialno "$SERIAL" 2>/dev/null
    fi

    # Treble Partitions
    for P in system vendor product odm system_ext vendor_dlkm system_dlkm; do
        [ -n "$BRAND" ] && resetprop "ro.product.${P}.brand" "$BRAND" 2>/dev/null
        [ -n "$MANUFACTURER" ] && resetprop "ro.product.${P}.manufacturer" "$MANUFACTURER" 2>/dev/null
        [ -n "$MODEL" ] && resetprop "ro.product.${P}.model" "$MODEL" 2>/dev/null
        [ -n "$PRODUCT" ] && resetprop "ro.product.${P}.name" "$PRODUCT" 2>/dev/null
        [ -n "$DEVICE" ] && resetprop "ro.product.${P}.device" "$DEVICE" 2>/dev/null
        [ -n "$BOARD" ] && resetprop "ro.product.${P}.board" "$BOARD" 2>/dev/null
        [ -n "$FINGERPRINT" ] && resetprop "ro.${P}.build.fingerprint" "$FINGERPRINT" 2>/dev/null
        [ -n "$OS_VERSION" ] && resetprop "ro.${P}.build.version.release" "$OS_VERSION" 2>/dev/null
        [ -n "$BUILD_ID" ] && resetprop "ro.${P}.build.id" "$BUILD_ID" 2>/dev/null
        resetprop "ro.${P}.build.tags" "release-keys" 2>/dev/null
        resetprop "ro.${P}.build.type" "user" 2>/dev/null
    done

    # System & Vendor product namespaces
    [ -n "$BRAND" ] && resetprop ro.system.product.brand "$BRAND" 2>/dev/null
    [ -n "$MANUFACTURER" ] && resetprop ro.system.product.manufacturer "$MANUFACTURER" 2>/dev/null
    [ -n "$MODEL" ] && resetprop ro.system.product.model "$MODEL" 2>/dev/null
    [ -n "$PRODUCT" ] && resetprop ro.system.product.name "$PRODUCT" 2>/dev/null
    [ -n "$DEVICE" ] && resetprop ro.system.product.device "$DEVICE" 2>/dev/null

    [ -n "$BRAND" ] && resetprop ro.vendor.product.brand "$BRAND" 2>/dev/null
    [ -n "$MANUFACTURER" ] && resetprop ro.vendor.product.manufacturer "$MANUFACTURER" 2>/dev/null
    [ -n "$MODEL" ] && resetprop ro.vendor.product.model "$MODEL" 2>/dev/null
    [ -n "$PRODUCT" ] && resetprop ro.vendor.product.name "$PRODUCT" 2>/dev/null
    [ -n "$DEVICE" ] && resetprop ro.vendor.product.device "$DEVICE" 2>/dev/null

    if [ -n "$FINGERPRINT" ]; then
        resetprop ro.build.fingerprint "$FINGERPRINT" 2>/dev/null
        resetprop ro.product.build.fingerprint "$FINGERPRINT" 2>/dev/null
        for P in bootimage; do
            resetprop "ro.${P}.build.fingerprint" "$FINGERPRINT" 2>/dev/null
        done
    fi

    [ -n "$BUILD_ID" ] && resetprop ro.build.id "$BUILD_ID" 2>/dev/null
    [ -n "$BUILD_ID" ] && resetprop ro.build.display.id "$BUILD_ID" 2>/dev/null
    [ -n "$SECURITY_PATCH" ] && resetprop ro.build.version.security_patch "$SECURITY_PATCH" 2>/dev/null
    resetprop ro.build.tags "release-keys" 2>/dev/null
    resetprop ro.build.type "user" 2>/dev/null

    if [ -n "$PRODUCT" ] && [ -n "$OS_VERSION" ] && [ -n "$BUILD_ID" ] && [ -n "$INCREMENTAL" ]; then
        resetprop ro.build.description "$PRODUCT-user $OS_VERSION $BUILD_ID $INCREMENTAL release-keys" 2>/dev/null
    fi

    if [ -n "$OS_VERSION" ]; then
        resetprop ro.build.version.release "$OS_VERSION" 2>/dev/null
        resetprop ro.build.version.release_or_codename "$OS_VERSION" 2>/dev/null
        resetprop ro.build.version.release_or_preview_display "$OS_VERSION" 2>/dev/null
        resetprop ro.system.build.version.release "$OS_VERSION" 2>/dev/null
        resetprop ro.vendor.build.version.release "$OS_VERSION" 2>/dev/null
        resetprop ro.product.build.version.release "$OS_VERSION" 2>/dev/null
        resetprop ro.system_ext.build.version.release "$OS_VERSION" 2>/dev/null
        resetprop ro.odm.build.version.release "$OS_VERSION" 2>/dev/null
    fi
    # SDK_INT must never be changed globally: ART and system_server are compiled
    # against the physical ROM SDK and can enter a restart loop when it changes.
    # XSent applies the profile SDK inside each scoped app process. The host
    # runtime SDK stays physical because ART and system_server depend on it.
    [ -n "$INCREMENTAL" ] && resetprop ro.build.version.incremental "$INCREMENTAL" 2>/dev/null
    resetprop ro.build.version.codename "REL" 2>/dev/null
    resetprop ro.build.version.all_codenames "REL" 2>/dev/null
    resetprop ro.build.version.preview_sdk "0" 2>/dev/null
    resetprop ro.build.version.preview_sdk_fingerprint "0" 2>/dev/null
}
