import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.Common
import qs.DCommon.Widgets

Item {
    id: root

    property var tray: null
    property var trayItem: null
    property string source: ""
    property real iconSize: tray ? tray.trayIconSize : 16
    property bool iconTintEnabled: tray ? tray.trayIconTintEnabled : false
    property real iconSaturation: tray ? tray.trayIconSaturation : 0
    property real iconColorization: tray ? tray.trayIconColorization : 0
    property color iconTintColor: tray ? tray.trayIconTintColor : "transparent"
    property color fallbackTextColor: tray ? (tray.trayTextColor ?? Theme.widgetTextColor) : Theme.widgetTextColor
    property real fallbackTextSize: 10
    property string fallbackSource: ""
    property bool lowContrast: false
    property bool hasImage: false

    onSourceChanged: fallbackSource = ""

    function luminance(r, g, b) {
        const channel = c => c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);
    }

    // Outline icons drawn mostly in colors close to the bar background (e.g. white icons on a light bar).
    Canvas {
        id: contrastProbe
        width: 16
        height: 16
        opacity: 0
        onImageLoaded: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(iconImg.backer, 0, 0, width, height);
            const data = ctx.getImageData(0, 0, width, height).data;
            const bg = Theme.widgetBaseBackgroundColor;
            const bgLum = root.luminance(bg.r, bg.g, bg.b);
            let total = 0;
            let faint = 0;
            for (let i = 0; i < data.length; i += 4) {
                const alpha = data[i + 3] / 255;
                if (alpha < 0.1)
                    continue;
                const lum = root.luminance(data[i] / 255, data[i + 1] / 255, data[i + 2] / 255);
                total += alpha;
                if ((Math.max(lum, bgLum) + 0.05) / (Math.min(lum, bgLum) + 0.05) < 2.2)
                    faint += alpha;
            }
            root.lowContrast = total > 0 && faint / total > 0.5;
        }
    }

    Connections {
        target: Theme
        function onWidgetBaseBackgroundColorChanged() {
            contrastProbe.requestPaint();
        }
    }

    IconImage {
        id: iconImg
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: root.fallbackSource || root.source
        asynchronous: true
        // Pixmap-backed items get a new URL on every icon update; keep the old frame instead of flashing the fallback.
        backer.retainWhileLoading: true
        onStatusChanged: {
            if (status === Image.Ready)
                contrastProbe.requestPaint();
            if (status !== Image.Loading)
                root.hasImage = status === Image.Ready;
            if (status !== Image.Error || root.fallbackSource)
                return;
            const requested = root.source;
            TrayMenuManager.resolveIconFallback(root.trayItem?.icon, url => {
                if (root.source !== requested)
                    return;
                root.fallbackSource = url;
            });
        }
        smooth: true
        mipmap: true
        visible: status === Image.Ready || (status === Image.Loading && root.hasImage)
        layer.enabled: root.iconTintEnabled || root.lowContrast
        layer.effect: MultiEffect {
            saturation: root.iconTintEnabled ? root.iconSaturation : 0
            colorization: root.iconTintEnabled ? root.iconColorization : 0
            colorizationColor: root.iconTintColor
            shadowEnabled: root.lowContrast
            shadowColor: Theme.surfaceText
            shadowBlur: 0.5
            blurMax: 4
            shadowScale: 1.12
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
    }

    StyledText {
        anchors.centerIn: parent
        visible: !iconImg.visible
        text: {
            const itemId = root.trayItem?.id || "";
            if (!itemId)
                return "?";
            return itemId.charAt(0).toUpperCase();
        }
        font.pixelSize: root.fallbackTextSize
        color: root.fallbackTextColor
    }
}
