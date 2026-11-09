.pragma library

var BUCKETS = ["minimized", "scratchpad"];
var SURFACES = ["bar", "dock"];

// A stored session choice wins over the configured default; anything else stays in the bar.
function placement(stored, fallback) {
    return SURFACES.includes(stored) ? stored : SURFACES.includes(fallback) ? fallback : "bar";
}

// Where the buckets show: where they were placed, or on the only surface able to hold them.
function host(placed, inBar, inDock) {
    if (!inDock)
        return inBar ? "bar" : "none";
    return inBar ? placed : "dock";
}

function flipped(placed) {
    return placed === "dock" ? "bar" : "dock";
}
