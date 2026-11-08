import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick

StyledPopup {
    id: root

    property real gpuUsage: 0
    property real vramUsed: 0
    property real vramTotal: 0
    property real gpuTemp: 0

    function formatBytes(bytes) {
        return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB"
    }

    Row {
        spacing: 5

        ResourceCard {
            label: "GPU"
            iconText: "developer_board"
            iconShape: MaterialShape.Shape.Gem
            value: root.gpuUsage
            sublabel: `${Math.round(root.gpuTemp)}°C`
            sublabelColor: root.gpuTemp > 85 ? Appearance.colors.colError
                : root.gpuTemp > 70 ? Appearance.m3colors.m3tertiary
                : Appearance.colors.colOnLayer1
        }

        ResourceCard {
            label: "VRAM"
            iconText: "memory_alt"
            iconShape: MaterialShape.Shape.Clover4Leaf
            value: root.vramTotal > 0 ? root.vramUsed / root.vramTotal : 0
            sublabel: root.formatBytes(root.vramUsed) + " / " + root.formatBytes(root.vramTotal)
        }
    }
}
