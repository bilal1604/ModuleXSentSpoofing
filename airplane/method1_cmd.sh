#!/system/bin/sh
# Airplane Mode Method 1 - Android Connectivity Command (Android 10+)
ACTION="$1" # "enable" or "disable"
[ -z "$ACTION" ] && ACTION="enable"

cmd connectivity airplane-mode "$ACTION" 2>/dev/null