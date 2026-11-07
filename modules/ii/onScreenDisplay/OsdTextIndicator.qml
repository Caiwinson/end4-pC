import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

// Same pill styling as OsdValueIndicator, but shows a text label instead of a slider.
Item {
    id: root
    required property string icon
    required property string label
    required property string name

    implicitWidth: Appearance.sizes.osdWidth + 4 * Appearance.sizes.elevationMargin + 80
    implicitHeight: valueIndicator.implicitHeight + 2 * Appearance.sizes.elevationMargin

    Rectangle {
        id: valueIndicator
        WindowGlass {
            anchors.fill: parent
            glassEnabled: (parent?.color.a ?? 0) > 0
            cardRadius: parent?.radius ?? 0
            tint: parent?.color ?? 'transparent'
        }
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        radius: Appearance.rounding.full
        color: Appearance.colors.colUiBackground
        implicitHeight: 52

        RowLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 8

            Rectangle {
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 40
                radius: height / 2
                color: Appearance.colors.colSecondaryContainer

                MaterialSymbol {
                    anchors.centerIn: parent
                    color: Appearance.colors.colOnSecondaryContainer
                    renderType: Text.QtRendering
                    text: root.icon
                    iconSize: 25
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 12
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: Appearance.colors.colOnLayer0
                font.pixelSize: Appearance.font.pixelSize.normal
                text: root.label
            }
        }
    }
}
