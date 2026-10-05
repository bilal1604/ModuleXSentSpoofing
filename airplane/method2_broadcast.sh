#!/system/bin/sh
# Airplane Mode Method 2 - Global Settings & Broadcast Intent (AOSP / MIUI / OneUI)
ACTION="$1" # "enable" or "disable"

if [ "$ACTION" = "enable" ]; then
    settings put global airplane_mode_on 1 2>/dev/null || true
    am broadcast --user 0 -a android.intent.action.AIRPLANE_MODE --ez state true --receiver-include-background 2>/dev/null || \
        am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true 2>/dev/null || true
else
    settings put global airplane_mode_on 0 2>/dev/null || true
    am broadcast --user 0 -a android.intent.action.AIRPLANE_MODE --ez state false --receiver-include-background 2>/dev/null || \
        am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false 2>/dev/null || true
fi