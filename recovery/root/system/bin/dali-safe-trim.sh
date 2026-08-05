#!/system/bin/sh
# Safe trim for Flash current OrangeFox: remove from the inactive platform
# cpio only entries that are byte-identical (or identical symlink targets) in
# that slot's official recovery cpio. Normal-boot platform files (sepolicy,
# ueventd, init, fstab) stay intact.
# usage: dali-safe-trim.sh <magiskboot> <platform.cpio> <official-recovery.cpio>
set -e
MAGISKBOOT=$1
PLATFORM=$2
OFFICIAL_REC=$3
[ -x "$MAGISKBOOT" ] || exit 1
[ -f "$PLATFORM" ] || exit 1
[ -f "$OFFICIAL_REC" ] || exit 1
WORK=/tmp/dali-safe-trim
rm -rf "$WORK"
mkdir -p "$WORK/p" "$WORK/r"
trap 'rm -rf "$WORK"' EXIT
(cd "$WORK/p" && /system/bin/cpio -idmu --quiet < "$PLATFORM") || exit 1
(cd "$WORK/r" && /system/bin/cpio -idmu --quiet < "$OFFICIAL_REC") || exit 1
(cd "$WORK/r" && find . \( -type f -o -type l \) -print) > "$WORK/list"

# Execute one batch of magiskboot cpio rm commands. The command line is
# assembled from positional parameters and run with "$@" -- never eval --
# so cpio entry names can never reach the shell as code.
run_trim() {
    [ "$#" -gt 3 ] || return 0
    "$@" >/dev/null 2>&1 || exit 1
}

set -- "$MAGISKBOOT" cpio "$PLATFORM"
batch=0
while IFS= read -r p; do
    [ -n "$p" ] || continue
    rel=${p#./}
    if [ -L "$WORK/r/$rel" ] && [ -L "$WORK/p/$rel" ]; then
        if [ "$(readlink "$WORK/r/$rel")" = "$(readlink "$WORK/p/$rel")" ]; then
            # Whitelist check: reject names carrying shell metacharacters
            # (e.g. $ ( ) | ; & space quote backtick glob chars) or names
            # that could be parsed as an option. Only plain safe names are
            # ever passed to magiskboot.
            case "$rel" in
                -*|*[!A-Za-z0-9_./:+=-]*)
                    echo "dali-safe-trim: refusing unsafe cpio entry: $rel" >&2
                    exit 1 ;;
            esac
            set -- "$@" "rm $rel"
            batch=$((batch+1))
            if [ "$batch" -ge 500 ]; then
                run_trim "$@"
                set -- "$MAGISKBOOT" cpio "$PLATFORM"
                batch=0
            fi
        fi
    elif [ -f "$WORK/r/$rel" ] && [ -f "$WORK/p/$rel" ]; then
        if cmp -s "$WORK/r/$rel" "$WORK/p/$rel"; then
            case "$rel" in
                -*|*[!A-Za-z0-9_./:+=-]*)
                    echo "dali-safe-trim: refusing unsafe cpio entry: $rel" >&2
                    exit 1 ;;
            esac
            set -- "$@" "rm $rel"
            batch=$((batch+1))
            if [ "$batch" -ge 500 ]; then
                run_trim "$@"
                set -- "$MAGISKBOOT" cpio "$PLATFORM"
                batch=0
            fi
        fi
    fi
done < "$WORK/list"
run_trim "$@"
exit 0
