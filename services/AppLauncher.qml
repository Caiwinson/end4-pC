pragma Singleton

import Quickshell

Singleton {
    // Accepts a DesktopEntry or a DesktopAction. Launches it in its own
    // systemd scope so it survives a quickshell.service restart.
    function launch(entry) {
        const cmd = entry?.command;
        if (!cmd || cmd.length === 0) {
            entry?.execute();   // fallback, shouldn't normally happen
            return;
        }
        Quickshell.execDetached([
            "systemd-run", "--user", "--scope", "--collect",
            "--slice=app.slice",
            ...cmd
        ]);
    }
}
