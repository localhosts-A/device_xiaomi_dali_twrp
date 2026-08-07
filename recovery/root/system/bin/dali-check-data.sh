#!/system/bin/sh
# dali-check-data.sh
# Detect a corrupt (or non-F2FS) userdata superblock very early in recovery
# startup and rebuild the filesystem in place, so TWRP never falls into the
# "Decrypt adopted storage" wait (which otherwise looks like a hang on the
# splash screen). A corrupt superblock means the partition contents are
# already unrecoverable; rebuilding is the only way to make recovery usable.
#
# The F2FS superblock magic lives at byte offset 1024 (0x400) and is
# 0xF2F52010 on disk. If we cannot read that magic, the partition is either
# not F2FS or its primary superblock is corrupt.

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
        log "corrupt/non-F2FS superblock; rebuilding userdata filesystem"
        if make_f2fs -f "$DATA_DEV" >> "$LOG" 2>&1; then
            log "userdata filesystem rebuilt successfully"
        else
            log "make_f2fs failed; leaving partition as-is"
        fi
        ;;
esac

touch "$MARK"
exit 0
