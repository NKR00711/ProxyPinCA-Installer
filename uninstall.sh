#!/system/bin/sh
# ProxyPin Certificate Installer - Uninstall Script
# Author: NKR00711
# GitHub: https://github.com/NKR00711/ProxyPinCA-Installer

MODDIR=${0%/*}
LOG_FILE="/data/local/tmp/ProxyPinCert.log"
NOMOUNT_NM="/data/adb/modules/nomount/bin/nm"
CERT_DIR="${MODDIR}/system/etc/security/cacerts"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [uninstall] $1" >> "$LOG_FILE"
}

log "Uninstall script started"

# If NoMount present, remove rules we added (best-effort)
if [ -x "$NOMOUNT_NM" ]; then
    log "NoMount detected — removing rules for our certificates"
    for cert in "$CERT_DIR"/*.0; do
        [ -f "$cert" ] || continue
        name=$(basename "$cert")
        SYS_VPATH="/system/etc/security/cacerts/$name"
        SYSROOT_VPATH="/system_root/system/etc/security/cacerts/$name"
        APEX_VPATH="/apex/com.android.conscrypt/cacerts/$name"

        "$NOMOUNT_NM" rule del "$SYS_VPATH" 2>/dev/null || true
        "$NOMOUNT_NM" rule del "$SYSROOT_VPATH" 2>/dev/null || true
        "$NOMOUNT_NM" rule del "$APEX_VPATH" 2>/dev/null || true

        log "NoMount: removed rules for $name"
    done
fi

# Unmount APEX certificates if mounted
unmount_apex() {
    local apex_dir="/apex/com.android.conscrypt/cacerts"
    local temp_dir="/data/local/tmp/proxypin-apex-ca"
    
    # Unmount APEX directory
    if mountpoint -q "$apex_dir" 2>/dev/null; then
        umount "$apex_dir" 2>/dev/null
        log "Unmounted APEX CA directory"
    fi
    
    # Try to unmount in all namespaces
    for pid in 1 $(pidof zygote 2>/dev/null) $(pidof zygote64 2>/dev/null); do
        if [ -d "/proc/$pid/ns/mnt" ]; then
            nsenter --mount=/proc/$pid/ns/mnt -- \
                umount "$apex_dir" 2>/dev/null
        fi
    done
    
    # Unmount and remove temp directory
    if mountpoint -q "$temp_dir" 2>/dev/null; then
        umount "$temp_dir" 2>/dev/null
        log "Unmounted temp directory"
    fi
    rm -rf "$temp_dir" 2>/dev/null
}

# Cleanup temporary files
cleanup_temp() {
    rm -rf /data/local/tmp/apex-ca-copy 2>/dev/null
    rm -rf /data/local/tmp/apex-ca-reinject 2>/dev/null
    rm -rf /data/local/tmp/proxypin-apex-ca 2>/dev/null
    rm -f "$MODDIR/.apex_bypass_needed" 2>/dev/null
    log "Cleaned up temporary files"
}

# Main
unmount_apex
cleanup_temp

log "Uninstall completed"
log "NOTE: Reboot recommended to fully remove certificate from system"
