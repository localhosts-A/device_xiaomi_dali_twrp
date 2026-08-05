#!/system/bin/sh
# Keep a persistent copy of the Recovery log so sideload/OTA failures survive
# reboots (tmpfs /tmp is cleared on reboot, /cache is not).
mkdir -p /cache/recovery
if [ -f /tmp/dali-log-persist.pid ] && kill -0 $(cat /tmp/dali-log-persist.pid) 2>/dev/null; then exit 0; fi
echo $$ > /tmp/dali-log-persist.pid
trap 'rm -f /tmp/dali-log-persist.pid' EXIT
last_mtime=
while true; do
    if [ -f /tmp/recovery.log ]; then
        mtime=$(stat -c %Y /tmp/recovery.log 2>/dev/null) || mtime=
        if [ "$mtime" != "$last_mtime" ]; then
            cp -f /tmp/recovery.log /cache/recovery/log 2>/dev/null
            last_mtime=$mtime
        fi
    fi
    sleep 5
done
