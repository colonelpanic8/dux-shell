import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.DCommon.Common as DCommon
import qs.DCommon.Widgets
import qs.Widgets

BasePill {
    id: root

    readonly property var activeInhibitors: IdleService.activeInhibitors
    readonly property bool inhibited: activeInhibitors.length > 0
    readonly property var iconInhibitors: activeInhibitors.filter(i => i.appId)
    readonly property int maxPillIcons: 3
    readonly property string inhibitorSummary: activeInhibitors.map(i => {
        const detail = inhibitorDetail(i);
        return detail ? inhibitorName(i) + " — " + detail : inhibitorName(i);
    }).join("\n")

    function inhibitorName(i) {
        switch (i.kind) {
        case "manual":
            return I18n.tr("Idle inhibitor");
        case "compositor":
            return I18n.tr("Unknown");
        default:
            return Paths.getAppName(i.appId, DesktopEntries.heuristicLookup(Paths.moddedAppId(i.appId))) || i.name;
        }
    }

    function inhibitorDetail(i) {
        const parts = [];
        if (i.title)
            parts.push(i.title);
        if (i.workspace)
            parts.push(I18n.tr("Workspace %1", "idle inhibitor menu: workspace of the inhibiting window").arg(i.workspace));
        if (i.reason && i.reason !== i.title)
            parts.push(i.reason);
        return parts.join(" · ");
    }

    function inhibitorIcon(i) {
        return i.appId ? Paths.getAppIcon(i.appId, DesktopEntries.heuristicLookup(Paths.moddedAppId(i.appId))) : "";
    }

    readonly property var nextAction: IdleService.nextIdleAction
    readonly property double idleSince: IdleService.idleSince
    property double now: Date.now()

    readonly property int remaining: {
        if (!nextAction)
            return 0;
        const elapsed = idleSince > 0 ? Math.floor((now - idleSince) / 1000) : 0;
        return Math.max(0, nextAction.timeout - elapsed);
    }

    readonly property string iconName: {
        if (inhibited)
            return "local_cafe";
        switch (nextAction?.action) {
        case "lock":
            return "lock_clock";
        case "suspend":
            return "bedtime";
        default:
            return "desktop_access_disabled";
        }
    }

    readonly property string remainingText: inhibited ? "--" : formatRemaining(remaining)
    // Sized for the longest configured timeout on either power source so the pill never resizes.
    readonly property string reserveText: formatRemaining(Math.max(SettingsData.acMonitorTimeout, SettingsData.acLockTimeout, SettingsData.acSuspendTimeout, SettingsData.acPostLockMonitorTimeout, SettingsData.batteryMonitorTimeout, SettingsData.batteryLockTimeout, SettingsData.batterySuspendTimeout, SettingsData.batteryPostLockMonitorTimeout))

    readonly property real textPixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)

    // Every digit gets a cell as wide as the font's widest digit, and the text is
    // right-aligned in the space the longest timeout needs, so ticking never moves it.
    component CountdownLabel: Item {
        id: label

        StyledText {
            id: probe
            visible: false
            text: "0"
            font.pixelSize: root.textPixelSize
        }

        readonly property real digitWidth: Math.ceil(DCommon.Fonts.textWidth(probe.font, DCommon.Fonts.widestDigit(probe.font)))

        function cellWidth(ch) {
            return /\d/.test(ch) ? digitWidth : Math.ceil(DCommon.Fonts.textWidth(probe.font, ch));
        }

        function textWidth(str) {
            let w = 0;
            for (const ch of str)
                w += cellWidth(ch);
            return w;
        }

        implicitWidth: Math.max(textWidth(root.reserveText), textWidth(root.remainingText))
        implicitHeight: probe.implicitHeight

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: root.remainingText.split("")

                StyledText {
                    required property string modelData

                    text: modelData
                    width: label.cellWidth(modelData)
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: root.textPixelSize
                    color: root.contentColor
                }
            }
        }
    }

    function formatRemaining(seconds) {
        const h = Math.floor(seconds / 3600);
        const m = Math.floor(seconds % 3600 / 60);
        const s = String(seconds % 60).padStart(2, "0");
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + s : m + ":" + s;
    }

    visible: IdleService.enabled && (inhibited || !!nextAction)

    onIdleSinceChanged: now = Date.now()

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: DTooltip {}
    }

    function showInhibitorTooltip() {
        if (!root.inhibited || !root.inhibitorSummary || !root.parentScreen || inhibitorMenu.openState)
            return;
        tooltipLoader.active = true;
        const anchor = root.contextMenuAnchor();
        tooltipLoader.item.show(root.inhibitorSummary, anchor.x, anchor.y, anchor.screen, anchor.isVertical && anchor.edge === "left", anchor.isVertical && anchor.edge === "right");
    }

    function hideInhibitorTooltip() {
        tooltipLoader.item?.hide();
        tooltipLoader.active = false;
    }

    onIsMouseHoveredChanged: isMouseHovered ? showInhibitorTooltip() : hideInhibitorTooltip()

    function openInhibitorMenu() {
        hideInhibitorTooltip();
        inhibitorMenu.openFromBar(root.contextMenuAnchor());
    }

    DContextMenu {
        id: inhibitorMenu

        layerNamespace: "dms:idle-inhibitor-menu"
        customContentWidth: Theme.fieldDefaultWidth * 1.5
        customContent: Component {
            Column {
                width: inhibitorMenu.customContentWidth
                spacing: Theme.groupedListGap

                Repeater {
                    // The manual row is always offered so the menu can also turn keep-awake on.
                    model: [
                        {
                            "key": "manual",
                            "kind": "manual",
                            "active": SessionService.idleInhibited,
                            "canIgnore": true,
                            "ignoredByConfig": false
                        }
                    ].concat(IdleService.inhibitors.filter(i => i.kind !== "manual"))

                    Rectangle {
                        id: inhibitorRow
                        required property var modelData
                        readonly property bool focusable: !!modelData.address

                        width: parent.width
                        height: Math.max(DCommon.Style.menuRowHeight, rowContent.implicitHeight + Theme.spacingS * 2)
                        radius: Theme.cornerRadiusM
                        color: focusable && rowMouse.containsMouse ? Theme.withAlpha(Theme.onSurface, Theme.stateLayerHover) : "transparent"

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: inhibitorRow.focusable
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                CompositorService.focusWindow(inhibitorRow.modelData.address);
                                inhibitorMenu.hide();
                            }
                        }

                        Row {
                            id: rowContent
                            anchors.left: parent.left
                            anchors.right: rowToggle.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.rightMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingM

                            Item {
                                width: DCommon.Style.menuItemIconSize
                                height: width
                                anchors.verticalCenter: parent.verticalCenter

                                IconImage {
                                    id: rowAppIcon
                                    anchors.fill: parent
                                    source: root.inhibitorIcon(inhibitorRow.modelData)
                                    asynchronous: true
                                    visible: status === Image.Ready
                                }

                                DIcon {
                                    anchors.centerIn: parent
                                    visible: !rowAppIcon.visible
                                    size: parent.width
                                    name: inhibitorRow.modelData.kind === "manual" ? "local_cafe" : inhibitorRow.modelData.kind === "compositor" ? "help" : "desktop_windows"
                                    color: Theme.onSurfaceVariant
                                }
                            }

                            Column {
                                width: rowContent.width - DCommon.Style.menuItemIconSize - rowContent.spacing
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    width: parent.width
                                    text: root.inhibitorName(inhibitorRow.modelData)
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Theme.fontWeight
                                    color: inhibitorRow.modelData.active ? Theme.onSurface : Theme.onSurfaceVariant
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    width: parent.width
                                    visible: text !== ""
                                    text: root.inhibitorDetail(inhibitorRow.modelData)
                                    font.pixelSize: Theme.fontSizeXSmall
                                    color: Theme.onSurfaceVariant
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        DToggle {
                            id: rowToggle
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            hideText: true
                            checked: inhibitorRow.modelData.active
                            enabled: inhibitorRow.modelData.canIgnore && !inhibitorRow.modelData.ignoredByConfig
                            onToggled: checked => {
                                if (inhibitorRow.modelData.kind === "manual")
                                    checked ? SessionService.enableIdleInhibit() : SessionService.disableIdleInhibit();
                                else
                                    IdleService.setInhibitorIgnored(inhibitorRow.modelData.key, !checked);
                            }
                        }
                    }
                }
            }
        }

        onOpenStateChanged: {
            const screenName = root.parentScreen?.name;
            if (!screenName)
                return;
            if (openState)
                TrayMenuManager.registerMenu(screenName, inhibitorMenu.contextWindow);
            else
                TrayMenuManager.unregisterMenu(screenName);
        }
        Component.onDestruction: {
            if (openState && root.parentScreen?.name)
                TrayMenuManager.unregisterMenu(root.parentScreen.name);
        }
    }
    onInhibitedChanged: {
        if (!inhibited)
            hideInhibitorTooltip();
    }

    Component.onCompleted: IdleService.addCountdownRef()
    Component.onDestruction: IdleService.removeCountdownRef()

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && !root.inhibited && root.idleSince > 0 && !!root.nextAction
        onTriggered: root.now = Date.now()
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? root.contentThickness : row.implicitWidth
            implicitHeight: root.isVerticalOrientation ? column.implicitHeight : root.contentThickness

            Column {
                id: column
                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 1

                DIcon {
                    name: root.iconName
                    size: Theme.barIconSize(root.barThickness, -6, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: root.inhibited ? Theme.primary : Theme.widgetIconColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                CountdownLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Row {
                id: row
                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DIcon {
                    name: root.iconName
                    size: Theme.barIconSize(root.barThickness, -6, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: root.inhibited ? Theme.primary : Theme.widgetIconColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                CountdownLabel {
                    visible: root.iconInhibitors.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                }

                Repeater {
                    model: root.iconInhibitors.slice(0, root.maxPillIcons)

                    IconImage {
                        required property var modelData
                        implicitSize: Theme.barIconSize(root.barThickness, -6, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                        source: root.inhibitorIcon(modelData)
                        asynchronous: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StyledText {
                    visible: root.iconInhibitors.length > root.maxPillIcons
                    text: "+" + (root.iconInhibitors.length - root.maxPillIcons)
                    font.pixelSize: root.textPixelSize
                    color: root.contentColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    onClicked: openInhibitorMenu()
    onRightClicked: openInhibitorMenu()
}
