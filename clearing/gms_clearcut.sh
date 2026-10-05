#!/system/bin/sh
# XSent Spoof Clearing - GMS Clearcut & Google Cache Cleaner

export PATH="/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:/data/adb/mksu/bin:/data/adb/sukisu/bin:/data/adb/ksud:/data/adb/bin:/sbin:/debug_ramdisk:/system/bin:/system/xbin:/vendor/bin:$PATH"

# 1. Stop Google Services
am force-stop com.google.android.gms 2>/dev/null || true
am force-stop com.android.vending 2>/dev/null || true
am force-stop com.google.android.gsf 2>/dev/null || true
pkill -9 -f '^com.google.android.gms(:|$)' 2>/dev/null || true
pkill -9 -f '^com.android.vending(:|$)' 2>/dev/null || true
pkill -9 -f '^com.google.android.gsf(:|$)' 2>/dev/null || true

# 2. Wipe GMS Clearcut Logs & Caches (Preserves Login Accounts)
rm -rf /data/data/com.google.android.gms/files/clearcut/* /data/user/0/com.google.android.gms/files/clearcut/* 2>/dev/null || true
rm -rf /data/data/com.google.android.gms/cache/* /data/user/0/com.google.android.gms/cache/* 2>/dev/null || true
rm -rf /data/data/com.google.android.gms/code_cache/* /data/user/0/com.google.android.gms/code_cache/* 2>/dev/null || true
rm -rf /data/data/com.android.vending/cache/* /data/user/0/com.android.vending/cache/* 2>/dev/null || true
rm -rf /data/data/com.android.vending/code_cache/* /data/user/0/com.android.vending/code_cache/* 2>/dev/null || true
rm -rf /data/data/com.google.android.gsf/cache/* /data/user/0/com.google.android.gsf/cache/* 2>/dev/null || true
rm -rf /data/data/com.google.android.gsf/code_cache/* /data/user/0/com.google.android.gsf/code_cache/* 2>/dev/null || true

sync
exit 0
