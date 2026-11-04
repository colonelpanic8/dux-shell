.pragma library

// filter is a comma-separated list: plain entries match a window's class
// case-insensitively, /regex/ entries are tested against its class and title.
function isWindowIgnored(window, filter) {
    const appId = window.appId || "";
    const title = window.title || "";
    return filter.split(",").map(pattern => pattern.trim()).filter(pattern => pattern).some(pattern => {
        if (pattern.startsWith("/") && pattern.endsWith("/") && pattern.length > 2) {
            try {
                const re = new RegExp(pattern.slice(1, -1), "i");
                return re.test(appId) || re.test(title);
            } catch (e) {
                return false;
            }
        }
        return appId.toLowerCase() === pattern.toLowerCase();
    });
}

function clientWindow(c) {
    return {
        "address": c.address || "",
        "appId": c.class || c.initialClass || "",
        "title": c.title || "",
        "workspace": String(c.workspace?.name ?? "")
    };
}

function entry(key, kind, fields, state) {
    const ignoredByConfig = !!state.filter && (kind === "window" || kind === "screensaver") && isWindowIgnored(fields, state.filter);
    const ignored = state.ignored.includes(key);
    return Object.assign({
        "key": key,
        "kind": kind,
        "appId": "",
        "name": "",
        "title": "",
        "workspace": "",
        "reason": "",
        "address": "",
        "canIgnore": true,
        "ignoredByConfig": ignoredByConfig,
        "ignored": ignored,
        "active": !ignored && !ignoredByConfig
    }, fields);
}

// Every current idle inhibitor, ignored ones included. state: { manual, screensaver,
// clients (Hyprland IPC objects), compositorInhibited, windowInfo, filter, ignored (keys) }.
function collect(state) {
    const list = [];
    const clients = (state.clients || []).filter(c => c && c.address);

    if (state.manual)
        list.push(entry("manual", "manual", {}, state));

    for (const i of state.screensaver || []) {
        // A caller with several windows cannot be pinned to one of them.
        const owned = i.pid > 0 ? clients.filter(c => c.pid === i.pid).map(clientWindow) : [];
        const win = owned.length === 1 ? owned[0] : null;
        list.push(entry("dbus:" + i.cookie, "screensaver", {
            "appId": owned[0]?.appId || i.appName || "",
            "name": i.appName || "",
            "title": win?.title ?? "",
            "workspace": win?.workspace ?? "",
            "address": win?.address ?? "",
            "reason": i.reason || ""
        }, state));
    }

    if (!state.compositorInhibited)
        return list;

    const windows = clients.filter(c => c.inhibitingIdle).map(clientWindow);
    for (const w of windows)
        list.push(entry("window:" + w.address, "window", w, state));

    // The bar surface holds a compositor inhibitor for the manual and D-Bus ones.
    const shellInhibits = list.some(e => e.active && (e.kind === "manual" || e.kind === "screensaver"));
    if (windows.length === 0 && !shellInhibits)
        list.push(entry("compositor", "compositor", {
            "canIgnore": !!state.windowInfo
        }, state));

    return list;
}
