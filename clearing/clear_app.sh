#!/system/bin/sh
# XSent Spoof Clearing - App Data & Cache Cleaner
# Usage: sh clear_app.sh <package_name> [safe|medium|hard]

export PATH="/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:/data/adb/mksu/bin:/data/adb/sukisu/bin:/data/adb/ksud:/data/adb/bin:/sbin:/debug_ramdisk:/system/bin:/system/xbin:/vendor/bin:$PATH"

PKG="$1"
MODE="$2"
[ -z "$MODE" ] && MODE="medium"

[ -z "$PKG" ] && exit 1
[ "$PKG" = "io.xsent.spoof" ] && exit 0
# SOTER is a Tencent system service; clearing/stopping it makes it crash on
# some devices (notably KernelSU). Never touch it.
[ "$PKG" = "com.tencent.soter.soterserver" ] && exit 0

# 1. Force Stop Process
am force-stop "$PKG" 2>/dev/null || true
# Match only the Android package process (and its colon-suffixed services).
# A broad -f match also matches this script's own command line because PKG is
# passed as an argument, terminating the cleaner before `pm clear` runs.
pkill -9 -f "^$PKG(:|$)" 2>/dev/null || true

# 2. Safe Clear: Standard pm clear
pm clear "$PKG" 2>/dev/null || true

# 3. Medium & Hard: Deep storage & cache purge
if [ "$MODE" = "medium" ] || [ "$MODE" = "hard" ]; then
    rm -rf "/data/data/$PKG/cache" "/data/data/$PKG/code_cache" "/data/data/$PKG/app_webview" 2>/dev/null || true
    rm -rf "/data/user/0/$PKG/cache" "/data/user/0/$PKG/code_cache" 2>/dev/null || true
    rm -rf "/data/user_de/0/$PKG" 2>/dev/null || true
    rm -rf "/sdcard/Android/data/$PKG/cache" "/sdcard/Android/media/$PKG" 2>/dev/null || true

    # Delete SSAID (Android ID for this specific app)
    settings delete ssaid "$PKG" 2>/dev/null || true
fi

# 4. Hard Clear: Complete data wipe
if [ "$MODE" = "hard" ]; then
    rm -rf "/data/data/$PKG" "/data/user/0/$PKG" "/sdcard/Android/data/$PKG" "/sdcard/Android/obb/$PKG" 2>/dev/null || true
fi

sync
exit 0
