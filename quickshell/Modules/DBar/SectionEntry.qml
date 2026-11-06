import QtQuick
import qs.Services
import "OverflowLayout.js" as OverflowLayout

Item {
    id: root

    required property var sectionContext
    required property var itemData
    required property int occurrenceOrder
    readonly property alias host: widgetLoader
    readonly property alias slot: slot
    readonly property alias item: widgetLoader.item
    readonly property var widgetItem: widgetLoader.item
    readonly property bool active: widgetLoader.active
    readonly property bool itemVisible: widgetItem?.visible ?? false
    readonly property bool effectiveVisible: widgetItem?.effectiveVisible ?? true
    readonly property real itemWidth: widgetItem?.width ?? 0
    readonly property real itemHeight: widgetItem?.height ?? 0
    readonly property var trayPlacement: itemData?.widgetId === "systemTray" ? TrayPlacementService.forScreen(sectionContext.parentScreen?.name ?? "") : null
    // A routable tray stays measured while it is in the dock, so leaving never changes the layout that sent it away.
    readonly property bool routable: trayPlacement?.routable ?? false
    readonly property bool homeElsewhere: !!trayPlacement && trayPlacement.home !== "bar"
    readonly property bool routesAway: routable && (sectionContext.barContent?.trayRoutesAway ?? false)
    readonly property bool away: homeElsewhere || (routable && (sectionContext.barContent?.trayRouted ?? false))
    readonly property bool detached: inOverflow || away
    readonly property bool available: active && widgetLoader.widgetEnabled && itemVisible && effectiveVisible && itemWidth > 0 && itemHeight > 0
    readonly property real primarySize: available ? (sectionContext.isVertical ? itemHeight : itemWidth) : 0
    // A flexible widget reports the width it wants and the width it can live with; the resolver allots between them.
    readonly property real preferredSize: !available || homeElsewhere ? 0 : widgetItem && "naturalPrimarySize" in widgetItem ? widgetItem.naturalPrimarySize : primarySize
    readonly property real minimumSize: available && widgetItem && "minimumPrimarySize" in widgetItem ? Math.min(preferredSize, widgetItem.minimumPrimarySize) : preferredSize
    readonly property real allottedSize: sectionContext.allottedSizes[occurrenceOrder] ?? 0
    readonly property string configuredOverflowMode: OverflowLayout.placement(itemData, sectionContext.overflowDefaultMode)
    readonly property string overflowMode: routable && configuredOverflowMode === "bar" ? "auto" : configuredOverflowMode
    // A tray with a dock to go to leaves the bar first.
    readonly property real overflowPriority: routable ? -Infinity : OverflowLayout.priority(itemData)
    readonly property bool inOverflow: overflowMode === "always" || sectionContext.overflowIndices.includes(occurrenceOrder)
    readonly property bool inPopup: inOverflow && !away && sectionContext.overflowOpen && !!sectionContext.overflowParent
    readonly property bool participates: available && !detached
    readonly property bool presentationLive: !detached || inPopup
    property real popupX: 0
    property real popupY: 0

    visible: active && widgetLoader.widgetEnabled && !detached
    z: widgetItem?.overlaying ? 1 : 0
    width: participates ? (sectionContext.isVertical ? sectionContext.width : itemWidth) : 0
    height: participates ? itemHeight : 0

    Item {
        id: slot
        // The slot moves between the wrapper, the parking host and the popup; the widget never changes anchors.
        parent: root.detached ? (root.inPopup ? root.sectionContext.overflowParent : root.sectionContext.parkingHost) : root
        x: root.detached ? root.popupX : 0
        y: root.detached ? root.popupY : 0
        width: root.detached ? root.itemWidth : root.width
        height: root.detached ? root.itemHeight : root.height

        SectionWidget {
            id: widgetLoader
            // Constant anchors: changing the anchor set, even for one evaluation, makes Qt stretch the loader and overwrite the widget's size.
            anchors.left: root.sectionContext.isVertical ? undefined : parent.left
            anchors.verticalCenter: root.sectionContext.isVertical ? undefined : parent.verticalCenter
            anchors.top: root.sectionContext.isVertical ? parent.top : undefined
            anchors.horizontalCenter: root.sectionContext.isVertical ? parent.horizontalCenter : undefined
            enabled: root.presentationLive
            live: root.presentationLive
            sectionContext: root.sectionContext
            widgetData: root.itemData
            occurrenceOrder: root.occurrenceOrder
            isFirst: !root.detached && root.sectionContext.inlineOrder[0] === root.occurrenceOrder
            isLast: !root.detached && root.sectionContext.inlineOrder[root.sectionContext.inlineOrder.length - 1] === root.occurrenceOrder
            sectionSpacing: root.detached ? 0 : root.sectionContext.widgetSpacing
            segmentRole: root.detached ? "solo" : root.sectionContext.roleAt(root.occurrenceOrder)
            blurBarWindow: root.detached ? null : root.sectionContext.blurBarWindow
            isLeftBarEdge: !root.detached && !isInColumn && section === "left" && root.sectionContext.edgeIsScreenEdge
            isRightBarEdge: !root.detached && !isInColumn && section === "right" && root.sectionContext.edgeIsScreenEdge
            isTopBarEdge: !root.detached && isInColumn && section === "left" && root.sectionContext.edgeIsScreenEdge
            isBottomBarEdge: !root.detached && isInColumn && section === "right" && root.sectionContext.edgeIsScreenEdge
            crossEdgeExtension: !root.detached && !isInColumn && section !== "center" ? root.sectionContext.crossEdgeExtension : 0
            allottedPrimarySize: root.detached ? 0 : root.allottedSize
            overflowAnchor: root.inOverflow && !root.away ? root.sectionContext.overflowButton : null
            overflowSurface: root.inOverflow && !root.away ? root.sectionContext.overflowSurface : null
        }
    }
}
