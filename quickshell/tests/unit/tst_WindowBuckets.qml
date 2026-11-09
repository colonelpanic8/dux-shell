import QtQuick
import QtTest
import "../../Common/WindowBuckets.js" as WindowBuckets

TestCase {
    name: "WindowBuckets"

    function test_minimizedPopsOutWhileScratchpadsStay() {
        const placed = WindowBuckets.placements(WindowBuckets.moved({}, {}, "minimized"), {});
        compare(WindowBuckets.hosted("dock", placed, true, true).join(","), "minimized");
        compare(WindowBuckets.hosted("bar", placed, true, true).join(","), "scratchpad");
    }
}
