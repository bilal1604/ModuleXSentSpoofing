#!/system/bin/sh

# Boot-time authorization guard. The manager writes this lease only after the
# token has been accepted by the XSent server. Raw bearer tokens never enter
# system properties or module scripts.

xsent_auth_value() {
    key="$1"
    file="$2"
    sed -n "s/^${key}=//p" "$file" 2>/dev/null | tail -n 1
}

xsent_invalidate_auth() {
    config_dir="$1"
    module_dir="$2"
    resetprop persist.sys.xsent.auth_valid 0 2>/dev/null || true
    for key in android_id token token_hash verified_at_ms expires_at_ms payload signature alg public_key; do
        resetprop --delete "persist.sys.xsent.auth.$key" 2>/dev/null || true
    done
    for prop_file in \
        "$config_dir/system.prop" \
        "$module_dir/runtime.prop" \
        "$module_dir/defaults.prop" \
        /data/local/tmp/XSent_runtime.prop; do
        [ -f "$prop_file" ] || continue
        sed -i '/^persist\.sys\.xsent\.auth/d' "$prop_file" 2>/dev/null || true
        printf '%s\n' 'persist.sys.xsent.auth_valid=0' >> "$prop_file"
    done
}

xsent_publish_auth() {
    config_dir="$1"
    module_dir="$2"
    android_id="$3"
    token_hash="$4"
    verified_at_ms="$5"
    expires_at_ms="$6"
    payload="$7"
    signature="$8"
    alg="$9"
    public_key="${10}"

    resetprop persist.sys.xsent.auth_valid 1 2>/dev/null || true
    resetprop persist.sys.xsent.auth.android_id "$android_id" 2>/dev/null || true
    resetprop persist.sys.xsent.auth.token_hash "$token_hash" 2>/dev/null || true
    resetprop persist.sys.xsent.auth.verified_at_ms "$verified_at_ms" 2>/dev/null || true
    resetprop persist.sys.xsent.auth.expires_at_ms "$expires_at_ms" 2>/dev/null || true

    for prop_file in \
        "$config_dir/system.prop" \
        "$module_dir/runtime.prop" \
        "$module_dir/defaults.prop" \
        /data/local/tmp/XSent_runtime.prop; do
        [ -f "$prop_file" ] || continue
        sed -i '/^persist\.sys\.xsent\.auth/d' "$prop_file" 2>/dev/null || true
        {
            printf '%s\n' 'persist.sys.xsent.auth_valid=1'
            printf 'persist.sys.xsent.auth.android_id=%s\n' "$android_id"
            printf 'persist.sys.xsent.auth.token_hash=%s\n' "$token_hash"
            printf 'persist.sys.xsent.auth.verified_at_ms=%s\n' "$verified_at_ms"
            printf 'persist.sys.xsent.auth.expires_at_ms=%s\n' "$expires_at_ms"
            printf 'persist.sys.xsent.auth.payload=%s\n' "$payload"
            printf 'persist.sys.xsent.auth.signature=%s\n' "$signature"
            printf 'persist.sys.xsent.auth.alg=%s\n' "$alg"
            printf 'persist.sys.xsent.auth.public_key=%s\n' "$public_key"
        } >> "$prop_file"
    done
}

xsent_require_auth() {
    config_dir="$1"
    module_dir="$2"
    lease="$config_dir/auth.lease"

    [ -r "$lease" ] || {
        xsent_invalidate_auth "$config_dir" "$module_dir"
        return 1
    }

    valid="$(xsent_auth_value valid "$lease")"
    android_id="$(xsent_auth_value android_id "$lease")"
    token_hash="$(xsent_auth_value token_hash "$lease")"
    verified_at_ms="$(xsent_auth_value verified_at_ms "$lease")"
    expires_at_ms="$(xsent_auth_value expires_at_ms "$lease")"
    payload="$(xsent_auth_value payload "$lease")"
    signature="$(xsent_auth_value signature "$lease")"
    alg="$(xsent_auth_value alg "$lease")"
    public_key="$(xsent_auth_value public_key "$lease")"

    case "$valid" in 1|true|on) ;; *) xsent_invalidate_auth "$config_dir" "$module_dir"; return 1 ;; esac
    [ "${#android_id}" -ge 6 ] || { xsent_invalidate_auth "$config_dir" "$module_dir"; return 1; }
    [ "${#token_hash}" -eq 64 ] || { xsent_invalidate_auth "$config_dir" "$module_dir"; return 1; }
    case "$token_hash" in *[!0-9a-fA-F]*) xsent_invalidate_auth "$config_dir" "$module_dir"; return 1 ;; esac
    [ "${#payload}" -ge 120 ] || { xsent_invalidate_auth "$config_dir" "$module_dir"; return 1; }
    [ "${#signature}" -ge 80 ] || { xsent_invalidate_auth "$config_dir" "$module_dir"; return 1; }
    [ "$alg" = "Ed25519" ] || { xsent_invalidate_auth "$config_dir" "$module_dir"; return 1; }
    [ "${#public_key}" -ge 40 ] || { xsent_invalidate_auth "$config_dir" "$module_dir"; return 1; }
    case "$payload:$signature:$public_key" in *[!A-Za-z0-9_:-]*) xsent_invalidate_auth "$config_dir" "$module_dir"; return 1 ;; esac
    case "$verified_at_ms:$expires_at_ms" in *[!0-9:]*|:*|*:) xsent_invalidate_auth "$config_dir" "$module_dir"; return 1 ;; esac

    # Android's boot shell can use signed 32-bit arithmetic. Multiplying epoch
    # seconds by 1000 overflows there and invalidates every otherwise-valid
    # lease. Strip the millisecond suffix and keep all calculations in seconds.
    verified_at_s="$(printf '%s' "$verified_at_ms" | sed 's/[0-9][0-9][0-9]$//')"
    expires_at_s="$(printf '%s' "$expires_at_ms" | sed 's/[0-9][0-9][0-9]$//')"
    now_s="$(date +%s 2>/dev/null)"
    case "$verified_at_s:$expires_at_s:$now_s" in *[!0-9:]*|:*|*:) xsent_invalidate_auth "$config_dir" "$module_dir"; return 1 ;; esac
    max_future_verify_s=$(( now_s + 300 ))
    [ "$verified_at_s" -gt 0 ] 2>/dev/null || { xsent_invalidate_auth "$config_dir" "$module_dir"; return 1; }
    [ "$verified_at_s" -le "$max_future_verify_s" ] 2>/dev/null || { xsent_invalidate_auth "$config_dir" "$module_dir"; return 1; }
    [ "$expires_at_s" -gt "$now_s" ] 2>/dev/null || { xsent_invalidate_auth "$config_dir" "$module_dir"; return 1; }
    # Shell performs only boot availability/time checks. The APK and injected
    # Kotlin hook verifies the Ed25519 signature before enabling protected behavior.
    xsent_publish_auth "$config_dir" "$module_dir" "$android_id" "$token_hash" "$verified_at_ms" "$expires_at_ms" "$payload" "$signature" "$alg" "$public_key"
    return 0
}
