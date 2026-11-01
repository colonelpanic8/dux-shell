import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Settings.Widgets
import qs.Widgets

Column {
    id: root

    property var page: null

    readonly property bool inlineExpansion: page.value("trayUseInlineExpansion")
    readonly property bool autoOverflow: page.value("trayAutoOverflow")
    readonly property bool trayTinted: ["primary", "secondary"].includes(SettingsData.systemTrayIconTintMode || "none")
    readonly property var clickActions: ["activate", "secondaryActivate", "menu", "none"]
    readonly property var clickActionLabels: [I18n.tr("Activate"), I18n.tr("Secondary action"), I18n.tr("Menu"), I18n.tr("Nothing")]
    readonly property var clickButtons: [
        {
            "name": "left",
            "key": "systemTrayLeftClickAction",
            "label": I18n.tr("Left click")
        },
        {
            "name": "middle",
            "key": "systemTrayMiddleClickAction",
            "label": I18n.tr("Middle click")
        },
        {
            "name": "right",
            "key": "systemTrayRightClickAction",
            "label": I18n.tr("Right click")
        }
    ]
    // Running items plus overridden ones that are not running, so stale overrides stay clearable.
    readonly property var clickOverrideItems: {
        const overrides = SettingsData.systemTrayItemClickActions || {};
        const seen = new Set();
        const rows = [];
        for (const item of SystemTray.items.values) {
            const id = item?.id || "";
            if (!id || seen.has(id))
                continue;
            seen.add(id);
            rows.push({
                "id": id,
                "title": item.tooltipTitle || item.title || id,
                "icon": TrayMenuManager.iconSourceFor(item)
            });
        }
        for (const id of Object.keys(overrides)) {
            if (!seen.has(id))
                rows.push({
                    "id": id,
                    "title": id,
                    "icon": ""
                });
        }
        return rows;
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
        settingKey: "trayClickActions"
        tags: ["tray", "click", "menu", "activate", "mouse", "system tray"]
        iconName: "mouse"
        title: I18n.tr("Click actions")

        Repeater {
            model: root.clickButtons

            delegate: SettingsDropdownRow {
                required property var modelData

                text: modelData.label
                resetKeys: [modelData.key]
                options: root.clickActionLabels
                optionValues: root.clickActions
                currentValue: SettingsData[modelData.key]
                onValueChanged: value => SettingsData.set(modelData.key, value)
            }
        }

        Repeater {
            model: root.clickOverrideItems

            delegate: SettingsRow {
                id: overrideRow
                required property var modelData
                readonly property var overrides: (SettingsData.systemTrayItemClickActions || {})[modelData.id] || {}

                title: modelData.title
                subtitle: modelData.title === modelData.id ? "" : modelData.id
                leading: IconImage {
                    visible: overrideRow.modelData.icon !== ""
                    source: overrideRow.modelData.icon
                    implicitSize: Theme.iconSize
                }
                body: Flow {
                    width: parent.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: root.clickButtons

                        delegate: DDropdown {
                            required property var modelData

                            text: modelData.label
                            dropdownWidth: 160
                            backgroundColor: SettingsMetrics.controlSurface
                            options: [I18n.tr("Default")].concat(root.clickActionLabels)
                            optionValues: ["default"].concat(root.clickActions)
                            currentValue: overrideRow.overrides[modelData.name] || "default"
                            onValueChanged: value => TrayMenuManager.setItemClickAction(overrideRow.modelData.id, modelData.name, value)
                        }
                    }
                }
            }
        }
    }
}
