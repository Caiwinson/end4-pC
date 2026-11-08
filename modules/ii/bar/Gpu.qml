import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

BarWidgetSwitcherArea {
    id: root
    property color contentColor: Appearance.colors.colOnSecondaryContainer
    property bool contentColorOverridden: false
    horizontalExtraPadding: 12
    leftExtraPadding: Config.options.bar.resources.style === "text" ? 4 : 0
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    // Data (usage and vram are 0..1, bytes for memory, °C for temp)
    property bool hasGpu: false
    property real gpuUsage: 0
    property real vramUsed: 0
    property real vramTotal: 0
    property real gpuTemp: 0
    readonly property real vramPercentage: vramTotal > 0 ? vramUsed / vramTotal : 0

    visible: hasGpu

    function parse(text) {
        const p = text.trim().split(/\s+/).map(Number)
        if (p.length < 4 || p.some(n => !Number.isFinite(n))) {
            root.hasGpu = false
            return
        }
        root.gpuUsage = Math.max(0, Math.min(1, p[0] / 100))
        root.vramUsed = p[1]
        root.vramTotal = p[2]
        root.gpuTemp = p[3] / 1000
        root.hasGpu = true
    }

    Process {
        id: poller
        command: ["bash", "-c", [
            "best=''; max=0",
            "for d in /sys/class/drm/card[0-9]*/device; do",
            "  [ -r \"$d/gpu_busy_percent\" ] || continue",
            "  t=$(cat \"$d/mem_info_vram_total\" 2>/dev/null || echo 0)",
            "  if [ \"$t\" -ge \"$max\" ]; then max=$t; best=$d; fi",
            "done",
            "[ -z \"$best\" ] && exit 0",
            "busy=$(cat \"$best/gpu_busy_percent\")",
            "used=$(cat \"$best/mem_info_vram_used\")",
            "temp=$(cat \"$best\"/hwmon/hwmon*/temp1_input 2>/dev/null | head -n1)",
            "echo \"$busy $used $max ${temp:-0}\""
        ].join("\n")]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Timer {
        interval: Config.options.resources.updateInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!poller.running) poller.running = true
    }

    Component {
        id: rowContent
        RowLayout {
            spacing: 0
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "developer_board"
                label: "GPU"
                percentage: root.gpuUsage
                warningThreshold: 90
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "memory_alt"
                label: "VRM"
                percentage: root.vramPercentage
                Layout.leftMargin: 6
                warningThreshold: 90
            }
        }
    }

    Component {
        id: colContent
        ColumnLayout {
            spacing: 7
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "developer_board"
                label: "GPU"
                vertical: true
                percentage: root.gpuUsage
                warningThreshold: 90
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "memory_alt"
                label: "VRM"
                vertical: true
                percentage: root.vramPercentage
                warningThreshold: 90
            }
        }
    }

    rowDefault: rowContent
    rowMaterial: rowContent
    colDefault: colContent
    colMaterial: colContent

    GpuPopup {
        hoverTarget: root
        gpuUsage: root.gpuUsage
        vramUsed: root.vramUsed
        vramTotal: root.vramTotal
        gpuTemp: root.gpuTemp
    }
}
