import qs.services
import QtQuick
import qs.modules.ii.onScreenDisplay

OsdTextIndicator {
    // Fed by OnScreenDisplay.qml (watches ~/.config/hypr/display-mode)
    property string mode: "off"

    name: Translation.tr("Display mode")
    icon: mode === "on" ? "desktop_windows" : "desktop_access_disabled"
    label: mode === "on" ? Translation.tr("Internal screen: On")
                         : Translation.tr("Internal screen: Off")
}
