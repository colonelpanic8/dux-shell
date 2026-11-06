import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const placement = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/TrayPlacement.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), placement);
const resolve = facts => JSON.parse(JSON.stringify(placement.resolve(facts)));
const both = { barTray: true, dockTray: true };

test("stored placement wins, then the configured default, then the bar", () => {
    assert.equal(placement.normalize("dock", "bar"), "dock");
    assert.equal(placement.normalize("", "dock"), "dock");
    assert.equal(placement.normalize(undefined, "dock"), "dock");
    assert.equal(placement.normalize("corner", "elsewhere"), "bar");
});

test("with both surfaces the tray lives where it was placed and can move", () => {
    assert.deepEqual(resolve({ ...both, placement: "dock" }), { home: "dock", host: "dock", routable: false, toggle: true });
    assert.deepEqual(resolve({ ...both, placement: "bar" }), { home: "bar", host: "bar", routable: false, toggle: true });
});

test("a screen with one surface keeps the tray there whatever the placement", () => {
    assert.deepEqual(resolve({ barTray: false, dockTray: true, placement: "bar" }), { home: "dock", host: "dock", routable: false, toggle: false });
    assert.deepEqual(resolve({ barTray: true, dockTray: false, placement: "dock", overflowToDock: true, barOverflowed: true }), { home: "bar", host: "bar", routable: false, toggle: false });
    assert.deepEqual(resolve({ barTray: false, dockTray: false, placement: "dock" }), { home: "none", host: "none", routable: false, toggle: false });
});

test("only a bar tray with overflow routing on leaves for the dock, and only while the bar overflows it", () => {
    assert.deepEqual(resolve({ ...both, placement: "bar", overflowToDock: true, barOverflowed: false }), { home: "bar", host: "bar", routable: true, toggle: true });
    assert.deepEqual(resolve({ ...both, placement: "bar", overflowToDock: true, barOverflowed: true }), { home: "bar", host: "dock", routable: true, toggle: false });
    assert.deepEqual(resolve({ ...both, placement: "bar", overflowToDock: false, barOverflowed: true }), { home: "bar", host: "bar", routable: false, toggle: true });
    assert.deepEqual(resolve({ ...both, placement: "dock", overflowToDock: true, barOverflowed: true }), { home: "dock", host: "dock", routable: false, toggle: true });
});

const service = readFileSync(new URL("../Services/TrayPlacementService.qml", import.meta.url), "utf8");

function serviceContext() {
    const context = vm.createContext({});
    for (const name of ["isTray", "barHasTray", "setBarRouted"]) {
        const match = service.match(new RegExp(`^    function ${name}\\([^\\n]*\\) \\{\\n[\\s\\S]*?^    \\}`, "m"));
        assert.ok(match, name);
        vm.runInContext(match[0].replace(/root\./g, "this."), context);
    }
    context.routedBars = {};
    return context;
}

test("a bar offers the tray only through an enabled systemTray entry", () => {
    const context = serviceContext();
    assert.equal(context.barHasTray({ rightWidgets: ["clock", "systemTray"] }), true);
    assert.equal(context.barHasTray({ leftWidgets: [{ id: "systemTray", enabled: true }] }), true);
    assert.equal(context.barHasTray({ rightWidgets: [{ id: "systemTray", enabled: false }, "clock"] }), false);
    assert.equal(context.barHasTray({ centerWidgets: ["clock"] }), false);
    assert.equal(context.isTray({ widgetId: "systemTray", enabled: false }), false);
});

test("routing facts stay per bar, so one bar coming back does not clear another", () => {
    const context = serviceContext();
    context.setBarRouted("DP-1", "top", true);
    context.setBarRouted("DP-1", "side", true);
    context.setBarRouted("DP-1", "top", false);
    assert.deepEqual(Object.keys(context.routedBars), ["DP-1\nside"]);
});
