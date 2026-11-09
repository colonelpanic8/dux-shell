import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const order = loadScript(new URL("../Common/TrayOrder.js", import.meta.url));

const item = (name, id, watcherAddress, title = "") => ({ name, id, watcherAddress, title });
const priorities = { alpha: 2, delta: -1 };
const sortNames = (items, savedOrder = []) => [...order.sorted(items, it => priorities[it.name] ?? 0, savedOrder, it => it.id)].map(it => it.name);

function permutations(list) {
    if (list.length <= 1)
        return [list];
    return list.flatMap((first, i) => permutations([...list.slice(0, i), ...list.slice(i + 1)]).map(rest => [first, ...rest]));
}

const tray = [
    item("alpha", "alpha", "org.kde.StatusNotifierItem-4100-1"),
    item("bravo", "bravo", ":1.41/org/ayatana/NotificationItem/bravo"),
    item("chrome-work", "chrome_status_icon_1", ":1.1364", "Work"),
    item("chrome-home", "chrome_status_icon_1", ":1.1201", "Home"),
    item("gmail", "", "org.Gmail.Notifications"),
    item("github", "", "org.Github.Notifications"),
    item("delta", "delta", "org.kde.StatusNotifierItem-977-1")
];

test("every registration order renders the same tray", () => {
    const expected = ["alpha", "bravo", "chrome-home", "chrome-work", "github", "gmail", "delta"];
    for (const registered of permutations(tray))
        assert.deepEqual(sortNames(registered), expected, registered.map(it => it.name).join(" "));
});

test("an app that registers again under a new bus name keeps its slot", () => {
    const zed = item("zed", "", ":1.50/org/zed/StatusNotifierItem");
    const ant = item("ant", "", ":1.51/org/ant/StatusNotifierItem");
    const sync = item("sync", "", "org.kde.StatusNotifierItem-1978-2", "sync");
    const backup = item("backup", "", "org.kde.StatusNotifierItem-2210-1", "backup");
    assert.deepEqual(sortNames([zed, ant, sync, backup]), ["ant", "zed", "backup", "sync"]);
    const zedAgain = item("zed", "", ":1.97/org/zed/StatusNotifierItem");
    const syncAgain = item("sync", "", "org.kde.StatusNotifierItem-3001-1", "sync");
    assert.deepEqual(sortNames([ant, backup, zedAgain, syncAgain]), ["ant", "zed", "backup", "sync"]);
});

test("priority outranks the saved order, which outranks identity", () => {
    const registered = [tray[6], tray[4], tray[5], tray[1], tray[0]];
    assert.deepEqual(sortNames(registered, ["delta", "bravo"]), ["alpha", "bravo", "github", "gmail", "delta"]);
});
