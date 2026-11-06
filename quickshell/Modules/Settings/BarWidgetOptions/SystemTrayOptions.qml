pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.SystemTray
import qs.Common
import qs.Services
import qs.Modules.Settings.Widgets

Column {
    id: root

    property var page: null

    readonly property bool inlineExpansion: page.value("trayUseInlineExpansion")
    readonly property bool autoOverflow: page.value("trayAutoOverflow")
    readonly property bool trayTinted: ["primary", "secondary"].includes(SettingsData.systemTrayIconTintMode || "none")
    readonly property bool dockHosted: root.page?.dockHosted ?? false
    readonly property bool collapsesInBar: !root.dockHosted && root.page.value("trayCollapseInBar") === true
    // Live items in tray order, then pinned keys whose app is not running so they can still be unpinned.
    // Items without an id have no key, so they cannot be pinned.
    readonly property var pinRows: {
        const live = TrayMenuManager.filterEnvHidden(SystemTray.items.values);
        const rows = TrayMenuManager.sortByPreferredOrder(live, SessionData.trayItemOrder).map(item => ({
                    key: TrayMenuManager.getTrayItemKey(item, live),
                    title: item.tooltipTitle || item.title || item.id
                }));
        const keys = rows.map(row => row.key);
        return rows.concat(TrayPlacementService.pinnedKeys.filter(key => !keys.includes(key)).map(key => ({
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
        settingKey: "barWidgetTrayPlacement"
        tags: ["tray", "placement", "move", "dock", "corner", "bar", "overflow", "system tray"]
        title: I18n.tr("Placement", "system tray settings: where the tray is shown, the bar or a dock")
        iconName: "swap_vert"

        SettingsButtonGroupRow {
            settingKey: "trayPlacementCurrent"
            tags: ["tray", "placement", "move", "dock", "corner", "bar"]
            text: I18n.tr("Show the tray in", "system tray settings: current tray placement, the bar or a dock")
            description: I18n.tr("Remembered across restarts; the tray's options menu switches it too", "system tray settings: current placement description")
            model: [I18n.tr("Bar"), I18n.tr("Dock")]
            values: ["bar", "dock"]
            value: TrayPlacementService.placement
            onValueSelected: value => TrayPlacementService.setPlacement(value)
        }

        SettingsButtonGroupRow {
            settingKey: "systemTrayDefaultPlacement"
            tags: ["tray", "placement", "default", "dock", "bar"]
            text: I18n.tr("Default placement", "system tray settings: placement used until the tray is first moved")
            resetKeys: ["systemTrayDefaultPlacement"]
            model: [I18n.tr("Bar"), I18n.tr("Dock")]
            values: ["bar", "dock"]
            value: SettingsData.systemTrayDefaultPlacement
            onValueSelected: value => SettingsData.set("systemTrayDefaultPlacement", value)
        }

        SettingsToggleRow {
            settingKey: "systemTrayQuickMenu"
            tags: ["tray", "options", "menu", "button", "placement", "move", "collapse", "dock", "bar"]
            text: I18n.tr("Options button", "system tray settings: show a button on the tray that opens its quick options menu")
            description: I18n.tr("A button at the tray's inner end opens a menu to move the tray or stop it collapsing", "system tray settings: options button description")
            resetKeys: ["systemTrayQuickMenu"]
            checked: SettingsData.systemTrayQuickMenu
            onToggled: checked => SettingsData.set("systemTrayQuickMenu", checked)
        }

        SettingsToggleRow {
            settingKey: "trayOverflowToDock"
            tags: ["tray", "overflow", "dock", "corner", "bar", "full"]
            text: I18n.tr("Move to a dock when the bar is full", "system tray settings: route the tray to a dock while the bar overflows it")
            description: I18n.tr("The tray leaves the bar first and comes back when there is room", "system tray settings: overflow to dock description")
            resetKeys: ["trayOverflowToDock"]
            checked: SettingsData.trayOverflowToDock
            onToggled: checked => SettingsData.set("trayOverflowToDock", checked)
        }
    }

    SettingsCard {
        settingKey: "barWidgetTrayCollapse"
        tags: ["tray", "collapse", "bar", "arrow", "expand", "hover"]
        title: I18n.tr("Collapse", "system tray settings: card for collapsing the tray behind an expand arrow")
        iconName: "unfold_less"

        SettingsToggleRow {
            settingKey: "trayCollapseCurrent"
            tags: ["tray", "collapse", "automatically", "expanded", "peek", "dock", "bar"]
            text: I18n.tr("Collapse automatically", "tray options menu check item: whether the tray collapses to its pinned icons and an expand arrow")
            description: I18n.tr("Remembered across restarts; the tray's options menu switches it too", "system tray settings: current collapse state description")
            checked: TrayPlacementService.collapseEnabled
            onToggled: checked => TrayPlacementService.setCollapseEnabled(checked)
        }

        SettingsToggleRow {
            settingKey: "trayCollapseDefault"
            tags: ["tray", "collapse", "default", "peek", "dock", "bar"]
            text: I18n.tr("Collapse by default", "system tray settings: whether the tray collapses until it is switched from its options menu")
            resetKeys: ["trayCollapseDefault"]
            checked: SettingsData.trayCollapseDefault
            onToggled: checked => SettingsData.set("trayCollapseDefault", checked)
        }

        SettingsToggleRow {
            visible: !root.dockHosted
            text: I18n.tr("Collapse in bar", "system tray settings: collapse the bar's tray behind an expand arrow")
            description: I18n.tr("Keeps the leading and pinned icons; expanded, the tray draws over its neighbours", "system tray settings: collapse in bar description")
            checked: root.collapsesInBar
            onToggled: checked => root.page.set("trayCollapseInBar", checked)
        }

        SettingsButtonGroupRow {
            text: I18n.tr("Expand on", "dock settings: what expands a collapsed peek dock")
            visible: root.collapsesInBar
            model: [I18n.tr("Arrow hover", "dock peek expand trigger: pointer over the expand arrow"), I18n.tr("Arrow click", "dock peek expand trigger: clicking the expand arrow"), I18n.tr("Tray hover", "bar tray expand trigger: pointer anywhere over the tray")]
            values: ["arrowHover", "arrowClick", "trayHover"]
            value: root.page.value("trayExpandOn")
            onValueSelected: value => root.page.set("trayExpandOn", value)
        }
    }

    SettingsCard {
        settingKey: "barWidgetTrayPinned"
        tags: ["tray", "pin", "pinned", "collapsed", "peek", "dock"]
        title: I18n.tr("Show when collapsed", "dock widget toggle: keep this widget on a collapsed peek dock")
        iconName: "push_pin"
        visible: (root.dockHosted || root.collapsesInBar) && root.pinRows.length > 0

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

        SettingsNoteRow {
            noteIconName: "info"
            tint: Theme.surfaceVariantText
            tintBackground: Theme.surfaceVariantAlpha
            text: I18n.tr("Pins apply to the bar tray and every dock tray. A tray icon's menu pins it too.", "system tray settings: note above the pinned icon checklist")
        }

        Repeater {
            model: root.pinRows

            delegate: SettingsToggleRow {
                id: pinRow
                required property var modelData

                text: pinRow.modelData.title
                description: pinRow.modelData.title === pinRow.modelData.key ? "" : pinRow.modelData.key
                checked: TrayPlacementService.pinnedKeys.includes(pinRow.modelData.key)
                onToggled: checked => TrayPlacementService.setPinned(pinRow.modelData.key, checked)
            }
        }
    }
}
