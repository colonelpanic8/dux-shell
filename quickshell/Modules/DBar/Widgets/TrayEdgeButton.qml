import QtQuick
import qs.Common
import qs.Modules.DBar
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets

// A tray-sized button at the tray's inner end: the collapsed tray's expand arrow, or the quick options button.
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
        width: root.tray.trayIconSize
        height: root.tray.trayIconSize
        anchors.centerIn: parent
        style: BarMetrics.widgetStyle(root.tray.barConfig)
        pressed: area.pressed
        color: Theme.blend(Theme.secondaryContainer, Theme.onSecondaryContainer, area.pressed ? Theme.stateLayerDrag + Theme.stateLayerPressed : area.containsMouse ? Theme.stateLayerDrag : 0)

        DIcon {
            anchors.centerIn: parent
            name: root.iconName
            size: Math.min(root.tray.trayIconSize, Theme.iconSizeSmall)
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

    // Screen point just outside the button on the side away from the surface's edge, where popups open.
    function popupAnchor() {
        const screen = tray.parentScreen;
        // A dock's layer window does not start at the screen edge, so map through its surface.
        const corner = BarWidgetService.registrationForItem(tray)?.context?.surface?.screenPoint(root, 0, 0);
        if (!corner || !screen)
            return null;
        const edge = tray.axis?.edge || "bottom";
        const gap = Theme.spacingS;
        const point = {
            left: Qt.point(corner.x + root.width + gap, corner.y + root.height / 2),
            right: Qt.point(corner.x - gap, corner.y + root.height / 2),
            top: Qt.point(corner.x + root.width / 2, corner.y + root.height + gap),
            bottom: Qt.point(corner.x + root.width / 2, corner.y - gap)
        }[edge];
        return {
            x: point.x,
            y: point.y,
            edge,
            isVertical: tray.isVerticalOrientation,
            screen
        };
    }

    function showTooltip() {
        tooltipLoader.active = true;
        const tooltip = tooltipLoader.item as DTooltip;
        const anchor = root.popupAnchor();
        if (!tooltip || !anchor)
            return;
        const text = root.tooltipText;
        tooltip.text = text;
        tooltip.show(text, anchor.x, anchor.edge === "bottom" ? anchor.y - tooltip.implicitHeight : anchor.y, anchor.screen, anchor.edge === "left", anchor.edge === "right");
    }
}
