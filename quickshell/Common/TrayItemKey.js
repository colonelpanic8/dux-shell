.pragma library

const DEFAULT_PATH = "/StatusNotifierItem";
const PER_PROCESS_NAME = /^org\.(kde|freedesktop)\.StatusNotifierItem-\d+-\d+$/;
const THEME_ICON = "image://icon/";

// The watcher address is "<bus name>[<object path>]". Unique (":1.41") and per-process
// names change on every launch, so only a well-known name can identify the item.
function stableAddress(address) {
    if (!address)
        return "";
    const slash = address.indexOf("/");
    const service = slash < 0 ? address : address.substring(0, slash);
    const path = slash < 0 ? "" : address.substring(slash);
    if (!service || service.startsWith(":") || PER_PROCESS_NAME.test(service))
        return "";
    return path && path !== DEFAULT_PATH ? service + path : service;
}

function themeIconName(icon) {
    if (typeof icon !== "string" || !icon.startsWith(THEME_ICON))
        return "";
    return icon.substring(THEME_ICON.length).split("?")[0];
}

function baseKey(item) {
    if (item?.id)
        return item.id;
    const address = stableAddress(item?.watcherAddress);
    if (address)
        return address;
    const iconName = themeIconName(item?.icon);
    return iconName ? `icon:${iconName}` : "";
}

// Keys stay fixed per item object, so a later duplicate takes "<base>::1" instead of renaming the first.
function assign(item, pool, keyByItem) {
    const base = baseKey(item);
    if (!base)
        return "";
    // An item can be keyed before its id loads; re-key it once, when the id arrives.
    const cached = keyByItem.get(item);
    if (cached !== undefined && (!item.id || cached === item.id || cached.startsWith(item.id + "::")))
        return cached;
    const taken = new Set();
    for (const live of pool) {
        if (live !== item && keyByItem.has(live) && baseKey(live) === base)
            taken.add(keyByItem.get(live));
    }
    let key = base;
    for (let n = 1; taken.has(key); n++)
        key = `${base}::${n}`;
    keyByItem.set(item, key);
    return key;
}
