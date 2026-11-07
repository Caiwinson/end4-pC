import qs.services
import QtQuick
import Quickshell.Services.UPower
import qs.modules.ii.onScreenDisplay

OsdTextIndicator {
    readonly property var profile: PowerProfiles.profile

    name: Translation.tr("Power profile")
    icon: profile === PowerProfile.PowerSaver ? "energy_savings_leaf"
        : profile === PowerProfile.Performance ? "speed"
        : "balance"
    label: profile === PowerProfile.PowerSaver ? Translation.tr("Power saver")
        : profile === PowerProfile.Performance ? Translation.tr("Performance")
        : Translation.tr("Balanced")
}
