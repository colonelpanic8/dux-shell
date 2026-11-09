import QtQuick
import QtTest
import "../../Common/settings/DockConfig.js" as DockConfig

TestCase {
    name: "DockEdgeSlots"

    function dock(id, align) {
        return Object.assign(DockConfig.create(id, id), {
            "enabled": true,
            "autoHide": true,
            "align": align
        });
    }

    function test_cornerDocksShareTheBottomEdge() {
        const screen = {
            "name": "DP-1"
        };
        const resolved = DockConfig.resolveAll([dock("tray", "end"), dock("minimized", "start")], screen, [screen]);
        compare(resolved.map(config => config.id).join(","), "tray,minimized");
    }
}
