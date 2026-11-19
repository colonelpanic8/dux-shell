import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const trayKey = loadScript(new URL("../Common/TrayItemKey.js", import.meta.url));

const github = { id: "", watcherAddress: "org.Github.Notifications", icon: "image://icon/github" };
const gmail = { id: "", watcherAddress: "org.Gmail.Notifications", icon: "image://icon/gmail" };
const gitea = { id: "", watcherAddress: "org.Gitea.Notifications", icon: "image://icon/gitea" };

test("baseKey prefers the id, then a well-known bus name, then the theme icon name", () => {
    const cases = [
        [{ id: "git-sync-rs", watcherAddress: "org.kde.StatusNotifierItem-1978-2", icon: "image://icon/git-sync" }, "git-sync-rs"],
        [{ id: "nm-applet", watcherAddress: ":1.41/org/ayatana/NotificationItem/nm_applet", icon: "image://icon/nm-signal-75" }, "nm-applet"],
        [github, "org.Github.Notifications"],
        [gmail, "org.Gmail.Notifications"],
        [gitea, "org.Gitea.Notifications"],
        [{ id: "", watcherAddress: "org.Example.Tray/StatusNotifierItem", icon: "" }, "org.Example.Tray"],
        [{ id: "", watcherAddress: "org.Example.Tray/org/example/Item/2", icon: "" }, "org.Example.Tray/org/example/Item/2"],
        [{ id: "", watcherAddress: ":1.93/org/blueman/sni", icon: "image://icon/blueman-tray" }, "icon:blueman-tray"],
        [{ id: "", watcherAddress: "org.kde.StatusNotifierItem-959731-1", icon: "image://icon/steam?path=/opt/steam/icons" }, "icon:steam"],
        [{ id: "", watcherAddress: "org.freedesktop.StatusNotifierItem-4187542-1", icon: "image://icon/discord" }, "icon:discord"],
        [{ id: "", watcherAddress: ":1.103", icon: "image://service.sni/:1.103/0" }, ""],
    ];
    for (const [item, expected] of cases)
        assert.equal(trayKey.baseKey(item), expected, item.watcherAddress);
});

test("assign gives each id-less notifier its own key and numbers true duplicates", () => {
    const sameIconA = { id: "", watcherAddress: ":1.200", icon: "image://icon/chat" };
    const sameIconB = { id: "", watcherAddress: ":1.201", icon: "image://icon/chat" };
    const dupA = { id: "app", watcherAddress: ":1.300", icon: "" };
    const dupB = { id: "app", watcherAddress: ":1.301", icon: "" };
    const pool = [github, gmail, gitea, sameIconA, sameIconB, dupA, dupB];
    const keys = new Map();
    assert.deepEqual(pool.map(item => trayKey.assign(item, pool, keys)), ["org.Github.Notifications", "org.Gmail.Notifications", "org.Gitea.Notifications", "icon:chat", "icon:chat::1", "app", "app::1"]);
    assert.equal(trayKey.assign(sameIconB, [sameIconB], keys), "icon:chat::1");
});

test("assign re-keys an item whose id loads after its first key, but not when only its icon changes", () => {
    const late = { id: "", watcherAddress: "org.kde.StatusNotifierItem-11-1", icon: "image://icon/net-0" };
    const keys = new Map();
    assert.equal(trayKey.assign(late, [late], keys), "icon:net-0");
    late.icon = "image://icon/net-75";
    assert.equal(trayKey.assign(late, [late], keys), "icon:net-0");
    late.id = "nm-applet";
    assert.equal(trayKey.assign(late, [late], keys), "nm-applet");
});
