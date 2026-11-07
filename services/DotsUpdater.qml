pragma Singleton

import qs
import QtQuick
import Quickshell

Singleton {
    id: root

    function runSystemUpdate() {
        Quickshell.execDetached([
            "kitty", "--hold",
            "fish", "-i", "-l", "-c",
            "if type -q yay; yay -Syu --combinedupgrade=false; else if type -q paru; paru -Syu; else; sudo pacman -Syu; end"
        ])
        Qt.callLater(() => GlobalStates.settingsOpen = false)
    }

    // Branch to track (your tweaks are now merged into main)
    readonly property string branch: "main"

    function runUpdateDots() {
        const updateScript = `
            set -e
            DIR="$HOME/.config/quickshell/end4-pC"
            BRANCH="${root.branch}"

            # Not a git clone yet? Fresh clone, nothing to preserve.
            if [ ! -d "$DIR/.git" ]; then
                rm -rf "$DIR"
                git clone https://github.com/Caiwinson/end4-pC.git "$DIR"
                cd "$DIR"
                git checkout "$BRANCH"
            else
                cd "$DIR"
                git fetch origin

                # Make sure we are on main
                git checkout "$BRANCH"

                # Fast-forward to the latest main, replaying any local commits on top
                if ! git pull --rebase --autostash origin "$BRANCH"; then
                    git rebase --abort || true
                    echo
                    echo "Update stopped: your local changes conflict with upstream changes."
                    echo "Your files are untouched. Resolve manually in $DIR with:"
                    echo "  git pull --rebase origin $BRANCH"
                    exit 1
                fi
            fi

            killall qs 2>/dev/null || true
            sleep 0.5
            setsid qs -c end4-pC >/tmp/qs.log 2>&1 < /dev/null &
            disown
        `

        Quickshell.execDetached(["kitty", "--hold", "bash", "-c", updateScript])
        Qt.callLater(() => GlobalStates.settingsOpen = false)
    }
}
