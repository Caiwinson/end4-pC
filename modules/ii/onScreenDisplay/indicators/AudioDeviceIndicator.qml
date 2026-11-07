import qs.services
import QtQuick
import Quickshell.Services.Pipewire
import qs.modules.ii.onScreenDisplay

OsdTextIndicator {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink

    // Optional friendly names: first match on the node name wins.
    // Node names look like "alsa_output.usb-KTMicro_Chu2_DSP-00.analog-stereo"
    readonly property var friendlyNames: [
        { match: "KTMicro_Chu2_DSP", label: "Earphone", icon: "headphones" },
        { match: "pci-0000_03_00.6", label: "Speaker", icon: "speaker" }
    ]
    readonly property var friendly: {
        const n = root.sink?.name ?? "";
        return friendlyNames.find(f => n.indexOf(f.match) !== -1) ?? null;
    }

    // Keeps the sink's properties (description, nickname) populated
    PwObjectTracker { objects: [root.sink] }

    name: Translation.tr("Audio output")
    icon: friendly?.icon ?? "speaker"
    label: !sink ? Translation.tr("No output")
        : (friendly?.label ?? sink.nickname ?? sink.description ?? sink.name)
}
