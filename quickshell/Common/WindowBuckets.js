.pragma library

var BUCKETS = ["minimized", "scratchpad"];
var SURFACES = ["bar", "dock"];

// A stored session choice wins over the configured default; anything else stays in the bar.
function placements(stored, defaults) {
    const result = {};
    for (const bucket of BUCKETS) {
        const choice = stored ? stored[bucket] : undefined;
        const fallback = defaults ? defaults[bucket] : undefined;
        result[bucket] = SURFACES.includes(choice) ? choice : SURFACES.includes(fallback) ? fallback : "bar";
    }
    return result;
}

// Buckets shown on `surface`: each where it was placed, or on the only surface able to hold it.
function hosted(surface, placed, inBar, inDock) {
    return BUCKETS.filter(bucket => {
        const home = !inDock ? (inBar ? "bar" : "") : !inBar ? "dock" : placed[bucket];
        return home === surface;
    });
}

function moved(stored, defaults, bucket) {
    const next = Object.assign({}, stored);
    next[bucket] = placements(stored, defaults)[bucket] === "dock" ? "bar" : "dock";
    return next;
}
