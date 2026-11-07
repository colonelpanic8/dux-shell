import QtQuick
import qs.Common
import qs.Services
import qs.Modules.Settings.Widgets

Item {
    id: root

    property var parentModal: null
    readonly property bool autoHides: (dock.config?.autoHide ?? false) || (dock.config?.smartAutoHide ?? false)

    DockSelectionState {
        id: dock
    }

    SettingsPage {
        SettingsCard {
            width: parent.width
            visible: dock.hasConfig
            iconName: "display_settings"
            title: I18n.tr("Displays")
            settingKey: "dockDisplays"
            tags: ["dock", "display", "monitor", "screen"]

            SettingsDisplayPicker {
                displayPreferences: dock.screenPreferences
                emptyMeansAll: false
                preferencesHandler: preferences => dock.setOption("screenPreferences", preferences)
            }

            SettingsToggleRow {
                text: I18n.tr("Show on last display")
                checked: dock.config?.showOnLastDisplay ?? true
                onToggled: checked => dock.setOption("showOnLastDisplay", checked)
            }
        }

        SettingsCard {
            width: parent.width
            visible: dock.hasConfig
            iconName: "view_compact"
            title: I18n.tr("Layout")
            settingKey: "dockLayout"
            tags: ["dock", "layout", "compact", "taskbar", "alignment"]

            SettingsButtonGroupRow {
                resetStore: dock
                resetKeys: ["mode"]
                text: I18n.tr("Style")
                model: [I18n.tr("Compact", "adjective, dock style option, also notification compact mode toggle"), I18n.tr("Taskbar", "dock style option, alternative to compact")]
                currentIndex: dock.config?.mode === "taskbar" ? 1 : 0
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    dock.setOption("mode", index === 1 ? "taskbar" : "compact");
                }
            }

            SettingsButtonGroupRow {
                resetStore: dock
                resetKeys: ["align"]
                readonly property var alignments: ["start", "center", "end"]

                text: I18n.tr("Alignment", "row label, where taskbar dock items align")
                model: dock.isVertical ? [I18n.tr("Top"), I18n.tr("Center", "noun, taskbar dock alignment option between start and end"), I18n.tr("Bottom")] : [I18n.tr("Left"), I18n.tr("Center"), I18n.tr("Right")]
                currentIndex: Math.max(0, alignments.indexOf(dock.config?.align ?? "center"))
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    dock.setOption("align", alignments[index]);
                }
            }

            SettingsSliderRow {
                settingKey: "dockAlignOffset"
                tags: ["dock", "alignment", "offset", "corner", "position"]
                resetStore: dock
                resetKeys: ["alignOffset"]
                text: I18n.tr("Offset", "dock settings: distance from the aligned screen end")
                visible: dock.config?.mode !== "taskbar" && dock.config?.align !== "center"
                unit: "px"
                minimum: 0
                maximum: 1000
                value: dock.config?.alignOffset ?? 0
                onSliderDragFinished: finalValue => dock.setOption("alignOffset", finalValue)
            }
        }

        SettingsCard {
            width: parent.width
            visible: dock.hasConfig && dock.config.enabled
            iconName: "visibility_off"
            title: I18n.tr("Visibility")
            settingKey: "dockAutoHideCard"
            tags: ["dock", "autohide", "hide", "hover"]

            SettingsToggleRow {
                settingKey: "dockAutoHide"
                tags: ["dock", "autohide", "hide", "hover"]
                text: I18n.tr("Auto-hide")
                checked: dock.config?.autoHide ?? false
                onToggled: checked => {
                    if (checked && dock.config.smartAutoHide)
                        dock.setOption("smartAutoHide", false);
                    dock.setOption("autoHide", checked);
                }
            }

            SettingsToggleRow {
                settingKey: "dockSmartAutoHide"
                tags: ["dock", "smart", "autohide", "windows", "overlap", "intelligent", "floating"]
                text: I18n.tr("Smart auto-hide")
                description: I18n.tr("Hides only while a window overlaps the dock", "dock smart auto-hide toggle description")
                visible: CompositorService.supportsSmartDock
                checked: dock.config?.smartAutoHide ?? false
                onToggled: checked => {
                    if (checked && dock.config.autoHide)
                        dock.setOption("autoHide", false);
                    dock.setOption("smartAutoHide", checked);
                }
            }

            SettingsButtonGroupRow {
                settingKey: "dockAutoHideStyle"
                tags: ["dock", "autohide", "peek", "slide", "collapse", "corner", "tray"]
                resetStore: dock
                resetKeys: ["autoHideStyle"]
                text: I18n.tr("Hide style", "dock settings: whether an auto-hidden dock slides away or stays collapsed")
                description: dock.config?.autoHideStyle === "peek" ? I18n.tr("Stays on screen showing only widgets marked to show when collapsed", "dock peek hide style description") : ""
                visible: root.autoHides
                model: [I18n.tr("Slide", "dock hide style: slides off screen"), I18n.tr("Peek", "dock hide style: stays on screen collapsed")]
                values: ["slide", "peek"]
                value: dock.config?.autoHideStyle ?? "slide"
                onValueSelected: value => dock.setOption("autoHideStyle", value)
            }

            SettingsButtonGroupRow {
                settingKey: "dockPeekExpandOn"
                tags: ["dock", "peek", "expand", "arrow", "hover", "click", "tray"]
                resetStore: dock
                resetKeys: ["peekExpandOn"]
                text: I18n.tr("Expand on", "dock settings: what expands a collapsed peek dock")
                visible: root.autoHides && dock.config?.autoHideStyle === "peek"
                model: [I18n.tr("Arrow hover", "dock peek expand trigger: pointer over the expand arrow"), I18n.tr("Arrow click", "dock peek expand trigger: clicking the expand arrow"), I18n.tr("Dock hover", "dock peek expand trigger: pointer anywhere over the dock")]
                values: ["arrowHover", "arrowClick", "dockHover"]
                value: dock.config?.peekExpandOn ?? "arrowHover"
                onValueSelected: value => dock.setOption("peekExpandOn", value)
            }

            SettingsSliderRow {
                settingKey: "dockPeekOpacity"
                tags: ["dock", "peek", "opacity", "collapsed", "transparency"]
                resetStore: dock
                resetKeys: ["peekOpacity"]
                text: I18n.tr("Opacity")
                visible: root.autoHides && dock.config?.autoHideStyle === "peek"
                unit: "%"
                minimum: 0
                maximum: 100
                value: Math.round((dock.config?.peekOpacity ?? 1) * 100)
                onSliderDragFinished: finalValue => dock.setOption("peekOpacity", finalValue / 100)
            }

            SettingsSliderRow {
                settingKey: "dockRevealDelay"
                tags: ["dock", "autohide", "reveal", "delay", "hover"]
                resetStore: dock
                resetKeys: ["revealDelay"]
                text: I18n.tr("Open delay")
                visible: root.autoHides
                unit: "ms"
                minimum: 0
                maximum: 2000
                step: 50
                value: dock.config?.revealDelay ?? 0
                onSliderDragFinished: finalValue => dock.setOption("revealDelay", finalValue)
            }

            SettingsSliderRow {
                settingKey: "dockHideDelay"
                tags: ["dock", "autohide", "hide", "delay"]
                resetStore: dock
                resetKeys: ["hideDelay"]
                text: I18n.tr("Hide delay")
                visible: root.autoHides
                unit: "ms"
                minimum: 0
                maximum: 5000
                step: 50
                value: dock.config?.hideDelay ?? 250
                onSliderDragFinished: finalValue => dock.setOption("hideDelay", finalValue)
            }
        }

        SettingsCard {
            width: parent.width
            visible: dock.hasConfig
            iconName: "mouse"
            title: I18n.tr("Mouse behavior", "dock mouse settings card title")
            settingKey: "dockMouseBehavior"
            tags: ["dock", "mouse", "middle-click", "close", "launch", "instance"]

            SettingsButtonGroupRow {
                settingKey: "dockMiddleClickAction"
                tags: ["dock", "middle-click", "close", "launch", "instance"]
                resetStore: dock
                resetKeys: ["middleClickAction"]
                text: I18n.tr("Middle-click action", "dock middle-click behavior setting")
                values: ["close", "launch"]
                model: [I18n.tr("Close Window", "dock middle-click action option"), I18n.tr("Launch new instance", "dock middle-click action option")]
                value: dock.config?.middleClickAction ?? "close"
                fallbackValue: "close"
                onValueSelected: value => dock.setOption("middleClickAction", value)
            }
        }

        SettingsCard {
            width: parent.width
            visible: dock.hasConfig && dock.config.enabled
            iconName: "edit"
            title: I18n.tr("Edit mode")
            settingKey: "dockEditMode"
            tags: ["dock", "edit", "widgets", "right-click"]

            SettingsToggleRow {
                settingKey: "dockEditOnRightClick"
                tags: ["dock", "edit", "right-click", "context"]
                text: I18n.tr("Right-click empty space to edit")
                checked: dock.config?.editOnRightClick ?? false
                onToggled: checked => dock.setOption("editOnRightClick", checked)
            }
        }
    }
}
