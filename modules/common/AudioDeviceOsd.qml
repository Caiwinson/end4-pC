pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root
    // Call from shell.qml Component.onCompleted to instantiate this singleton
    function load() {}

    property bool shown: false
    property bool ready: false   // ignore the initial value at startup

    readonly property var sink: Pipewire.defaultAudioSink

    // Optional friendly names: first match on the node name wins.
    // Node names look like "alsa_output.usb-KTMicro_Chu2_DSP-00.analog-stereo"
    readonly property var friendlyNames: [
        { match: "KTMicro_Chu2_DSP", label: "Earphone" },
        { match: "pci-0000_03_00.6", label: "Speaker" }
    ]

    function label(s) {
        if (!s) return "No output";
        for (let i = 0; i < friendlyNames.length; i++) {
            if (s.name && s.name.indexOf(friendlyNames[i].match) !== -1)
                return friendlyNames[i].label;
        }
        return s.nickname || s.description || s.name;
    }

    // Keeps the sink's properties (description, nickname) populated
    PwObjectTracker { objects: [root.sink] }

    Timer { running: true; interval: 1000; onTriggered: root.ready = true }
    Timer { id: hideTimer; interval: 1500; onTriggered: root.shown = false }

    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() {
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
            implicitWidth: Math.max(220, text.implicitWidth + 56)
            implicitHeight: 48
            color: "transparent"
            mask: Region {}          // click-through

            Rectangle {
                anchors.fill: parent
                radius: 24
                color: "#cc241b1d"
                Text {
                    id: text
                    anchors.centerIn: parent
                    text: "󰓃  " + root.label(root.sink)   // speaker glyph (Nerd Font)
                    color: "#efdfe1"
                    font.pixelSize: 15
                }
            }
        }
    }
}
