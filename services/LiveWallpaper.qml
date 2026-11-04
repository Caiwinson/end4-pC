pragma Singleton

import qs.modules.common
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

/*
 * Control surface for the mpvpaper live wallpaper.
 *
 * switchwall.sh gives every output an mpv IPC socket, so the wallpaper can be
 * paused and resumed instead of only being killed and relaunched. Commands go
 * to every socket at once: one wallpaper, however many screens.
 *
 * mpvpaper also pauses on its own when the wallpaper is hidden (its -p flag).
 * That one is invisible from here and does not change `paused`, which tracks
 * what was asked for, not what mpv is doing behind a maximised window.
 */
Singleton {
    id: root

    readonly property string socketPrefix:
        `${Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000"}/mpvpaper-`

    // A live wallpaper is running and reachable
    property bool available: false
    // What we last asked for
    property bool paused: false
    // The policy (power or gamemode, not the user) paused the wallpaper
    property bool pausedByPolicy: false
    // The user resumed the wallpaper while the policy wanted it paused
    property bool policyOverridden: false

    readonly property bool pauseOnBattery: Config.options?.background.liveWallpaper.pauseOnBattery ?? false
    readonly property real pauseBelowPercent: Config.options?.background.liveWallpaper.pauseBelowPercent ?? 0
    // Pause while the power profile is "power-saver" (set to false to disable)
    readonly property bool pauseOnPowerSaver: true
    // Pause while Feral GameMode (gamemoded) is active (set to false to disable)
    readonly property bool pauseOnGameMode: true
    // Result of `gamemoded -s`
    property bool gameModeActive: false

    function load() {}

    property string pendingCommand: ""

    function sendCommand(json) {
        if (!root.available) {
            console.log(`[LiveWallpaper] sendCommand skipped (available=false): ${json}`);
            return;
        }
        // A command sent while the previous one is still running used to be
        // dropped silently (setting running=true on a running Process is a no-op).
        // Queue it; commandProc.onRunningChanged sends it when the last one ends.
        if (commandProc.running) {
            root.pendingCommand = json;
            console.log(`[LiveWallpaper] sendCommand queued: ${json}`);
            return;
        }
        console.log(`[LiveWallpaper] sendCommand: ${json}`);
        // Not silenced: each socket prints "<path>: <reply>" so failures show in the log
        commandProc.command = ["bash", "-c",
            `for s in ${root.socketPrefix}*.sock; do [ -S "$s" ] || continue; `
            + `printf '%s: ' "$s"; printf '%s\\n' '${json}' | socat -T1 - UNIX-CONNECT:"$s" 2>&1 | head -1; done`];
        commandProc.running = true;
    }

    function setPaused(value) {
        root.paused = value;
        root.sendCommand(`{"command":["set_property","pause",${value}]}`);
    }

    function toggle() {
        // A manual toggle takes over from the power policy
        root.pausedByPolicy = false;
        if (root.policyWantsPause) root.policyOverridden = root.paused;
        root.setPaused(!root.paused);
    }
    function pause()  { root.setPaused(true) }
    function resume() { root.setPaused(false) }

    Process {
        id: commandProc
        stdout: StdioCollector {
            onStreamFinished: console.log(`[LiveWallpaper] mpv replied: ${text.trim() || "(nothing)"}`)
        }
        onRunningChanged: {
            if (!running && root.pendingCommand !== "") {
                const next = root.pendingCommand;
                root.pendingCommand = "";
                root.sendCommand(next);
            }
        }
    }

    // Reads back the real state, so a wallpaper change or a restart does not
    // leave the button lying about what is playing.
    Process {
        id: pollProc
        running: true
        command: ["bash", "-c",
            `for s in ${root.socketPrefix}*.sock; do [ -S "$s" ] || continue; `
            + `printf '%s\\n' '{"command":["get_property","pause"]}' | socat -T1 - UNIX-CONNECT:"$s" 2>/dev/null | grep -m1 '"error"'; exit 0; done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim();
                if (line === "") {
                    root.available = false;
                    return;
                }
                try {
                    const reply = JSON.parse(line);
                    const ok = reply.error === "success";
                    // Update `paused` first so the policy sees fresh state
                    if (ok) root.paused = reply.data === true;
                    root.available = ok;
                } catch (e) {
                    root.available = false;
                }
                // Re-apply the policy every poll: survives wallpaper restarts
                root.applyPolicy();
            }
        }
    }

    Timer {
        running: true
        repeat: true
        interval: 4000
        onTriggered: {
            pollProc.running = true;
            if (root.pauseOnGameMode) gameModeProc.running = true;
        }
    }

    // `gamemoded -s` prints "gamemode is active" or "gamemode is inactive".
    // Match on the text, not the exit code, and anchor on "is active" because
    // "inactive" contains "active".
    Process {
        id: gameModeProc
        running: root.pauseOnGameMode
        command: ["bash", "-c", "gamemoded -s 2>&1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const active = /\bis active\b/.test(text);
                if (active !== root.gameModeActive)
                    console.log(`[LiveWallpaper] gamemoded -s -> ${JSON.stringify(text.trim())} active=${active}`);
                root.gameModeActive = active;
            }
        }
    }

    // Power policies. UPower.onBattery is true whenever AC is unplugged, which
    // is more reliable than inferring it from the battery's charge state.
    readonly property bool onBattery: UPower.onBattery
    readonly property bool powerSaverActive: root.pauseOnPowerSaver
        && PowerProfiles.profile === PowerProfile.PowerSaver

    readonly property bool batteryPolicyActive: root.onBattery
        && (root.pauseOnBattery
            || (root.pauseBelowPercent > 0 && Battery.available
                && Battery.percentage * 100 <= root.pauseBelowPercent))

    readonly property bool gameModePolicyActive: root.pauseOnGameMode && root.gameModeActive

    readonly property bool policyWantsPause: root.batteryPolicyActive || root.powerSaverActive
        || root.gameModePolicyActive
    readonly property bool shouldPauseForPower: root.available && root.policyWantsPause

    function applyPolicy() {
        if (!root.available) return;
        if (root.policyWantsPause) {
            if (!root.paused && !root.policyOverridden) {
                root.pausedByPolicy = true;
                root.pause();
            }
        } else {
            root.policyOverridden = false;
            // Only resume what the policy paused
            if (root.pausedByPolicy) {
                root.pausedByPolicy = false;
                root.resume();
            }
        }
    }

    onShouldPauseForPowerChanged: root.applyPolicy()
    onPolicyWantsPauseChanged: {
        console.log(`[LiveWallpaper] policyWantsPause=${root.policyWantsPause} `
            + `onBattery=${root.onBattery} powerSaver=${root.powerSaverActive} gameMode=${root.gameModePolicyActive} available=${root.available}`);
        root.applyPolicy();
    }
}
