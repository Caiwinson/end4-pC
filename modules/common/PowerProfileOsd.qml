pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root
    // Call from shell.qml Component.onCompleted to instantiate this singleton
    function load() {}

    property bool shown: false
    property bool ready: false   // ignore the initial value at startup

    function label(p) {
        if (p === PowerProfile.PowerSaver) return "Power saver";
        if (p === PowerProfile.Performance) return "Performance";
        return "Balanced";
    }

    Timer { running: true; interval: 1000; onTriggered: root.ready = true }
    Timer { id: hideTimer; interval: 1500; onTriggered: root.shown = false }

    Connections {
        target: PowerProfiles
        function onProfileChanged() {
            if (!root.ready) return;
            root.shown = true;
            hideTimer.restart();
        }
    }

    LazyLoader {
        active: root.shown

        PanelWindow {
            anchors.bottom: true
            margins.bottom: 80
            exclusiveZone: 0
            implicitWidth: 220
            implicitHeight: 48
            color: "transparent"
            mask: Region {}          // click-through

            Rectangle {
                anchors.fill: parent
                radius: 24
                color: "#cc241b1d"
                Text {
                    anchors.centerIn: parent
                    text: root.label(PowerProfiles.profile)
                    color: "#efdfe1"
                    font.pixelSize: 15
                }
            }
        }
    }
}
