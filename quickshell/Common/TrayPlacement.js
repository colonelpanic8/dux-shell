.pragma library

var PLACEMENTS = ["bar", "dock"];

function normalize(value, fallback) {
    if (PLACEMENTS.includes(value))
        return value;
    return PLACEMENTS.includes(fallback) ? fallback : "bar";
}

// Unset until first toggled, so the configured default applies.
function collapseEnabled(stored, fallback) {
    return typeof stored === "boolean" ? stored : fallback !== false;
}

function flipped(placement) {
    return placement === "dock" ? "bar" : "dock";
}

// Where the system tray lives on one screen.
//   home: the chosen surface, or the only one the screen offers ("none" without either).
//   host: where it renders now; home, unless the full bar routed it to the dock.
//   routable: a bar tray that leaves for the dock when the bar overflows it.
//   toggle: both surfaces exist here, so the tray can offer to move.
function resolve(facts) {
    const barTray = facts.barTray === true;
    const dockTray = facts.dockTray === true;
    const home = !barTray && !dockTray ? "none" : !dockTray ? "bar" : !barTray ? "dock" : normalize(facts.placement, "bar");
    const routable = home === "bar" && dockTray && facts.overflowToDock === true;
    const routed = routable && facts.barOverflowed === true;
    return {
        home,
        host: routed ? "dock" : home,
        routable,
        toggle: barTray && dockTray && !routed
    };
}
