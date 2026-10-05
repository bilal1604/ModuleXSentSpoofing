#!/system/bin/sh

# Remove the XSent companion app together with XSent Spoof. Module
# managers may invoke this script before Android's Package Manager is ready, so
# a temporary one-shot worker completes the uninstall after boot when needed.
PACKAGE_NAME="io.xsent.spoof"
TASK_FILE="/data/local/tmp/xsent-uninstall-on-boot.sh"
LOG_FILE="/data/local/tmp/xsent_apk_uninstall.log"

uninstall_xsent() {
    pm path "$PACKAGE_NAME" >/dev/null 2>&1 || return 0
    pm uninstall --user 0 "$PACKAGE_NAME" >/dev/null 2>&1 || \
        pm uninstall "$PACKAGE_NAME" >/dev/null 2>&1
}

if command -v pm >/dev/null 2>&1 && pm path android >/dev/null 2>&1; then
    uninstall_xsent
    exit $?
fi

cat > "$TASK_FILE" <<'XSENT_UNINSTALL_EOF'
#!/system/bin/sh
PACKAGE_NAME="io.xsent.spoof"
LOG_FILE="/data/local/tmp/xsent_apk_uninstall.log"

i=0
while [ "$i" -lt 300 ]; do
    if [ "$(getprop sys.boot_completed 2>/dev/null)" = "1" ] && \
        command -v pm >/dev/null 2>&1 && pm path android >/dev/null 2>&1; then
        if pm path "$PACKAGE_NAME" >/dev/null 2>&1; then
            pm uninstall --user 0 "$PACKAGE_NAME" >> "$LOG_FILE" 2>&1 || \
                pm uninstall "$PACKAGE_NAME" >> "$LOG_FILE" 2>&1
        fi
        rm -f "$0" 2>/dev/null || true
        exit 0
    fi
    sleep 1
    i=$((i + 1))
done
printf '%s\n' "XSent uninstall timed out while waiting for Package Manager" >> "$LOG_FILE" 2>/dev/null || true
rm -f "$0" 2>/dev/null || true
exit 1
XSENT_UNINSTALL_EOF

chmod 0700 "$TASK_FILE" 2>/dev/null || exit 1
if command -v nohup >/dev/null 2>&1; then
    nohup /system/bin/sh "$TASK_FILE" >> "$LOG_FILE" 2>&1 </dev/null &
else
    /system/bin/sh "$TASK_FILE" >> "$LOG_FILE" 2>&1 </dev/null &
fi
exit 0
