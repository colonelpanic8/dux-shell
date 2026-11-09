import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Modules.DBar
import qs.Modules.Plugins
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets

// Minimized and scratchpad windows by bucket; shows in the bar or a dock, wherever it was placed.
BasePill {
    id: root

    property var widgetData: null
    property string surfaceKind: "bar"
    readonly property string screenName: parentScreen?.name ?? ""
    readonly property var placement: WindowBucketService.forScreen(screenName)
    readonly property real appIconSize: Math.max(0, widgetThickness - Theme.spacingXS * 2)

    property int _revision: 0
    readonly property var buckets: {
        _revision;
        if (placement.host !== surfaceKind || !IconThemeService.ready)
            return [];
        return CompositorService.windowBuckets(screenName).map(bucket => ({
                    "bucket": bucket.bucket,
                    "icon": bucket.icon,
                    "windows": bucket.windows.map(appEntry)
                }));
    }

    function appEntry(window) {
        const moddedId = Paths.moddedAppId(window.app_id || window.appId || window.class || window.windowClass || "unknown");
        const desktopEntry = DesktopEntries.heuristicLookup(moddedId);
        return {
            "windowId": window.address || window.id,
            "icon": Paths.getAppIcon(moddedId, desktopEntry),
            "name": Paths.getAppName(moddedId, desktopEntry) || ""
        };
    }

    visible: buckets.length > 0
    enableBackgroundHover: false
    enableCursor: false

    Connections {
        target: CompositorService
        function onToplevelsChanged() {
            root._revision++;
        }
        function onWorkspaceStateChanged() {
            root._revision++;
        }
    }

    content: Component {
        Grid {
            rows: root.isVerticalOrientation ? -1 : 1
            columns: root.isVerticalOrientation ? 1 : -1
            spacing: Theme.spacingM
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            Repeater {
                model: root.buckets

                Grid {
                    id: bucketGroup
                    required property var modelData
                    rows: root.isVerticalOrientation ? -1 : 1
                    columns: root.isVerticalOrientation ? 1 : -1
                    spacing: Theme.spacingXS
                    horizontalItemAlignment: Grid.AlignHCenter
                    verticalItemAlignment: Grid.AlignVCenter

                    DIcon {
                        name: bucketGroup.modelData.icon
                        size: root.appIconSize
                        color: root.contentColor
                    }

                    Repeater {
                        model: bucketGroup.modelData.windows

                        Item {
                            id: windowIcon
                            required property var modelData
                            width: root.appIconSize
                            height: root.appIconSize

                            IconImage {
                                id: appImage
                                anchors.fill: parent
                                source: windowIcon.modelData.icon || ""
                                visible: status === Image.Ready
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: appImage.status !== Image.Ready
                                color: Theme.chipSurface
                                radius: Math.min(Theme.cornerRadiusS, width / 2, height / 2)
                                border.width: Theme.outlineWidth
                                border.color: Theme.primarySelected

                                StyledText {
                                    anchors.centerIn: parent
                                    text: (windowIcon.modelData.name || "?").charAt(0).toUpperCase()
                                    font.pixelSize: parent.width * 0.45
                                    color: Theme.primary
                                    font.weight: Theme.fontWeightMedium
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: CompositorService.focusWindow(windowIcon.modelData.windowId)
                            }
                        }
                    }
                }
            }

            Item {
                id: moveButton
                visible: root.placement.movable
                width: root.appIconSize
                height: root.appIconSize

                BarPillSurface {
                    id: moveSurface
                    anchors.fill: parent
                    style: BarMetrics.widgetStyle(root.barConfig)
                    pressed: moveArea.pressed
                    color: Theme.blend(Theme.secondaryContainer, Theme.onSecondaryContainer, moveArea.pressed ? Theme.stateLayerDrag + Theme.stateLayerPressed : moveArea.containsMouse ? Theme.stateLayerDrag : 0)

                    DIcon {
                        anchors.centerIn: parent
                        name: root.surfaceKind === "dock" ? "close_fullscreen" : "open_in_new"
                        size: Math.min(root.appIconSize, Theme.iconSizeSmall)
                        color: Theme.onSecondaryContainer
                    }

                    MouseArea {
                        id: moveArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: {
                            if (moveArea.containsMouse)
                                root.showMoveTooltip(moveButton);
                            else
                                tooltipLoader.active = false;
                        }
                        onClicked: {
                            tooltipLoader.active = false;
                            WindowBucketService.move();
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: DTooltip {}
    }

    function showMoveTooltip(button) {
        tooltipLoader.active = true;
        const tooltip = tooltipLoader.item;
        // A dock's layer window does not start at the screen edge, so map through its surface.
        const corner = BarWidgetService.registrationForItem(root)?.context?.surface?.screenPoint(button, 0, 0);
        if (!tooltip || !corner || !parentScreen)
            return;
        const edge = axis?.edge || "bottom";
        const gap = Theme.spacingS;
        const point = {
            "left": Qt.point(corner.x + button.width + gap, corner.y + button.height / 2),
            "right": Qt.point(corner.x - gap, corner.y + button.height / 2),
            "top": Qt.point(corner.x + button.width / 2, corner.y + button.height + gap),
            "bottom": Qt.point(corner.x + button.width / 2, corner.y - gap)
        }[edge];
        const text = surfaceKind === "dock" ? I18n.tr("Move back to the bar", "tooltip on the hidden windows widget button that moves it from the dock to the bar") : I18n.tr("Pop out to the dock", "tooltip on the hidden windows widget button that moves it from the bar to the dock");
        tooltip.show(text, point.x, edge === "bottom" ? point.y - tooltip.implicitHeight : point.y, parentScreen, edge === "left", edge === "right");
    }
}
