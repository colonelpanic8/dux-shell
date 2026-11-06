import QtQuick
import qs.Common
import qs.Modules.DBar
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets

// A tray-sized button at the tray's inner end: the collapsed tray's expand arrow, or the move-to-bar/dock button.
Item {
    id: root

    required property SystemTrayBar tray
    property bool shown: false
    property string iconName: ""
    property string tooltipText: ""
    readonly property bool vertical: tray.isVerticalOrientation
    property real extent: shown ? tray.trayItemSize : 0

    signal clicked
    signal hoverChanged(bool hovered)

    width: vertical ? tray.barThickness : extent
    height: vertical ? extent : tray.barThickness
    opacity: shown ? 1 : 0
    visible: extent > 0

    Behavior on extent {
        enabled: !SettingsData.reduceMotion
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    Behavior on opacity {
        enabled: !SettingsData.reduceMotion
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    BarPillSurface {
        id: button
        width: root.tray.trayItemSize
        height: root.tray.trayItemSize
        anchors.centerIn: parent
        style: BarMetrics.widgetStyle(root.tray.barConfig)
        pressed: area.pressed
        color: Theme.blend(Theme.secondaryContainer, Theme.onSecondaryContainer, area.pressed ? Theme.stateLayerDrag + Theme.stateLayerPressed : area.containsMouse ? Theme.stateLayerDrag : 0)

        DIcon {
            anchors.centerIn: parent
            name: root.iconName
            size: root.tray.trayIconSize
            color: Theme.onSecondaryContainer
        }

        DRipple {
            id: ripple
            cornerRadius: button.radius
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: {
                root.hoverChanged(area.containsMouse);
                if (area.containsMouse)
                    root.showTooltip();
                else
                    tooltipLoader.active = false;
            }
            onPressed: mouse => ripple.trigger(mouse.x, mouse.y)
            onClicked: {
                tooltipLoader.active = false;
                root.clicked();
            }
        }
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: DTooltip {}
    }

    function showTooltip() {
        const screen = tray.parentScreen;
        tooltipLoader.active = true;
        const tooltip = tooltipLoader.item as DTooltip;
        if (!tooltip || !screen)
            return;
        const text = root.tooltipText;
        tooltip.text = text;
        // A dock's layer window does not start at the screen edge, so map through its surface.
        const corner = BarWidgetService.registrationForItem(tray)?.context?.surface?.screenPoint(root, 0, 0);
        if (!corner)
            return;
        switch (tray.axis?.edge) {
        case "left":
            tooltip.show(text, corner.x + root.width + Theme.spacingS, corner.y + root.height / 2, screen, true, false);
            return;
        case "right":
            tooltip.show(text, corner.x - Theme.spacingS, corner.y + root.height / 2, screen, false, true);
            return;
        case "top":
            tooltip.show(text, corner.x + root.width / 2, corner.y + root.height + Theme.spacingS, screen, false, false);
            return;
        default:
            tooltip.show(text, corner.x + root.width / 2, corner.y - Theme.spacingS - tooltip.implicitHeight, screen, false, false);
        }
    }
}
