#!/system/bin/sh
# dali-check-data.sh
# Detect a corrupt/non-F2FS userdata superblock very early in recovery
# startup and try to repair it WITHOUT formatting, so TWRP never falls
# into the "Decrypt adopted storage" wait (which otherwise looks like a
# hang on the splash screen) and no data is ever lost automatically.
#
# The F2FS superblock magic lives at byte offset 1024 (0x400) and is
# 0xF2F52010 on disk. If we cannot read that magic, the primary
# superblock is missing/corrupt; fsck.f2fs can often recover it from the
# backup superblock / checkpoint area.

DATA_DEV=/dev/block/by-name/userdata
MARK=/tmp/dali-data-check.done
LOG=/tmp/dali-data-check.log

[ -e "$MARK" ] && exit 0

log() {
    echo "I:dali-data-check: $*" >> "$LOG"
}

if [ ! -e "$DATA_DEV" ]; then
    log "userdata device not found; skipping"
    touch "$MARK"
    exit 0
fi

# Read the 4-byte magic at offset 1024 (little-endian on disk).
magic=$(dd if="$DATA_DEV" bs=1 skip=1024 count=4 2>/dev/null | od -An -tx1 | tr -d ' \n')
log "userdata superblock magic at +1024: $magic"

case "$magic" in
    f2f52010|1020f5f2)
        log "valid F2FS superblock; no action"
        ;;
    *)
        log "corrupt/non-F2FS superblock; attempting fsck repair (no format)"
        # fsck.f2fs -a: check/fix potential corruption reported by f2fs.
        # It never reformats; if the backup superblock/checkpoint is
        # intact it restores the primary one and keeps the data.
        if fsck.f2fs -a "$DATA_DEV" >> "$LOG" 2>&1; then
            log "fsck repair completed"
        else
            log "fsck could not repair; leaving partition untouched (user may format manually)"
        fi
        ;;
esac

touch "$MARK"
exit 0
