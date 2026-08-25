import Toybox.Lang;
import Toybox.Test;

// The clock decides the initial direction, so these tests never assert an
// absolute direction — only that a manual swap changes it and that a later
// refresh leaves it alone.

// Helpers live on a class rather than at file scope: the runner collects every
// (:test) function as a test case, whatever its signature.
(:test)
class _Vm {
    // An empty trainServices array keeps TrainService to a single call — the bus
    // fallback only fires when the key is missing altogether.
    static function enqueueEmpty(mock as MockWebRequester) as Void {
        mock.enqueue(200, { "trainServices" => [] as Array });
    }

    static function lastCrs(mock as MockWebRequester) as String {
        var url = mock.lastUrl;
        return url.substring(url.length() - 3, url.length());
    }
}

// --- Toggling swaps the title ---

// Leg 2 is left unset so the cycle is just the two leg-1 directions, whatever
// the clock says. testToggleCyclesThroughBothLegs covers the two-leg case.
(:test)
function testToggleDirectionSwapsTitle(logger as Test.Logger) as Boolean {
    var mock = new MockWebRequester();
    var vm   = new TrainViewModel("AAA", "BBB", "", "", 12, mock);

    var before = vm.getTitle();
    _Vm.enqueueEmpty(mock);
    vm.toggleDirection();
    var after = vm.getTitle();

    Test.assertMessage(!before.equals(after), "Title unchanged after toggle: " + before);
    Test.assert(before.equals("AAA > BBB") || before.equals("BBB > AAA"));
    Test.assert(after.equals("AAA > BBB")  || after.equals("BBB > AAA"));
    return true;
}

// --- Toggling walks all four routes, in the order the clock dictates ---
//
// The test can't set the clock, so it pins both orderings and requires the run
// to match one of them exactly: mornings go out-first from leg 1, afternoons
// run the same journeys backwards starting on the far return.
(:test)
function testToggleCyclesThroughBothLegs(logger as Test.Logger) as Boolean {
    var mock = new MockWebRequester();
    var vm   = new TrainViewModel("AAA", "BBB", "CCC", "DDD", 12, mock);

    _Vm.enqueueEmpty(mock);
    vm.refresh();

    // Five titles: the four steps, then the wrap back to the first.
    var seen = [ vm.getTitle() ] as Array<String>;
    for (var i = 0; i < 4; i++) {
        _Vm.enqueueEmpty(mock);
        vm.toggleDirection();
        seen.add(vm.getTitle());
    }

    var morning   = [ "AAA > BBB", "BBB > AAA", "CCC > DDD", "DDD > CCC", "AAA > BBB" ] as Array<String>;
    var afternoon = [ "DDD > CCC", "CCC > DDD", "BBB > AAA", "AAA > BBB", "DDD > CCC" ] as Array<String>;

    var wanted = seen[0].equals(morning[0]) ? morning : afternoon;
    for (var i = 0; i < wanted.size(); i++) {
        Test.assertMessage(seen[i].equals(wanted[i]),
            "Step " + i + " was " + seen[i] + ", expected " + wanted[i]
            + " (full run: " + seen.toString() + ")");
    }
    return true;
}

// --- With leg 2 unset the toggle stays on leg 1 ---

(:test)
function testToggleStaysOnLegOneWhenLegTwoUnset(logger as Test.Logger) as Boolean {
    var mock = new MockWebRequester();
    var vm   = new TrainViewModel("AAA", "BBB", "", "", 12, mock);

    _Vm.enqueueEmpty(mock);
    vm.refresh();

    for (var i = 0; i < 4; i++) {
        var title = vm.getTitle();
        Test.assertMessage(title.equals("AAA > BBB") || title.equals("BBB > AAA"),
            "Left leg 1 with no leg 2 configured: " + title);
        _Vm.enqueueEmpty(mock);
        vm.toggleDirection();
    }
    return true;
}

// --- An install predating leg 2 hands back null, not a blank string ---
//
// Properties.getValue() returns null for a key the stored settings have never
// held, and a sideloaded install keeps its own settings file — so upgrading to
// a build that adds Stop3/Stop4 delivers null here. That must read as "no leg
// 2" rather than throwing on a method call against null.
(:test)
function testNullLegTwoBehavesAsUnset(logger as Test.Logger) as Boolean {
    var mock = new MockWebRequester();
    var vm   = new TrainViewModel("AAA", "BBB", null, null, 12, mock);

    _Vm.enqueueEmpty(mock);
    vm.refresh();

    for (var i = 0; i < 4; i++) {
        var title = vm.getTitle();
        Test.assertMessage(title.equals("AAA > BBB") || title.equals("BBB > AAA"),
            "Null leg 2 should stay on leg 1, got " + title);
        _Vm.enqueueEmpty(mock);
        vm.toggleDirection();
    }
    return true;
}

// --- Toggling asks the API for the other station ---

