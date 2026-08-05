#!/system/bin/sh
# dali-ensure-tee.sh
#
# Recovery's init intermittently fails to actually start tee-supplicant even
# though the HAL-chain action continues (init.svc.tee-supplicant stays empty).
# Wait for the TEE device, then retry via ctl.start and, if init still will
# not track the service, launch the daemon directly (verified working when
# exec'd manually). KeyMint only needs the daemon process present.

# If a tee-supplicant is already running (e.g. a previous exec or init
# finally started it), there is nothing to do -- avoid a second instance.
if [ -f /tmp/dali-ensure-tee.pid ] && kill -0 $(cat /tmp/dali-ensure-tee.pid) 2>/dev/null; then exit 0; fi
echo $$ > /tmp/dali-ensure-tee.pid
trap 'rm -f /tmp/dali-ensure-tee.pid' EXIT

if [ -n "$(pidof tee-supplicant)" ]; then
    echo "dali-ensure-tee: already running pid=$(pidof tee-supplicant)"
    exit 0
fi

i=0
while [ $i -lt 20 ]; do
    [ -c /dev/tee0 ] && break
    sleep 0.5
    i=$((i + 1))
done

state=$(getprop init.svc.tee-supplicant)
if [ "$state" != running ]; then
    setprop ctl.start tee-supplicant 2>/dev/null
    j=0
    while [ "$j" -lt 10 ]; do
        state=$(getprop init.svc.tee-supplicant)
        [ "$state" = running ] && break
        sleep 0.2
        j=$((j + 1))
    done
fi

if [ "$state" != running ] && [ -z "$(pidof tee-supplicant)" ]; then
    # Direct fallback with the service environment: init exec lacks the
    # library path, so the daemon would die instantly without it. setsid
    # detaches it from the exec shell.
    export LD_LIBRARY_PATH=/system/lib64:/vendor/lib64:/odm/lib64:/vendor/lib64/hw:/odm/lib64/hw
    export LD_BIND_NOW=1
    setsid /vendor/bin/tee-supplicant >/dev/null 2>&1 &
fi

echo "dali-ensure-tee: state=$(getprop init.svc.tee-supplicant) pid=$(pidof tee-supplicant)"
exit 0
