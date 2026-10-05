#!/system/bin/sh

CONFIG_DIR="/data/adb/xsent-spoof"
LEGACY_CONFIG_DIR="/data/adb/ModuleXSent"
TARGET_TMP="/data/local/tmp/xsent_targets.list"

# Migrate persistent state from the former module identity once. Keep the
# legacy directory untouched so rollback remains possible if installation fails.
if [ ! -d "$CONFIG_DIR" ] && [ -d "$LEGACY_CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
    cp -a "$LEGACY_CONFIG_DIR"/. "$CONFIG_DIR"/ 2>/dev/null || {
        rm -rf "$CONFIG_DIR"
        abort "Unable to migrate legacy XSent state"
    }
fi
mkdir -p "$CONFIG_DIR"

# Auto-convert CRLF to pure Unix LF on installation (Magisk, KernelSU, APatch)
for f in "$MODPATH"/*.sh "$MODPATH"/*/*.sh "$MODPATH"/module.prop "$MODPATH"/defaults.prop "$MODPATH"/runtime.prop "$MODPATH"/target.txt "$CONFIG_DIR"/system.prop "$CONFIG_DIR"/target.txt; do
    [ -f "$f" ] || continue
    tr -d '\r' < "$f" > "$f.tmp" && mv -f "$f.tmp" "$f" 2>/dev/null || sed -i 's/\r$//' "$f" 2>/dev/null || true
done

merge_missing_props() {
    defaults="$1"
    destination="$2"
    [ -f "$defaults" ] || return 0
    [ -f "$destination" ] || {
        cp "$defaults" "$destination"
        return 0
    }

    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ''|\#*) continue ;;
            *=*)
                key="${line%%=*}"
                val="${line#*=}"
                # Do not copy empty keys
                [ -z "$val" ] && continue
                awk -F= -v wanted="$key" '$1 == wanted { found=1 } END { exit !found }' \
                    "$destination" 2>/dev/null || printf '%s\n' "$line" >> "$destination"
                ;;
        esac
    done < "$defaults"
}

[ -f "$MODPATH/defaults.prop" ] && merge_missing_props "$MODPATH/defaults.prop" "$CONFIG_DIR/system.prop"

# Migrate old profile snapshots before the first boot. All aliases are kept in
# the same snapshot so a stale persistent property cannot win after reboot.
upsert_alias() {
    source_key="$1"
    target_key="$2"
    value="$(sed -n "s/^${source_key}=//p" "$CONFIG_DIR/system.prop" 2>/dev/null | tail -n 1)"
    [ -n "$value" ] || return 0
    sed -i "\|^${target_key}=|d" "$CONFIG_DIR/system.prop" 2>/dev/null || true
    printf '%s=%s\n' "$target_key" "$value" >> "$CONFIG_DIR/system.prop"
}
upsert_alias persist.sys.xsent.identity.marketing_name persist.sys.xsent.identity.marketing
upsert_alias persist.sys.xsent.identity.marketing_name persist.sys.xsent.identity.device_name
upsert_alias persist.sys.xsent.identity.os persist.sys.xsent.identity.release

# runtime.prop, defaults.prop and the public runtime mirror must represent one
# complete profile. The APK later replaces all four files atomically.
if grep -q '^persist\.sys\.xsent\.identity\.tech_model=.' "$CONFIG_DIR/system.prop" 2>/dev/null; then
    cp -f "$CONFIG_DIR/system.prop" "$MODPATH/runtime.prop" 2>/dev/null || abort "Unable to mirror runtime identity"
    cp -f "$CONFIG_DIR/system.prop" "$MODPATH/defaults.prop" 2>/dev/null || abort "Unable to mirror default identity"
    cp -f "$CONFIG_DIR/system.prop" /data/local/tmp/XSent_runtime.prop 2>/dev/null || true
fi
# Never leave a root-level system.prop in the Magisk module. Magisk loads that
# file automatically and would overwrite the user's persisted checkbox values.
rm -f "$MODPATH/system.prop" 2>/dev/null || true
[ -f "$MODPATH/keybox.xml" ] && [ ! -f "$CONFIG_DIR/keybox.xml" ] && cp "$MODPATH/keybox.xml" "$CONFIG_DIR/keybox.xml"
[ -f "$MODPATH/target.txt" ] && [ ! -s "$CONFIG_DIR/target.txt" ] && cp "$MODPATH/target.txt" "$CONFIG_DIR/target.txt"
[ -f "$CONFIG_DIR/target.txt" ] && cp "$CONFIG_DIR/target.txt" "$TARGET_TMP" 2>/dev/null

chmod 700 "$CONFIG_DIR" 2>/dev/null
chmod 0644 "$CONFIG_DIR/system.prop" "$CONFIG_DIR/target.txt" 2>/dev/null
chmod 0644 "$TARGET_TMP" 2>/dev/null
chmod 0666 /data/local/tmp/XSent_runtime.prop 2>/dev/null || true
chmod 0600 "$CONFIG_DIR/keybox.xml" 2>/dev/null

chmod -R 0755 "$MODPATH"/*.sh "$MODPATH"/core "$MODPATH"/global "$MODPATH"/framework "$MODPATH"/telephony "$MODPATH"/shield "$MODPATH"/location "$MODPATH"/clearing "$MODPATH"/airplane "$MODPATH"/scripts 2>/dev/null

# Install or update the companion app while Android is running. Root managers
# may also flash modules from recovery, where Package Manager is unavailable;
# service.sh retries the same operation after Android finishes booting.
if [ -s "$MODPATH/xsent.apk" ] && [ -x "$MODPATH/scripts/install_xsent_apk.sh" ]; then
    ui_print "- Installing XSent companion app"
    "$MODPATH/scripts/install_xsent_apk.sh" || \
        ui_print "- XSent APK installation queued for the next boot"
else
    abort "XSent companion APK is missing from this module ZIP"
fi
