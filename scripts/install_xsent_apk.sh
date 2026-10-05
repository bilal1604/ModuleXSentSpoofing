#!/system/bin/sh

# Installs the XSent companion APK carried by XSent Spoof. This helper is
# safe to call both from customize.sh and service.sh.
MODDIR=${0%/*}
MODDIR=${MODDIR%/scripts}
APK_PATH="$MODDIR/xsent.apk"
APK_INFO="$MODDIR/xsent-apk.prop"
CONFIG_DIR="/data/adb/xsent-spoof"
STATE_FILE="$CONFIG_DIR/companion-apk.sha256"
PENDING_FILE="$MODDIR/.xsent-apk-pending"
LOG_FILE="/data/local/tmp/xsent_apk_install.log"
XSENT_RUNTIME_APK="/data/local/tmp/module_runtime_com_xsent.apk"

read_apk_info() {
    key="$1"
    sed -n "s/^${key}=//p" "$APK_INFO" 2>/dev/null | tail -n 1
}

PACKAGE_NAME="$(read_apk_info package)"
BUNDLED_VERSION_CODE="$(read_apk_info versionCode)"
BUNDLED_VERSION_NAME="$(read_apk_info versionName)"
BUNDLED_SHA256="$(read_apk_info sha256 | tr '[:lower:]' '[:upper:]')"
[ -n "$PACKAGE_NAME" ] || PACKAGE_NAME="io.xsent.spoof"

write_log() {
    mkdir -p "${LOG_FILE%/*}" 2>/dev/null || true
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)" "$*" >> "$LOG_FILE" 2>/dev/null || true
}

mark_pending() {
    touch "$PENDING_FILE" 2>/dev/null || true
    return 1
}

# XSent Full loads modules from the path published in xsent_modules.list. An
# Android package update changes /data/app/.../base.apk, so publishing that
# volatile path leaves XSent pointing at a deleted APK. Keep one stable,
# world-readable runtime mirror and migrate every known registry to it.
sync_xsent_runtime_apk() {
    installed_apk="$(pm path "$PACKAGE_NAME" 2>/dev/null | sed -n '1s/^package://p')"
    [ -r "$installed_apk" ] || return 1

    runtime_tmp="${XSENT_RUNTIME_APK}.tmp.$$"
    cp -f "$installed_apk" "$runtime_tmp" 2>/dev/null || return 1
    chmod 0644 "$runtime_tmp" 2>/dev/null || true
    chcon u:object_r:shell_data_file:s0 "$runtime_tmp" 2>/dev/null || true
    mv -f "$runtime_tmp" "$XSENT_RUNTIME_APK" 2>/dev/null || return 1
    chmod 0644 "$XSENT_RUNTIME_APK" 2>/dev/null || true
    chcon u:object_r:shell_data_file:s0 "$XSENT_RUNTIME_APK" 2>/dev/null || true

    for registry in \
        /data/adb/xsent/modules.list \
        /data/adb/xsent/modules.registry \
        /data/local/tmp/xsent_modules.list \
        /data/adb/xsent/manager/files/xsent_modules.list \
        /data/local/tmp/xsent/manager/files/xsent_modules.list; do
        [ -f "$registry" ] || continue
        registry_tmp="${registry}.tmp.$$"
        awk -F'|' -v apk="$XSENT_RUNTIME_APK" 'BEGIN { OFS="|" } $1 == "io.xsent.spoof" && NF >= 4 { $2=apk } { print }' \
            "$registry" > "$registry_tmp" 2>/dev/null || { rm -f "$registry_tmp"; continue; }
        cat "$registry_tmp" > "$registry" 2>/dev/null || true
        rm -f "$registry_tmp" 2>/dev/null || true
    done
    chmod 0666 /data/adb/xsent/modules.list /data/local/tmp/xsent_modules.list 2>/dev/null || true
    chmod 0600 /data/adb/xsent/modules.registry 2>/dev/null || true
    return 0
}

mark_complete() {
    sync_xsent_runtime_apk || write_log "Unable to refresh the XSent Full runtime APK mirror"
    mkdir -p "$CONFIG_DIR" 2>/dev/null || true
    printf '%s\n' "$BUNDLED_SHA256" > "$STATE_FILE" 2>/dev/null || true
    chmod 0600 "$STATE_FILE" 2>/dev/null || true
    rm -f "$PENDING_FILE" 2>/dev/null || true
    return 0
}

if [ ! -s "$APK_PATH" ] || [ ! -s "$APK_INFO" ]; then
    write_log "Bundled XSent APK or metadata is missing"
    exit 1
fi

if command -v sha256sum >/dev/null 2>&1 && [ -n "$BUNDLED_SHA256" ]; then
    ACTUAL_SHA256="$(sha256sum "$APK_PATH" 2>/dev/null | awk '{print toupper($1)}')"
    if [ -z "$ACTUAL_SHA256" ] || [ "$ACTUAL_SHA256" != "$BUNDLED_SHA256" ]; then
        write_log "Bundled XSent APK checksum mismatch"
        exit 1
    fi
fi

if ! command -v pm >/dev/null 2>&1 || ! pm path android >/dev/null 2>&1; then
    write_log "Package Manager is not ready; installation deferred until boot"
    mark_pending
    exit 1
fi

INSTALLED_PATHS="$(pm path "$PACKAGE_NAME" 2>/dev/null)"
INSTALL_MODE="fresh install"
[ -n "$INSTALLED_PATHS" ] && INSTALL_MODE="update"

INSTALLED_VERSION_CODE=""
if [ -n "$INSTALLED_PATHS" ]; then
    INSTALLED_VERSION_CODE="$(dumpsys package "$PACKAGE_NAME" 2>/dev/null | sed -n 's/.*versionCode=\([0-9][0-9]*\).*/\1/p' | head -n 1)"
fi

case "$INSTALLED_VERSION_CODE:$BUNDLED_VERSION_CODE" in
    *[!0-9:]*|:*) ;;
    *)
        if [ "$INSTALLED_VERSION_CODE" -gt "$BUNDLED_VERSION_CODE" ] 2>/dev/null; then
            write_log "Skipped bundled $BUNDLED_VERSION_NAME because installed versionCode $INSTALLED_VERSION_CODE is newer"
            mark_complete
            printf '%s\n' "XSent APK: newer installed version kept"
            exit 0
        fi
        ;;
