import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const buckets = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/WindowBuckets.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), buckets);

test("a moved placement overrides the configured default, which overrides the bar", () => {
    assert.equal(buckets.placement("dock", "bar"), "dock");
    assert.equal(buckets.placement("", "dock"), "dock");
    assert.equal(buckets.placement("corner", undefined), "bar");
});

test("the buckets show where they were placed, or on the only surface able to hold them", () => {
    assert.equal(buckets.host("dock", true, true), "dock");
    assert.equal(buckets.host("dock", true, false), "bar");
    assert.equal(buckets.host("bar", false, true), "dock");
    assert.equal(buckets.host("bar", false, false), "none");
});
