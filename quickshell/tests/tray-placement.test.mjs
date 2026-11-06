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

test("collapsing follows the stored choice, then the configured default, which is on", () => {
    assert.deepEqual([placement.collapseEnabled(false, true), placement.collapseEnabled(true, false)], [false, true]);
    assert.deepEqual([placement.collapseEnabled(null, false), placement.collapseEnabled(null, true), placement.collapseEnabled(null, undefined)], [false, true, true]);
});

const plain = value => JSON.parse(JSON.stringify(value));

test("pins keep distinct keys in pin order and never the empty key", () => {
    assert.deepEqual(plain(placement.pins(["a", "", "b", "a", 3, null, "b"])), ["a", "b"]);
    assert.deepEqual(plain(placement.pins(undefined)), []);
    assert.deepEqual(plain(placement.pins("a")), []);
});

test("pinning appends once, unpinning removes, and toggling flips", () => {
    assert.deepEqual(plain(placement.withPin(["a"], "b", true)), ["a", "b"]);
    assert.deepEqual(plain(placement.withPin(["a", "b"], "a", true)), ["a", "b"]);
    assert.deepEqual(plain(placement.withPin(["a", "b", "a"], "a", false)), ["b"]);
    assert.deepEqual(plain(placement.withPin(["a"], "", true)), ["a"]);
    assert.deepEqual(plain(placement.withPinToggled(["a", "b"], "a")), ["b"]);
    assert.deepEqual(plain(placement.withPinToggled(null, "a")), ["a"]);
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

const ipc = readFileSync(new URL("../DMSShellIPC.qml", import.meta.url), "utf8");

function pinShell(stored) {
    const SessionData = {
        trayPinnedItems: stored,
        set(key, value) {
            this[key] = value;
        }
    };
    const TrayPlacementService = vm.createContext({ SessionData, TrayPlacement: placement });
    Object.defineProperty(TrayPlacementService, "pinnedKeys", { get: () => placement.pins(SessionData.trayPinnedItems) });
    for (const name of ["setPinned", "togglePin"])
        vm.runInContext(service.match(new RegExp(`^    function ${name}\\([^\\n]*\\) \\{\\n[\\s\\S]*?^    \\}`, "m"))[0], TrayPlacementService);
    const handler = vm.createContext({ TrayPlacementService });
    for (const name of ["pins", "pin", "unpin", "togglePin"]) {
        const match = ipc.match(new RegExp(`^        function ${name}\\(([^)]*)\\): string \\{\\n[\\s\\S]*?^        \\}`, "m"));
        assert.ok(match, name);
        vm.runInContext(match[0].replace(/\((.*?)\): string \{/, (_, params) => "(" + params.replace(/: \w+/g, "") + ") {"), handler);
    }
    return { handler, SessionData };
}

test("ipc pins edit the one session list and refuse an empty key", () => {
    const { handler, SessionData } = pinShell(["a", ""]);
    assert.deepEqual([handler.pin("b"), handler.togglePin("a"), handler.unpin("missing"), handler.pins()], ["true", "false", "false", "b"]);
    assert.deepEqual(plain(SessionData.trayPinnedItems), ["b"]);
    assert.deepEqual([handler.pin(""), handler.togglePin(""), handler.unpin("")], Array(3).fill("ERROR: No tray key specified"));
    assert.deepEqual(plain(SessionData.trayPinnedItems), ["b"]);
});
