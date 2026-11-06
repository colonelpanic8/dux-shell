.pragma library

const ACTIONS = ["activate", "secondaryActivate", "menu", "none"];
const BUTTONS = ["left", "middle", "right"];
const BUILTIN = {
    "left": "activate",
    "middle": "secondaryActivate",
    "right": "menu"
};

function valid(action) {
    return ACTIONS.indexOf(action) !== -1;
}

function resolve(itemId, onlyMenu, button, defaults, overrides) {
    const override = overrides?.[itemId]?.[button];
    let action = valid(override) ? override : defaults?.[button];
    if (!valid(action))
        action = BUILTIN[button] || "none";
    // ItemIsMenu means the item has no primary action of its own.
    if (action === "activate" && onlyMenu)
        return "menu";
    return action;
}

function withOverride(overrides, itemId, button, action) {
    const next = Object.assign({}, overrides || {});
    const entry = Object.assign({}, next[itemId] || {});
    if (valid(action))
        entry[button] = action;
    else
        delete entry[button];
    if (Object.keys(entry).length)
        next[itemId] = entry;
    else
        delete next[itemId];
    return next;
}
