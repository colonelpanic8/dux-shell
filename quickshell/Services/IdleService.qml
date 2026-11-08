pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services
import "../Common/IdleInhibitors.js" as IdleInhibitors

Singleton {
    id: root
    readonly property var log: Log.scoped("IdleService")

    property bool enabled: true
    // Off: app inhibitors (D-Bus and Wayland) are still listed but never hold off the timers.
    readonly property bool respectInhibitors: SettingsData.idleRespectInhibitors

    // Wayland idle inhibitors held by windows (or layer surfaces). Only observable
    // by comparing an inhibitor-respecting probe against one that ignores them,
    // so it updates after a second without input and holds its value otherwise.
    property bool compositorInhibitActive: false
    readonly property bool hyprlandWindowInfo: CompositorService.isHyprland
    // Keys of inhibitors the user switched off; they last as long as the window or D-Bus caller.
    property var ignoredInhibitors: []
    readonly property bool inhibitorSourcesActive: compositorInhibitActive || DMSService.screensaverInhibitors.length > 0
    readonly property var inhibitors: IdleInhibitors.collect({
        "manual": SessionService.idleInhibited,
        "screensaver": DMSService.screensaverInhibitors,
        "clients": hyprlandWindowInfo && inhibitorSourcesActive ? Hyprland.toplevels.values.map(t => t.lastIpcObject) : [],
        "compositorInhibited": compositorInhibitActive,
        "windowInfo": hyprlandWindowInfo,
        "filter": SettingsData.idleInhibitIgnoredWindows,
        "ignored": ignoredInhibitors,
        "respect": respectInhibitors
    })
    readonly property var activeInhibitors: inhibitors.filter(i => i.active)
    readonly property bool externalInhibitActive: activeInhibitors.some(i => i.kind === "screensaver")
    readonly property bool windowInhibitActive: activeInhibitors.some(i => i.kind === "window" || i.kind === "compositor")
    readonly property bool filterWindowInhibitors: respectInhibitors && hyprlandWindowInfo && (SettingsData.idleInhibitIgnoredWindows.trim() !== "" || ignoredInhibitors.some(k => !k.startsWith("dbus:")))
    // Filtering means the timers ignore compositor inhibitors and are gated on windowInhibitActive instead.
    readonly property bool monitorsRespectInhibitors: respectInhibitors && !filterWindowInhibitors

    function setInhibitorIgnored(key, ignored) {
        const rest = ignoredInhibitors.filter(k => k !== key);
        ignoredInhibitors = ignored ? rest.concat([key]) : rest;
    }

    function _pruneIgnoredInhibitors() {
        if (ignoredInhibitors.length === 0)
            return;
        const cookies = DMSService.screensaverInhibitors.map(i => "dbus:" + i.cookie);
        const windows = hyprlandWindowInfo ? Hyprland.toplevels.values.map(t => "window:" + (t.lastIpcObject?.address ?? "")) : [];
        const live = ignoredInhibitors.filter(k => cookies.includes(k) || windows.includes(k) || (k === "compositor" && compositorInhibitActive));
        if (live.length !== ignoredInhibitors.length)
            ignoredInhibitors = live;
    }

    readonly property bool isOnBattery: BatteryService.batteryAvailable && !BatteryService.isPluggedIn
    readonly property int monitorTimeout: isOnBattery ? SettingsData.batteryMonitorTimeout : SettingsData.acMonitorTimeout
    readonly property int lockTimeout: isOnBattery ? SettingsData.batteryLockTimeout : SettingsData.acLockTimeout
    readonly property int suspendTimeout: isOnBattery ? SettingsData.batterySuspendTimeout : SettingsData.acSuspendTimeout
    readonly property int suspendBehavior: isOnBattery ? SettingsData.batterySuspendBehavior : SettingsData.acSuspendBehavior
    readonly property int postLockMonitorTimeout: isOnBattery ? SettingsData.batteryPostLockMonitorTimeout : SettingsData.acPostLockMonitorTimeout
    readonly property bool postLockMonitorActive: isShellLocked && postLockMonitorTimeout > 0

    onEnabledChanged: _applyMonitorEnableds()
    onPostLockMonitorActiveChanged: _applyMonitorEnableds()
    onMonitorTimeoutChanged: _rearmIdleMonitors()
    onLockTimeoutChanged: _rearmIdleMonitors()
    onSuspendTimeoutChanged: _rearmIdleMonitors()
    onPostLockMonitorTimeoutChanged: _rearmIdleMonitors()
    onIsShellLockedChanged: _rearmIdleMonitors()

    function _applyMonitorEnableds() {
        // Gate on the shell's own inhibit state rather than relying on the
        // compositor honoring the bar-surface zwp_idle_inhibit inhibitor,
        // which goes inactive whenever the bar surface is occluded
        // (fullscreen windows) or hidden (auto-hide).
        const base = enabled && !SessionService.idleInhibited && !externalInhibitActive && !(filterWindowInhibitors && windowInhibitActive);
        monitorOffMonitor.enabled = base && monitorTimeout > 0 && !postLockMonitorActive;
        postLockMonitorOffMonitor.enabled = enabled && postLockMonitorActive;
        lockMonitor.enabled = base && lockTimeout > 0;
        suspendMonitor.enabled = base && suspendTimeout > 0;
        countdownRearmed = true;
    }

    property int countdownRefs: 0
    // Rearmed with the action monitors so both measure idle time from the same instant.
    property bool countdownRearmed: true
    // Epoch ms of the last input, or 0 while active.
    property double idleSince: 0

    readonly property var nextIdleAction: {
        const candidates = [[monitorOffMonitor, "monitorOff", monitorTimeout], [postLockMonitorOffMonitor, "monitorOff", postLockMonitorTimeout], [lockMonitor, "lock", isShellLocked ? 0 : lockTimeout], [suspendMonitor, "suspend", suspendTimeout]];
        let next = null;
        for (const [monitor, action, timeout] of candidates) {
            if (!monitor.enabled || monitor.isIdle || timeout <= 0)
                continue;
            if (!next || timeout < next.timeout)
                next = {
                    "action": action,
                    "timeout": timeout
                };
        }
        return next;
    }

    // Actions idling would take first, ignoring inhibitors; ties run together.
    readonly property var firstIdleActions: {
        const stages = [["lock", isShellLocked ? 0 : lockTimeout], ["monitorOff", postLockMonitorActive ? postLockMonitorTimeout : monitorTimeout], ["suspend", suspendTimeout]].filter(([, timeout]) => timeout > 0);
        if (stages.length === 0)
            return ["monitorOff"];
        const first = Math.min(...stages.map(([, timeout]) => timeout));
        return stages.filter(([, timeout]) => timeout === first).map(([action]) => action);
    }

    function triggerIdleNow() {
        log.info("Idle triggered manually:", firstIdleActions.join(", "));
        dpmsReason = "go idle now";
        for (const action of firstIdleActions) {
            switch (action) {
            case "lock":
                lockRequested();
                break;
            case "suspend":
                requestSuspend();
                break;
            default:
                requestMonitorOff();
            }
        }
    }

    function addCountdownRef() {
        countdownRefs++;
    }

    function removeCountdownRef() {
        countdownRefs = Math.max(0, countdownRefs - 1);
    }

    function _rearmIdleMonitors() {
        log.info("Idle timers restarted" + (monitorsOff ? " while displays off" : ""));
        monitorOffMonitor.enabled = false;
        postLockMonitorOffMonitor.enabled = false;
        lockMonitor.enabled = false;
        suspendMonitor.enabled = false;
        countdownRearmed = false;
        Qt.callLater(_applyMonitorEnableds);
    }

    signal lockRequested
    signal fadeToLockRequested
    signal cancelFadeToLock
    signal dismissFadeToLock
    signal fadeToDpmsRequested
    signal cancelFadeToDpms
    signal requestMonitorOff
    signal requestMonitorOn
    signal requestSuspend

    property var lockComponent: null
    property bool monitorsOff: false
    // Why monitorsOff is about to change; logged with the change.
    property string dpmsReason: ""
    property bool isShellLocked: false
    property bool isSessionLockSecure: false
    property bool lockPowerOffRequested: false
    property bool sleepBlocked: false

    function _updateSleepBlocked(blockInhibited) {
        if (typeof blockInhibited === "string")
            sleepBlocked = blockInhibited.split(":").includes("sleep");
    }

    function reapplyDpmsIfNeeded() {
        if (monitorsOff)
            CompositorService.powerOffMonitors();
    }

    IdleMonitor {
        id: monitorOffMonitor
        timeout: root.monitorTimeout > 0 ? root.monitorTimeout : 86400
        respectInhibitors: root.monitorsRespectInhibitors
        enabled: false
        onIsIdleChanged: {
            if (!enabled)
                return;
            root.log.info("Display-off stage", isIdle ? "reached" : "reset by activity");
            root.dpmsReason = isIdle ? "idle for " + root.monitorTimeout + "s" : "activity";
            if (isIdle) {
                if (SettingsData.fadeToDpmsEnabled) {
                    root.fadeToDpmsRequested();
                } else {
                    root.requestMonitorOff();
                }
            } else {
                if (SettingsData.fadeToDpmsEnabled) {
                    root.cancelFadeToDpms();
                }
                root.requestMonitorOn();
            }
        }
    }

    IdleMonitor {
        id: postLockMonitorOffMonitor
        timeout: root.postLockMonitorTimeout > 0 ? root.postLockMonitorTimeout : 86400
        respectInhibitors: root.monitorsRespectInhibitors
        enabled: false
        onIsIdleChanged: {
            if (!enabled)
                return;
            root.log.info("Post-lock display-off stage", isIdle ? "reached" : "reset by activity");
            root.dpmsReason = isIdle ? "locked and idle for " + root.postLockMonitorTimeout + "s" : "activity on lock screen";
            if (isIdle) {
                root.requestMonitorOff();
            } else {
                root.requestMonitorOn();
            }
        }
    }

    IdleMonitor {
        id: lockMonitor
        timeout: root.lockTimeout > 0 ? root.lockTimeout : 86400
        respectInhibitors: root.monitorsRespectInhibitors
        enabled: false
        onIsIdleChanged: {
            if (!enabled)
                return;
            root.log.info("Lock stage", isIdle ? "reached" : "reset by activity");
            if (isIdle) {
                if (SettingsData.fadeToLockEnabled) {
                    root.fadeToLockRequested();
                } else {
                    root.lockRequested();
                }
            } else {
                if (SettingsData.fadeToLockEnabled) {
                    root.cancelFadeToLock();
                }
            }
        }
    }

    IdleMonitor {
        id: suspendMonitor
        timeout: root.suspendTimeout > 0 ? root.suspendTimeout : 86400
        respectInhibitors: root.monitorsRespectInhibitors
        enabled: false
        onIsIdleChanged: {
            if (!enabled)
                return;
            root.log.info("Suspend stage", isIdle ? "reached" : "reset by activity");
            if (isIdle)
                root.requestSuspend();
        }
    }

    IdleMonitor {
        id: activityMonitor
        timeout: 1
        respectInhibitors: root.monitorsRespectInhibitors
        enabled: root.enabled && root.countdownRefs > 0 && root.countdownRearmed && root.nextIdleAction !== null
        onEnabledChanged: root.idleSince = 0
        onIsIdleChanged: root.idleSince = enabled && isIdle ? Date.now() - timeout * 1000 : 0
    }

    IdleMonitor {
        id: inputProbe
        timeout: 1
        respectInhibitors: false
        enabled: root.enabled && (root.countdownRefs > 0 || root.filterWindowInhibitors)
        onEnabledChanged: {
            if (!enabled)
                root.compositorInhibitActive = false;
        }
        onIsIdleChanged: probeSettle.restart()
    }

    IdleMonitor {
        id: inhibitProbe
        timeout: 1
        respectInhibitors: true
        enabled: inputProbe.enabled
        onIsIdleChanged: probeSettle.restart()
    }

    // Both probes fire together; wait for the pair to settle before comparing.
    Timer {
        id: probeSettle
        interval: 250
        onTriggered: {
            if (inputProbe.enabled && inputProbe.isIdle)
                root.compositorInhibitActive = !inhibitProbe.isIdle;
        }
    }

    // Hyprland sends no event when a window starts or stops inhibiting.
    Timer {
        interval: 10000
        repeat: true
        triggeredOnStart: true
        running: root.inhibitorSourcesActive && root.hyprlandWindowInfo
        onTriggered: Hyprland.refreshToplevels()
    }

    // Rearming the timeout monitors while idle resets their isIdle without a wake
    // transition, so this listener, never rearmed, catches input while outputs are off.
    IdleMonitor {
        id: wakeMonitor
        timeout: 1
        respectInhibitors: false
        enabled: root.enabled && root.monitorsOff
        onIsIdleChanged: {
            if (!enabled)
                return;
            if (!isIdle && root.monitorsOff) {
                root.dpmsReason = "input while displays off";
                root.requestMonitorOn();
            }
        }
    }

    onMonitorsOffChanged: {
        log.info(monitorsOff ? "Displays off:" : "Displays on:", dpmsReason || "unknown");
        dpmsReason = "";
        displaysLitWhileOff = [];
    }

    // Outputs the compositor reports lit while monitorsOff, e.g. after a hotplug.
    property var displaysLitWhileOff: []

    Timer {
        interval: 30000
        repeat: true
        running: root.monitorsOff && CompositorService.isHyprland
        // lastIpcObject predates the DPMS change until the first refresh lands.
        property bool refreshed: false
        onRunningChanged: refreshed = false
        onTriggered: {
            Hyprland.refreshMonitors();
            if (!refreshed) {
                refreshed = true;
                return;
            }
            const lit = Hyprland.monitors.values.filter(m => m.lastIpcObject?.dpmsStatus === true).map(m => m.name);
            if (lit.join() !== root.displaysLitWhileOff.join()) {
                if (lit.length > 0)
                    root.log.warn("Displays lit while idle has them off:", lit.join(", "));
                else
                    root.log.info("Displays dark again");
                root.displaysLitWhileOff = lit;
            }
        }
    }

    Connections {
        target: Hyprland
        enabled: root.monitorsOff && CompositorService.isHyprland

        function onRawEvent(event) {
            if (event.name === "monitoraddedv2" || event.name === "monitorremoved")
                root.log.info("Display", event.name === "monitorremoved" ? "disconnected" : "connected", "while displays off:", event.data);
        }
    }

    Connections {
        target: SessionService

        function onIdleInhibitedChanged() {
            root._rearmIdleMonitors();
        }
    }

    Connections {
        target: DMSService

        function onCapabilitiesReceived() {
            if (!DMSService.capabilities.includes("dbus"))
                return;
            DMSService.dbusSubscribe("system", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.DBus.Properties", "PropertiesChanged");
            DMSService.dbusGetProperty("system", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "BlockInhibited", r => root._updateSleepBlocked(r.result?.value));
        }

        function onDbusSignalReceived(subscriptionId, data) {
            if (data.path === "/org/freedesktop/login1")
                root._updateSleepBlocked(data.body?.[1]?.BlockInhibited);
        }
    }

    Connections {
        target: root
        function onRequestMonitorOff() {
            monitorsOff = true;
            CompositorService.powerOffMonitors();
        }

        function onRequestMonitorOn() {
            monitorsOff = false;
            CompositorService.powerOnMonitors();
        }

        function onRequestSuspend() {
            SessionService.suspendWithBehavior(root.suspendBehavior);
        }
    }

    onExternalInhibitActiveChanged: {
        if (externalInhibitActive) {
            const apps = DMSService.screensaverInhibitors.map(i => i.appName).join(", ");
            log.info("External idle inhibit active from:", apps || "unknown");
        } else {
            log.info("External idle inhibit released");
        }
        _rearmIdleMonitors();
    }

    onWindowInhibitActiveChanged: {
        if (filterWindowInhibitors)
            _rearmIdleMonitors();
    }

    onFilterWindowInhibitorsChanged: _rearmIdleMonitors()
    onRespectInhibitorsChanged: _rearmIdleMonitors()

    readonly property string activeInhibitorKey: activeInhibitors.map(i => i.key).join(",")
    onActiveInhibitorKeyChanged: {
        if (activeInhibitorKey)
            log.info("Idle inhibited by:", activeInhibitors.map(i => (i.appId || i.kind) + (i.title ? " (" + i.title + ")" : "")).join(", "));
    }

    onInhibitorsChanged: Qt.callLater(_pruneIgnoredInhibitors)

    onSleepBlockedChanged: {
        log.info(sleepBlocked ? "Sleep blocked by logind inhibitor" : "Sleep inhibitor released");
        if (sleepBlocked || !suspendMonitor.enabled || !suspendMonitor.isIdle)
            return;
        log.info("Sleep inhibitor released while idle, retrying suspend");
        requestSuspend();
    }

    Component.onCompleted: _applyMonitorEnableds()
}
