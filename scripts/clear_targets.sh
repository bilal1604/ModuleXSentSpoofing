#!/system/bin/sh
# XSent Spoof Runtime Endpoint - Clear Target Apps Data & Cache
# Called by XSent APK on Deep Clean

export PATH="/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:/data/adb/mksu/bin:/data/adb/sukisu/bin:/data/adb/ksud:/data/adb/bin:/sbin:/debug_ramdisk:/system/bin:/system/xbin:/vendor/bin:$PATH"

CONFIG_DIR="/data/adb/xsent-spoof"
TARGET_FILE="$CONFIG_DIR/target.txt"

if [ -f "$TARGET_FILE" ]; then
    while IFS= read -r pkg || [ -n "$pkg" ]; do
        case "$pkg" in
            ''|\#*) continue ;;
        esac
        pkg="$(printf '%s' "$pkg" | tr -d '[:space:]')"
        [ -z "$pkg" ] && continue
        [ "$pkg" = "io.xsent.spoof" ] && continue
        # SOTER is a Tencent system service; clearing/stopping it makes it crash
        # on some devices (notably KernelSU). Never touch it.
        [ "$pkg" = "com.tencent.soter.soterserver" ] && continue

        am force-stop "$pkg" 2>/dev/null || true
        pkill -9 -f "^$pkg(:|$)" 2>/dev/null || true

        # Clear App Data & Cache
        pm clear "$pkg" 2>/dev/null || true
        rm -rf "/data/data/$pkg" "/data/user/0/$pkg" "/data/user_de/0/$pkg" "/sdcard/Android/data/$pkg" "/sdcard/Android/media/$pkg" "/sdcard/Android/obb/$pkg" 2>/dev/null || true
    done < "$TARGET_FILE"
fi

sync
exit 0
