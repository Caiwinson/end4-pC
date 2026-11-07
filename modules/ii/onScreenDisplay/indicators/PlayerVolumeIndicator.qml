import qs.services
import QtQuick
import qs.modules.ii.onScreenDisplay

// Volume of the MPRIS player that changed (e.g. via `playerctl volume`).
// `player` is fed by OnScreenDisplay.qml.
OsdValueIndicator {
    property var player: null

    value: player?.volume ?? 0
    icon: value <= 0 ? "music_off" : "music_note"
    name: Translation.tr("Player volume")
}
