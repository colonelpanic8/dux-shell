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

function inhibitingWindows(ipcClients) {
    return ipcClients.filter(c => c && c.inhibitingIdle).map(c => ({
                "address": c.address || "",
                "appId": c.class || c.initialClass || "",
                "title": c.title || ""
            }));
}
