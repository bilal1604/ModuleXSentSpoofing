#!/system/bin/sh
# Airplane Mode Method 4 - Telephony Radio Power Low-Level Service Call
ACTION="$1" # "enable" or "disable"

if [ "$ACTION" = "enable" ]; then
    # Disable radio power across phone interfaces
    service call phone 7 i32 0 2>/dev/null || true
    service call isub 7 i32 0 2>/dev/null || true
else
    # Enable radio power across phone interfaces
    service call phone 7 i32 1 2>/dev/null || true
    service call isub 7 i32 1 2>/dev/null || true
fi