(:test)
function testToggleDirectionSwapsRequestedStation(logger as Test.Logger) as Boolean {
    var mock = new MockWebRequester();
    var vm   = new TrainViewModel("AAA", "BBB", "", "", 12, mock);

    _Vm.enqueueEmpty(mock);
    vm.refresh();
    var first = _Vm.lastCrs(mock);

    _Vm.enqueueEmpty(mock);
    vm.toggleDirection();
    var second = _Vm.lastCrs(mock);

    Test.assertMessage(!first.equals(second), "Both requests used " + first);
    Test.assert(first.equals("AAA")  || first.equals("BBB"));
    Test.assert(second.equals("AAA") || second.equals("BBB"));
    return true;
}

// --- A refresh must not undo a manual swap ---

(:test)
function testRefreshKeepsManualDirection(logger as Test.Logger) as Boolean {
    var mock = new MockWebRequester();
    var vm   = new TrainViewModel("AAA", "BBB", "CCC", "DDD", 12, mock);

    _Vm.enqueueEmpty(mock);
    vm.refresh();
    var fromClock = vm.isOutward();

    _Vm.enqueueEmpty(mock);
    vm.toggleDirection();
    Test.assertMessage(vm.isOutward() != fromClock, "Toggle didn't change direction");

    _Vm.enqueueEmpty(mock);
    vm.refresh();
    Test.assertMessage(vm.isOutward() != fromClock, "refresh() reverted the manual swap");
    return true;
}

// --- Changing stations drops the override and follows the clock again ---

(:test)
function testSettingsChangeClearsManualDirection(logger as Test.Logger) as Boolean {
    var mock = new MockWebRequester();
    var vm   = new TrainViewModel("AAA", "BBB", "CCC", "DDD", 12, mock);

    _Vm.enqueueEmpty(mock);
    vm.refresh();
    var fromClock = vm.isOutward();

    _Vm.enqueueEmpty(mock);
    vm.toggleDirection();

    _Vm.enqueueEmpty(mock);
    vm.onSettingsChanged("CCC", "DDD", "EEE", "FFF", 12);
    Test.assertMessage(vm.isOutward() == fromClock, "Settings change kept the stale override");
    return true;
}

// --- Scroll position resets so a swap doesn't land mid-list ---

(:test)
function testToggleDirectionResetsScroll(logger as Test.Logger) as Boolean {
    var mock = new MockWebRequester();
    var vm   = new TrainViewModel("AAA", "BBB", "CCC", "DDD", 12, mock);

    mock.enqueue(200, {
        "trainServices" => [
            { "std" => "06:04", "etd" => "On time" },
            { "std" => "06:34", "etd" => "On time" },
            { "std" => "07:04", "etd" => "On time" }
        ]
    });
    vm.refresh();
    vm.scrollDown();
    Test.assertEqual(vm.getOffset(), 1);

    _Vm.enqueueEmpty(mock);
    vm.toggleDirection();
    Test.assertEqual(vm.getOffset(), 0);
    return true;
}

// --- Scrolling stops inside the list the view actually draws ---
//
// getTrains() keeps only the 3 most recent past trains, so it can be shorter
// than the raw service list. Bounding on the raw size let the offset run past
// the end, leaving the view with nothing to draw. Times below straddle the
// whole day so some are past whatever the clock says, which is what triggers
// the trim; the assertion is derived from the trimmed size, so it holds at any
// time of day.
(:test)
function testScrollStopsWithinTrimmedList(logger as Test.Logger) as Boolean {
    var times = ["00:00", "00:05", "00:10", "00:15", "00:20", "00:25",
                 "12:00", "23:40", "23:45", "23:50", "23:55"];
    var svcs = [] as Array;
    for (var i = 0; i < times.size(); i++) {
        svcs.add({ "std" => times[i], "etd" => "On time" });
    }

    var mock = new MockWebRequester();
    var vm   = new TrainViewModel("AAA", "BBB", "CCC", "DDD", 12, mock);
    mock.enqueue(200, { "trainServices" => svcs });
    vm.refresh();
    vm.setVisibleRows(3);

    for (var i = 0; i < 50; i++) { vm.scrollDown(); }

    var n         = vm.getTrains().size();
    var maxOffset = n > 3 ? n - 3 : 0;
    Test.assertMessage(vm.getOffset() == maxOffset,
        "offset " + vm.getOffset() + " should have stopped at " + maxOffset + " for " + n + " rows");
    // The last page is full: there is always something left to draw.
    Test.assert(n - vm.getOffset() > 0);
    return true;
}

// --- Scrolling back up returns to the top and stops there ---

(:test)
function testScrollUpStopsAtTop(logger as Test.Logger) as Boolean {
    var mock = new MockWebRequester();
    var vm   = new TrainViewModel("AAA", "BBB", "CCC", "DDD", 12, mock);
    mock.enqueue(200, {
        "trainServices" => [
            { "std" => "06:04", "etd" => "On time" },
            { "std" => "06:34", "etd" => "On time" },
            { "std" => "07:04", "etd" => "On time" }
        ]
    });
    vm.refresh();
    vm.setVisibleRows(1);

    vm.scrollDown();
    vm.scrollDown();
    Test.assertEqual(vm.getOffset(), 2);

    for (var i = 0; i < 5; i++) { vm.scrollUp(); }
    Test.assertEqual(vm.getOffset(), 0);
    return true;
}
