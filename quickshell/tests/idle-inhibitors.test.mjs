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

test("only clients reporting inhibitingIdle are returned", () => {
    const windows = idle.inhibitingWindows([{ address: "0x1", class: "google-chrome", title: "Kalshi", inhibitingIdle: true }, { address: "0x2", class: "kitty", title: "zsh", inhibitingIdle: false }, null]);
    assert.deepEqual(JSON.parse(JSON.stringify(windows)), [{ address: "0x1", appId: "google-chrome", title: "Kalshi" }]);
});
