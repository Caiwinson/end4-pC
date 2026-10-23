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

    // Local branch that holds your own commits (rebased onto upstream on every update)
    readonly property string tweakBranch: "my-tweaks"

    function runUpdateDots() {
        const updateScript = `
            set -e
            DIR="$HOME/.config/quickshell/end4-pC"
            BRANCH="${root.tweakBranch}"

            # Not a git clone yet? Fresh clone, nothing to preserve.
            if [ ! -d "$DIR/.git" ]; then
                rm -rf "$DIR"
                git clone https://github.com/pctrade/end4-pC.git "$DIR"
                cd "$DIR"
                git checkout -b "$BRANCH"
            else
                cd "$DIR"
                git fetch origin

                # Make sure we are on the tweak branch
                git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH"

                # Replay your commits on top of the latest upstream main
                if ! git rebase --autostash origin/main; then
                    git rebase --abort || true
                    echo
                    echo "Update stopped: your tweaks conflict with upstream changes."
                    echo "Your files are untouched. Resolve manually in $DIR with:"
                    echo "  git rebase origin/main"
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
