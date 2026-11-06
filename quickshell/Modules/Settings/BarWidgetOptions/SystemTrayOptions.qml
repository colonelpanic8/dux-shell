pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.SystemTray
import qs.Common
import qs.Modules.Settings.Widgets

Column {
    id: root

    property var page: null

    readonly property bool inlineExpansion: page.value("trayUseInlineExpansion")
    readonly property bool autoOverflow: page.value("trayAutoOverflow")
    readonly property bool trayTinted: ["primary", "secondary"].includes(SettingsData.systemTrayIconTintMode || "none")
    readonly property var pinnedKeys: root.page.value("trayPinnedItems") ?? []
    // Live items in tray order, then pinned keys whose app is not running so they can still be unpinned.
    // Items without an id have no key, so they cannot be pinned.
    readonly property var pinRows: {
        const live = TrayMenuManager.filterEnvHidden(SystemTray.items.values);
        const rows = TrayMenuManager.sortByPreferredOrder(live, SessionData.trayItemOrder).map(item => ({
                    key: TrayMenuManager.getTrayItemKey(item, live),
                    title: item.tooltipTitle || item.title || item.id
                }));
        const keys = rows.map(row => row.key);
        return rows.concat(pinnedKeys.filter(key => !keys.includes(key)).map(key => ({
                    key,
                    title: key
                }))).filter(row => row.key !== "");
    }

    width: parent?.width ?? 0
    spacing: Theme.spacingL

    SettingsCard {
        settingKey: "barWidgetTray"

        SettingsToggleRow {
            text: I18n.tr("Use inline expansion")
            description: I18n.tr("Hidden icons expand in place instead of in a popup", "system tray inline expansion toggle description")
            checked: root.inlineExpansion
            onToggled: checked => root.page.set("trayUseInlineExpansion", checked)
        }

        SettingsToggleRow {
            text: I18n.tr("Single-line popup")
            enabled: !root.inlineExpansion
            checked: root.page.value("trayPopupSingleLine")
            onToggled: checked => root.page.set("trayPopupSingleLine", checked)
        }

        SettingsToggleRow {
            text: I18n.tr("Auto overflow")
            checked: root.autoOverflow
            onToggled: checked => root.page.set("trayAutoOverflow", checked)
        }

        SettingsSliderRow {
            resetStore: root.page
            resetKeys: ["trayMaxVisibleItems"]
            text: I18n.tr("Max visible")
            unit: ""
            minimumLabel: I18n.tr("Auto")
            enabled: root.autoOverflow
            value: root.page.value("trayMaxVisibleItems")
            minimum: 0
            maximum: 20
            onSliderValueChanged: newValue => root.page.set("trayMaxVisibleItems", newValue)
        }

        SettingsSliderRow {
            resetStore: root.page
            resetKeys: ["trayIconSpacing"]
            text: I18n.tr("Icon spacing")
            value: root.page.value("trayIconSpacing")
            minimum: 0
            maximum: 20
            unit: "px"
            onSliderValueChanged: newValue => root.page.set("trayIconSpacing", newValue)
        }

        SettingsButtonGroupRow {
            readonly property var modes: ["none", "monochrome", "primary", "secondary"]

            settingKey: "trayIconTint"
            tags: ["tray", "icon", "tint", "monochrome", "system tray", "color"]
            text: I18n.tr("Tray icon tint")
            resetKeys: ["systemTrayIconTintMode"]
            model: [I18n.tr("None"), I18n.tr("Monochrome"), I18n.tr("Primary"), I18n.tr("Secondary")]
            currentIndex: Math.max(0, modes.indexOf(SettingsData.systemTrayIconTintMode || "none"))
            onSelectionChanged: (index, selected) => {
                if (!selected)
                    return;
                SettingsData.set("systemTrayIconTintMode", modes[index]);
            }
        }

        SettingsSliderRow {
            text: I18n.tr("Tint saturation")
            tags: ["tray", "tint", "saturation"]
            visible: root.trayTinted
            resetKeys: ["systemTrayIconTintSaturation"]
            value: SettingsData.systemTrayIconTintSaturation ?? 50
            minimum: 0
            maximum: 100
            onSliderDragFinished: finalValue => SettingsData.set("systemTrayIconTintSaturation", finalValue)
        }

        SettingsSliderRow {
            text: I18n.tr("Tint strength")
            tags: ["tray", "tint", "strength"]
            visible: root.trayTinted
            resetKeys: ["systemTrayIconTintStrength"]
            value: SettingsData.systemTrayIconTintStrength ?? 135
            minimum: 0
            maximum: 200
            onSliderDragFinished: finalValue => SettingsData.set("systemTrayIconTintStrength", finalValue)
        }
    }

    SettingsCard {
        settingKey: "barWidgetTrayPinned"
        tags: ["tray", "pin", "pinned", "collapsed", "peek", "dock"]
        title: I18n.tr("Show when collapsed", "dock widget toggle: keep this widget on a collapsed peek dock")
        iconName: "push_pin"
        visible: root.page.dockHosted && root.pinRows.length > 0

        SettingsSliderRow {
            resetStore: root.page
            resetKeys: ["trayCollapsedItemCount"]
            text: I18n.tr("Leading icons", "system tray: how many icons from the start of the tray stay on a collapsed peek dock")
            description: I18n.tr("Shown alongside the pinned icons below", "system tray: leading icons slider description on a collapsed peek dock")
            unit: ""
            value: root.page.value("trayCollapsedItemCount")
            minimum: 0
            maximum: 10
            onSliderValueChanged: newValue => root.page.set("trayCollapsedItemCount", newValue)
        }

        Repeater {
            model: root.pinRows

            delegate: SettingsToggleRow {
                id: pinRow
                required property var modelData

                text: pinRow.modelData.title
                description: pinRow.modelData.title === pinRow.modelData.key ? "" : pinRow.modelData.key
                checked: root.pinnedKeys.includes(pinRow.modelData.key)
                onToggled: checked => root.page.set("trayPinnedItems", checked ? root.pinnedKeys.concat([pinRow.modelData.key]) : root.pinnedKeys.filter(key => key !== pinRow.modelData.key))
            }
        }
    }
}
