import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const buckets = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/WindowBuckets.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), buckets);
const plain = value => JSON.parse(JSON.stringify(value));

test("a moved bucket overrides the configured default, which overrides the bar", () => {
    assert.deepEqual(plain(buckets.placements({ minimized: "dock", scratchpad: "corner" }, { scratchpad: "dock" })), { minimized: "dock", scratchpad: "dock" });
    assert.deepEqual(plain(buckets.placements(undefined, undefined)), { minimized: "bar", scratchpad: "bar" });
    assert.deepEqual(plain(buckets.moved({}, { minimized: "dock" }, "minimized")), { minimized: "bar" });
    assert.deepEqual(plain(buckets.moved({ minimized: "bar" }, {}, "minimized")), { minimized: "dock" });
});

test("each bucket shows where it was placed, or on the only surface able to hold it", () => {
    const placed = { minimized: "dock", scratchpad: "bar" };
    assert.deepEqual(plain(buckets.hosted("dock", placed, true, true)), ["minimized"]);
    assert.deepEqual(plain(buckets.hosted("bar", placed, true, true)), ["scratchpad"]);
    assert.deepEqual(plain(buckets.hosted("bar", placed, true, false)), ["minimized", "scratchpad"]);
    assert.deepEqual(plain(buckets.hosted("dock", placed, false, true)), ["minimized", "scratchpad"]);
    assert.deepEqual(plain(buckets.hosted("dock", placed, false, false)), []);
});
