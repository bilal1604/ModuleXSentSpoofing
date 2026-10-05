#!/system/bin/sh
# XSent Spoof Runtime Endpoint - Safe Fast Refresh (Anti-Blank Screen)
# Called by XSent APK on Fast Reboot

export PATH="/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:/data/adb/mksu/bin:/data/adb/sukisu/bin:/data/adb/ksud:/data/adb/bin:/sbin:/debug_ramdisk:/system/bin:/system/xbin:/vendor/bin:$PATH"

MODDIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="/data/adb/xsent-spoof"
TARGET_FILE="$CONFIG_DIR/target.txt"

# 1. Publish the private identity to XSent and mirror the four SoC compatibility
# properties used by early readers such as DevCheck. System Sync owns every
# other global/native identity property.
[ -f "$MODDIR/scripts/apply_xsent_runtime.sh" ] || exit 1
sh "$MODDIR/scripts/apply_xsent_runtime.sh" || exit 1

# 2. Stop every live XSent/XSent scope target exactly once. Scope comes from
# the framework registry and profile target files; package names are never built in.
XSENT_SCOPES=""
for registry in /data/local/tmp/xsent_modules.list /data/adb/xsent/modules.list /data/adb/xsent/modules.registry; do
    [ -r "$registry" ] || continue
    XSENT_SCOPES="$(awk -F'|' '$1 == "io.xsent.spoof" { print $4; exit }' "$registry" 2>/dev/null | tr ',' '\n')"
    break
done
FILE_PACKAGES="$(cat "$CONFIG_DIR/target.txt" "$CONFIG_DIR/user_targets.txt" 2>/dev/null)"
SEEN=" "
CURRENT_USER="$(am get-current-user 2>/dev/null)"
[ -n "$CURRENT_USER" ] || CURRENT_USER=0
for scoped_process in $XSENT_SCOPES $FILE_PACKAGES; do
    pkg="${scoped_process%%:*}"
    case "$pkg" in
        io.xsent.spoof|all|''|*[!A-Za-z0-9_.]*) continue ;;
    esac
    case "$pkg" in
        *.*) ;;
        *) continue ;;
    esac
    # SOTER is a Tencent system service; force-stopping it makes it crash on
    # some devices (notably KernelSU). Never refresh it.
    case "$pkg" in
        com.tencent.soter.soterserver) continue ;;
    esac
    case "$SEEN" in
        *" $pkg "*) continue ;;
    esac
    SEEN="$SEEN$pkg "
    am force-stop --user "$CURRENT_USER" "$pkg" 2>/dev/null || true
    pkill -9 -f "^$pkg(:|$)" 2>/dev/null || true
done

# 3. Clean GMS clearcut cache once.
[ -f "$MODDIR/clearing/gms_clearcut.sh" ] && sh "$MODDIR/clearing/gms_clearcut.sh"

sync
exit 0
