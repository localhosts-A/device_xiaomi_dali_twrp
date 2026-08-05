#!/system/bin/sh
# dali-prune-modules.sh
# Recovery only needs the module closure below (requested modules plus their
# transitive modules.dep dependencies). The official platform fragment
# contributes ~270 extra modules (~29 MiB) that are only useful to the normal
# system boot; pruning them from the running Recovery root makes the
# KernelModuleLoader tmpfs copy and module scan much faster. The platform
# fragment is untouched, so normal system boot is unaffected.
keep="aee_aed.ko blocktag.ko cl_dsp-core.ko cs40l26-core.ko cs40l26-i2c.ko cs40l26-spi.ko ffa_v11.ko flashlight.ko goodix_core_dali.ko irq-dbg.ko ise_lpm.ko leds-mt6379.ko leds-mt6379pmic.ko miev.ko mitee.ko mpbe.ko mrdump.ko mtk-ise-mailbox.ko mtk-mbox.ko mtk_battery_oc_throttling.ko mtk_bp_thl.ko mtk_dynamic_loading_throttling.ko mtk_gpueb.ko mtk_low_battery_throttling.ko mtk_mdpm.ko mtk_pbm.ko mtk_peak_power_budget.ko mtk_rpmsg_mbox.ko mtk_tinysys_ipi.ko nxp_i2c.ko p73.ko pmic_lbat_service.ko pmic_lvsys_notify.ko rpmb-mtk.ko rpmb.ko scp.ko snd-soc-cs40l26.ko spi-mt65xx.ko teeperf.ko tinysys-scmi.ko tui-common.ko ufs-mediatek-dbg.ko ufs-mediatek-mod-ise.ko v4l2-flash-led-class.ko xiaomi_touch_dali.ko"
for module in /lib/modules/*.ko
do
    base=${module##*/}
    case " $keep " in
        *" $base "*) ;;
        *) rm -f -- "$module" ;;
    esac
done
rmdir /lib/modules/6.6 /lib/modules/6.6-gki 2>/dev/null
exit 0
