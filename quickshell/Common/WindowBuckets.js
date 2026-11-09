.pragma library

var SURFACES = ["bar", "dock"];

// A stored session choice wins over the configured default; anything else stays in the bar.
function placement(stored, fallback) {
    return SURFACES.includes(stored) ? stored : SURFACES.includes(fallback) ? fallback : "bar";
}

// Where the hidden windows widget shows: where it was placed, or on the only surface holding it.
function host(placed, inBar, inDock) {
    if (!inDock)
        return inBar ? "bar" : "none";
    return inBar ? placed : "dock";
}

function flipped(placed) {
    return placed === "dock" ? "bar" : "dock";
}
