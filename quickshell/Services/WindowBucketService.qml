pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import "../Common/WindowBuckets.js" as WindowBuckets

Singleton {
    id: root

    readonly property string placement: WindowBuckets.placement(SessionData.windowBucketPlacement, SettingsData.windowBucketPlacement)

    function _barShowsBuckets(entry) {
        if (typeof entry === "string")
            return entry === "workspaceSwitcher" && SettingsData.widgetOption("workspaceSwitcher", null, "showSpecialWorkspaces");
        return (entry?.id ?? entry?.widgetId) === "workspaceSwitcher" && entry.enabled !== false && SettingsData.widgetOption("workspaceSwitcher", entry, "showSpecialWorkspaces");
    }

    function hostedIn(surface, screenName) {
        const screen = ShellLayout.screenForName(screenName);
        if (!screen)
            return [];
        const inBar = SettingsData.barConfigs.some(bar => bar.enabled !== false && ShellLayout.coversScreen(bar, screen) && ["leftWidgets", "centerWidgets", "rightWidgets"].some(key => (bar[key] ?? []).some(_barShowsBuckets)));
        const inDock = SettingsData.dockConfigsForScreen(screen).some(dock => dock.enabled && dock.widgets.some(widget => widget.widgetId === "windowBuckets" && widget.enabled !== false));
        return WindowBuckets.host(root.placement, inBar, inDock) === surface ? WindowBuckets.BUCKETS : [];
    }

    function move() {
        SessionData.set("windowBucketPlacement", WindowBuckets.flipped(root.placement));
    }
}
