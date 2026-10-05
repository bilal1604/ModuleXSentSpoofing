#!/system/bin/sh
# Airplane Mode Method 3 - Hardware Radio Service Control (Qualcomm / MediaTek)
ACTION="$1" # "enable" or "disable"

if [ "$ACTION" = "enable" ]; then
    svc data disable 2>/dev/null || true
    svc wifi disable 2>/dev/null || true
    svc bluetooth disable 2>/dev/null || true
else
    svc data enable 2>/dev/null || true
    svc wifi enable 2>/dev/null || true
    svc bluetooth enable 2>/dev/null || true
fi