esac

RECORDED_SHA256="$(cat "$STATE_FILE" 2>/dev/null | tr '[:lower:]' '[:upper:]')"
if [ -n "$INSTALLED_PATHS" ] && [ "$RECORDED_SHA256" = "BLOCKED:$BUNDLED_SHA256" ]; then
    write_log "Bundled XSent update remains blocked by an incompatible installed signature"
    sync_xsent_runtime_apk || true
    rm -f "$PENDING_FILE" 2>/dev/null || true
    printf '%s\n' "XSent APK: installed signature is incompatible; existing app kept"
    exit 0
fi
INSTALLED_SHA256=""
if [ -n "$INSTALLED_PATHS" ] && command -v sha256sum >/dev/null 2>&1; then
    INSTALLED_BASE="$(printf '%s\n' "$INSTALLED_PATHS" | sed -n '1s/^package://p')"
    [ -r "$INSTALLED_BASE" ] && INSTALLED_SHA256="$(sha256sum "$INSTALLED_BASE" 2>/dev/null | awk '{print toupper($1)}')"
fi
if [ -n "$INSTALLED_PATHS" ] && [ -n "$BUNDLED_SHA256" ] && \
    { [ "$INSTALLED_SHA256" = "$BUNDLED_SHA256" ] || \
      { [ -z "$INSTALLED_SHA256" ] && [ "$RECORDED_SHA256" = "$BUNDLED_SHA256" ]; }; }; then
    write_log "Bundled XSent $BUNDLED_VERSION_NAME is already installed"
    mark_complete
    printf '%s\n' "XSent APK: already current"
    exit 0
fi

STAGED_APK="/data/local/tmp/xsent-module-install.apk"
rm -f "$STAGED_APK" 2>/dev/null || true
if ! cp -f "$APK_PATH" "$STAGED_APK" 2>/dev/null; then
    write_log "Unable to stage APK for $INSTALL_MODE"
    mark_pending
    exit 1
fi
chmod 0644 "$STAGED_APK" 2>/dev/null || true
chcon u:object_r:shell_data_file:s0 "$STAGED_APK" 2>/dev/null || true

INSTALL_OUTPUT="$(pm install -r -d -g "$STAGED_APK" 2>&1)"
INSTALL_RESULT=$?
rm -f "$STAGED_APK" 2>/dev/null || true

if [ "$INSTALL_RESULT" -eq 0 ] && printf '%s' "$INSTALL_OUTPUT" | grep -q 'Success'; then
    write_log "XSent $BUNDLED_VERSION_NAME $INSTALL_MODE succeeded"
    mark_complete
    printf '%s\n' "XSent APK: $INSTALL_MODE succeeded"
    exit 0
fi

case "$INSTALL_OUTPUT" in
    *INSTALL_FAILED_UPDATE_INCOMPATIBLE*|*signatures\ do\ not\ match*|*signature*incompatible*)
        mkdir -p "$CONFIG_DIR" 2>/dev/null || true
        printf 'blocked:%s\n' "$BUNDLED_SHA256" > "$STATE_FILE" 2>/dev/null || true
        chmod 0600 "$STATE_FILE" 2>/dev/null || true
        rm -f "$PENDING_FILE" 2>/dev/null || true
        write_log "XSent $INSTALL_MODE blocked by incompatible installed signature; existing app preserved"
        sync_xsent_runtime_apk || true
        printf '%s\n' "XSent APK: incompatible signature; existing app was not removed"
        exit 0
        ;;
esac

write_log "XSent $BUNDLED_VERSION_NAME $INSTALL_MODE failed: $INSTALL_OUTPUT"
mark_pending
printf '%s\n' "XSent APK: $INSTALL_MODE deferred; see $LOG_FILE"
exit 1
