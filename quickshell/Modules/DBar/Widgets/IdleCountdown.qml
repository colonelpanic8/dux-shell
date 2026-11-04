import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets
import qs.Widgets

BasePill {
    id: root

    readonly property bool inhibited: SessionService.idleInhibited || IdleService.externalInhibitActive || IdleService.windowInhibitActive
    readonly property var inhibitors: {
        const list = [];
        if (SessionService.idleInhibited)
            list.push({
                "name": I18n.tr("Idle inhibitor"),
                "detail": ""
            });
        for (const i of DMSService.screensaverInhibitors)
            list.push({
                "name": i.appName,
                "detail": i.reason || ""
            });
        for (const w of IdleService.activeInhibitingWindows)
            list.push({
                "name": Paths.getAppName(w.appId, DesktopEntries.heuristicLookup(Paths.moddedAppId(w.appId))),
                "detail": w.title
            });
        if (list.length === 0 && IdleService.windowInhibitActive)
            list.push({
                "name": I18n.tr("Unknown"),
                "detail": ""
            });
        return list;
    }
    readonly property string inhibitorLabel: inhibitors.length === 0 ? "--" : inhibitors[0].name + (inhibitors.length > 1 ? " +" + (inhibitors.length - 1) : "")
    readonly property string inhibitorSummary: inhibitors.map(i => i.detail && i.detail !== i.name ? i.name + " — " + i.detail : i.name).join("\n")
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

        readonly property real digitWidth: Math.ceil(Fonts.textWidth(probe.font, Fonts.widestDigit(probe.font)))

        function cellWidth(ch) {
            return /\d/.test(ch) ? digitWidth : Math.ceil(Fonts.textWidth(probe.font, ch));
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
        if (!root.inhibited || !root.inhibitorSummary || !root.parentScreen)
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
                    visible: !root.inhibited
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    visible: root.inhibited
                    text: root.inhibitorLabel
                    width: Math.min(implicitWidth, root.barThickness * 4)
                    elide: Text.ElideRight
                    font.pixelSize: root.textPixelSize
                    color: root.contentColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    onClicked: {
        hideInhibitorTooltip();
        SessionService.toggleIdleInhibit();
    }
}
