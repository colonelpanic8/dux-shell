pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import "../Common/WindowBuckets.js" as WindowBuckets

Singleton {
    id: root

    readonly property string placement: WindowBuckets.placement(SessionData.windowBucketPlacement, SettingsData.windowBucketPlacement)

    function _isWidget(entry) {
        if (typeof entry === "string")
            return entry === "hiddenWindows";
        return (entry?.widgetId ?? entry?.id) === "hiddenWindows" && entry.enabled !== false;
    }

    function forScreen(screenName) {
        const screen = ShellLayout.screenForName(screenName);
        if (!screen)
            return {
                "host": "none",
                "movable": false
            };
        const inBar = SettingsData.barConfigs.some(bar => bar.enabled !== false && ShellLayout.coversScreen(bar, screen) && ["leftWidgets", "centerWidgets", "rightWidgets"].some(key => (bar[key] ?? []).some(_isWidget)));
        const inDock = SettingsData.dockConfigsForScreen(screen).some(dock => dock.enabled && dock.widgets.some(_isWidget));
        return {
            "host": WindowBuckets.host(root.placement, inBar, inDock),
            "movable": inBar && inDock
        };
    }

    function move() {
        SessionData.set("windowBucketPlacement", WindowBuckets.flipped(root.placement));
    }
}
