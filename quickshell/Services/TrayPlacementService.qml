pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import "../Common/TrayPlacement.js" as TrayPlacement

Singleton {
    id: root

    readonly property string placement: TrayPlacement.normalize(SessionData.systemTrayPlacement, SettingsData.systemTrayDefaultPlacement)
    readonly property bool collapseEnabled: TrayPlacement.sessionSwitch(SessionData.trayCollapseEnabled, SettingsData.trayCollapseDefault)
    // Otherwise only clicking the collapsed tray's arrow expands it.
    readonly property bool expandOnHover: TrayPlacement.sessionSwitch(SessionData.trayExpandOnHover, SettingsData.trayExpandOnHoverDefault)
    readonly property var pinnedKeys: TrayPlacement.pins(SessionData.trayPinnedItems)
    // Keyed by screen and bar, so bars sharing a screen never overwrite each other.
    property var routedBars: ({})

    function isTray(entry) {
        if (typeof entry === "string")
            return entry === "systemTray";
        return (entry?.widgetId ?? entry?.id) === "systemTray" && entry.enabled !== false;
    }

    function barHasTray(bar) {
        return ["leftWidgets", "centerWidgets", "rightWidgets"].some(key => (bar[key] ?? []).some(isTray));
    }

    function forScreen(screenName) {
        const screen = ShellLayout.screenForName(screenName);
        const prefix = screenName + "\n";
        return TrayPlacement.resolve({
            placement: root.placement,
            barTray: !!screen && SettingsData.barConfigs.some(bar => bar.enabled !== false && barHasTray(bar) && ShellLayout.coversScreen(bar, screen)),
            dockTray: !!screen && SettingsData.dockConfigsForScreen(screen).some(dock => dock.enabled && dock.widgets.some(isTray)),
            overflowToDock: SettingsData.trayOverflowToDock,
            barOverflowed: Object.keys(root.routedBars).some(key => key.startsWith(prefix))
        });
    }

    function setPlacement(value) {
        if (!TrayPlacement.PLACEMENTS.includes(value))
            return false;
        SessionData.set("systemTrayPlacement", value);
        return true;
    }

    function togglePlacement() {
        setPlacement(TrayPlacement.flipped(root.placement));
        return root.placement;
    }

    function setCollapseEnabled(enabled) {
        SessionData.set("trayCollapseEnabled", enabled === true);
    }

    function toggleCollapse() {
        setCollapseEnabled(!root.collapseEnabled);
        return root.collapseEnabled;
    }

    function setExpandOnHover(enabled) {
        SessionData.set("trayExpandOnHover", enabled === true);
    }

    function toggleExpandOnHover() {
        setExpandOnHover(!root.expandOnHover);
        return root.expandOnHover;
    }

    function setPinned(key, pinned) {
        if (!key)
            return false;
        SessionData.set("trayPinnedItems", TrayPlacement.withPin(SessionData.trayPinnedItems, key, pinned));
        return true;
    }

    function togglePin(key) {
        if (!key)
            return false;
        SessionData.set("trayPinnedItems", TrayPlacement.withPinToggled(SessionData.trayPinnedItems, key));
        return true;
    }

    function setBarRouted(screenName, barId, routed) {
        const key = screenName + "\n" + barId;
        if (!!root.routedBars[key] === routed)
            return;
        const next = Object.assign({}, root.routedBars);
        if (routed)
            next[key] = true;
        else
            delete next[key];
        root.routedBars = next;
    }
}
