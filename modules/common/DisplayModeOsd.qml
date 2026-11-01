import QtQuick
import Quickshell
import Quickshell.Io

// Shows an OSD whenever ~/.config/hypr/display-mode changes (SUPER + P).
Scope {
    id: root
    property bool shown: false
    property bool ready: false   // ignore the initial value at startup
    property string mode: "off"

    readonly property var labels: ({
        "on": "Internal screen: On",
        "off": "Internal screen: Off"
    })

    Timer { running: true; interval: 1000; onTriggered: root.ready = true }
    Timer { id: hideTimer; interval: 1500; onTriggered: root.shown = false }

    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/display-mode"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const m = text().trim();
            // Writes truncate first, so ignore empty/partial reads.
            if (!(m in root.labels)) return;

            root.mode = m;
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
            implicitWidth: 260
            implicitHeight: 48
            color: "transparent"
            mask: Region {}          // click-through

            Rectangle {
                anchors.fill: parent
                radius: 24
                color: "#cc241b1d"
                Text {
                    anchors.centerIn: parent
                    text: root.labels[root.mode]
                    color: "#efdfe1"
                    font.pixelSize: 15
                }
            }
        }
    }
}
