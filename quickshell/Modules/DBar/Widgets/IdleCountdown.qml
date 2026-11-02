import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.DCommon.Widgets

BasePill {
    id: root

    readonly property bool inhibited: SessionService.idleInhibited || IdleService.externalInhibitActive
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

    function formatRemaining(seconds) {
        const h = Math.floor(seconds / 3600);
        const m = Math.floor(seconds % 3600 / 60);
        const s = String(seconds % 60).padStart(2, "0");
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + s : m + ":" + s;
    }

    visible: IdleService.enabled && (inhibited || !!nextAction)

    onIdleSinceChanged: now = Date.now()

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

                NumericText {
                    text: root.remainingText
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: root.contentColor
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

                NumericText {
                    text: root.remainingText
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: root.contentColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    onClicked: SessionService.toggleIdleInhibit()
}
