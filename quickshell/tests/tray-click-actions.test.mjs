import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const actions = loadScript(new URL("../Common/TrayClickActions.js", import.meta.url));
const plain = value => JSON.parse(JSON.stringify(value));
const defaults = { left: "menu", middle: "none", right: "activate" };

test("per-item overrides win over defaults, and invalid values fall through", () => {
    const overrides = { blueman: { left: "activate" }, bogus: { left: "explode" } };
    const cases = [
        ["blueman", "left", "activate"],
        ["blueman", "right", "activate"],
        ["nm-applet", "left", "menu"],
        ["bogus", "left", "menu"],
    ];
    for (const [id, button, expected] of cases)
        assert.equal(actions.resolve(id, false, button, defaults, overrides), expected, `${id} ${button}`);
    assert.equal(actions.resolve("x", false, "middle", { middle: "explode" }, {}), "secondaryActivate");
});

test("activate becomes the menu for ItemIsMenu items, other actions are kept", () => {
    assert.equal(actions.resolve("tailscale", true, "left", { left: "activate" }, {}), "menu");
    assert.equal(actions.resolve("tailscale", true, "middle", { middle: "secondaryActivate" }, {}), "secondaryActivate");
});

test("clearing the last override removes the item entry", () => {
    const set = actions.withOverride({}, "spotify", "left", "menu");
    assert.deepEqual(plain(set), { spotify: { left: "menu" } });
    assert.deepEqual(plain(actions.withOverride(set, "spotify", "left", "")), {});
});
