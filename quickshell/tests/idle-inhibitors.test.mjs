import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const idle = loadScript(new URL("../Common/IdleInhibitors.js", import.meta.url));

test("ignore filter matches plain entries on class and regex entries on class or title", () => {
    const filter = "mpv, /kalshi/";
    const cases = [
        [{ appId: "MPV", title: "movie.mkv" }, true],
        [{ appId: "google-chrome", title: "Kalshi - Markets" }, true],
        [{ appId: "chrome-kalshi.com__-Default", title: "Markets" }, true],
        [{ appId: "google-chrome", title: "YouTube" }, false],
        [{ appId: "mpv-helper", title: "" }, false]
    ];
    for (const [window, ignored] of cases)
        assert.equal(idle.isWindowIgnored(window, filter), ignored, JSON.stringify(window));
});

test("an invalid regex entry ignores nothing", () => {
    assert.equal(idle.isWindowIgnored({ appId: "x", title: "x" }, "/[/"), false);
});

const plain = value => JSON.parse(JSON.stringify(value));
const base = { manual: false, screensaver: [], clients: [], compositorInhibited: false, windowInfo: true, filter: "", ignored: [] };
const summary = state => plain(idle.collect({ ...base, ...state }).map(e => `${e.key}:${e.address}:${e.active}`));


test("a D-Bus inhibitor is pinned to its caller's window only when the caller has exactly one", () => {
    const clients = [
        { address: "0xa", class: "mpv", title: "movie", pid: 10, workspace: { name: "3" } },
        { address: "0xb", class: "firefox", title: "one", pid: 20 },
        { address: "0xc", class: "firefox", title: "two", pid: 20 }
    ];
    const screensaver = [{ cookie: 1, appName: "mpv", reason: "Playing", pid: 10 }, { cookie: 2, appName: "firefox", reason: "Video", pid: 20 }];
    const entries = idle.collect({ ...base, clients, screensaver });
    assert.deepEqual(plain(entries.map(e => [e.key, e.appId, e.title, e.workspace, e.address])), [
        ["dbus:1", "mpv", "movie", "3", "0xa"],
        ["dbus:2", "firefox", "", "", ""]
    ]);
});

test("compositor inhibitors list the inhibiting windows, else an unknown entry unless the shell itself inhibits", () => {
    const clients = [{ address: "0xa", class: "google-chrome", title: "Kalshi", inhibitingIdle: true }, { address: "0xb", class: "kitty", inhibitingIdle: false }];
    assert.deepEqual(summary({ compositorInhibited: true, clients }), ["window:0xa:0xa:true"]);
    assert.deepEqual(summary({ compositorInhibited: true }), ["compositor::true"]);
    assert.deepEqual(summary({ compositorInhibited: true, manual: true }), ["manual::true"]);
    assert.deepEqual(summary({ compositorInhibited: true, screensaver: [{ cookie: 4, appName: "x" }] }), ["dbus:4::true"]);
    assert.deepEqual(summary({ compositorInhibited: true, screensaver: [{ cookie: 4, appName: "x" }], ignored: ["dbus:4"] }), ["dbus:4::false", "compositor::true"]);
});

test("switched-off and config-ignored inhibitors stay listed but inactive", () => {
    const clients = [{ address: "0xa", class: "google-chrome", title: "Kalshi", inhibitingIdle: true }, { address: "0xb", class: "mpv", title: "movie", inhibitingIdle: true }];
    assert.deepEqual(summary({ compositorInhibited: true, clients, filter: "/kalshi/", ignored: ["window:0xb"] }), ["window:0xa:0xa:false", "window:0xb:0xb:false"]);
});

test("with app inhibitors not respected only the manual one is active, and switches keep their state", () => {
    const clients = [{ address: "0xa", class: "google-chrome", title: "Kalshi", inhibitingIdle: true }];
    const entries = plain(idle.collect({ ...base, respect: false, manual: true, compositorInhibited: true, clients, screensaver: [{ cookie: 1, appName: "mpv" }], ignored: ["dbus:1"] }));
    assert.deepEqual(entries.map(e => [e.key, e.active, e.allowed]), [
        ["manual", true, true],
        ["dbus:1", false, false],
        ["window:0xa", false, true]
    ]);
});
