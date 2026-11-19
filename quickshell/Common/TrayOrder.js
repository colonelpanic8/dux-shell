.pragma library

// Unique bus names (":1.42") and the spec's per-process names
// ("org.kde.StatusNotifierItem-<pid>-<n>") change every time the app registers.
function stableAddress(address) {
    const slash = address.indexOf("/");
    const service = slash < 0 ? address : address.slice(0, slash);
    const path = slash < 0 ? "" : address.slice(slash);
    return (service.startsWith(":") ? "" : service.replace(/-\d+-\d+$/, "")) + path;
}

function identity(item) {
    const address = item.watcherAddress || "";
    const stable = stableAddress(address);
    return [item.id || stable, stable, item.title || "", address];
}

function compareIdentity(a, b) {
    for (let i = 0; i < a.length; i++) {
        if (a[i] !== b[i])
            return a[i] < b[i] ? -1 : 1;
    }
    return 0;
}

// Priority, then the saved manual order, then who the item is, never when it registered.
function sorted(items, priorityOf, savedOrder, keyOf) {
    const saved = new Map(savedOrder.map((key, index) => [key, index]));
    const entries = items.map(item => ({
        item: item,
        priority: priorityOf(item),
        saved: saved.has(keyOf(item)) ? saved.get(keyOf(item)) : savedOrder.length,
        identity: identity(item)
    }));
    entries.sort((a, b) => b.priority - a.priority || a.saved - b.saved || compareIdentity(a.identity, b.identity));
    return entries.map(entry => entry.item);
}
