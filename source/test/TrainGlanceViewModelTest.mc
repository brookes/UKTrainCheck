import Toybox.Lang;
import Toybox.Test;

using Toybox.Application.Properties;

// The glance has no controls: it shows whichever journey the widget would open
// on, and nothing else. That agreement is the whole contract, and it is what
// broke once — the glance opened on leg 2 outbound while the widget opened on
// leg 2's return — so most of these tests assert the two agree rather than
// asserting a direction outright. The clock decides which journey that is and
// the tests can't set it, so pinning an absolute direction would only pass for
// half the day.

(:test)
class _Glance {
    // Properties are process-wide in the test runner, so every test sets all
    // four stops rather than inheriting whatever ran before it.
    static function configure(stop1 as String, stop2 as String,
                              stop3 as String or Null, stop4 as String or Null,
                              switchHour as Number) as Void {
        Properties.setValue("Stop1", stop1);
        Properties.setValue("Stop2", stop2);
        Properties.setValue("Stop3", stop3);
        Properties.setValue("Stop4", stop4);
        Properties.setValue("SwitchHour", switchHour);
    }

    static function enqueueEmpty(mock as MockWebRequester) as Void {
        mock.enqueue(200, { "trainServices" => [] as Array });
    }

    // The title the widget opens on, for the same stops and switch hour.
    static function widgetOpeningTitle(stop1 as String, stop2 as String,
                                       stop3 as String or Null, stop4 as String or Null,
                                       switchHour as Number) as String {
        var mock = new MockWebRequester();
        var vm   = new TrainViewModel(stop1, stop2, stop3, stop4, switchHour, mock);
        enqueueEmpty(mock);
        vm.refresh();
        return vm.getTitle();
    }

    static function openGlance(mock as MockWebRequester) as TrainGlanceViewModel {
        var vm = new TrainGlanceViewModel(mock);
        enqueueEmpty(mock);
        vm.refresh();
        return vm;
    }
}

// --- The glance opens on the journey the widget opens on ---
//
// This is the regression test. With two legs configured the afternoon opens on
// leg 2's return, and the glance used to show leg 2 outbound instead.

(:test)
function testGlanceOpensWhereTheWidgetDoes(logger as Test.Logger) as Boolean {
    _Glance.configure("AAA", "BBB", "CCC", "DDD", 12);
    var expected = _Glance.widgetOpeningTitle("AAA", "BBB", "CCC", "DDD", 12);

    var mock = new MockWebRequester();
    var vm   = _Glance.openGlance(mock);

    Test.assertMessage(vm.getTitle().equals(expected),
        "Glance showed " + vm.getTitle() + " but the widget opens on " + expected);
    return true;
}

// --- ...and does so with only one leg configured too ---

(:test)
function testGlanceOpensWhereTheWidgetDoesWithOneLeg(logger as Test.Logger) as Boolean {
    _Glance.configure("AAA", "BBB", "", "", 12);
    var expected = _Glance.widgetOpeningTitle("AAA", "BBB", "", "", 12);

    var mock = new MockWebRequester();
    var vm   = _Glance.openGlance(mock);

    Test.assertMessage(vm.getTitle().equals(expected),
        "Glance showed " + vm.getTitle() + " but the widget opens on " + expected);
    return true;
}

// --- The station it asks the API for matches the one it displays ---
//
// Title and request are built separately, so a glance can look right while
// fetching the wrong board. The heading's first code is the origin.

(:test)
function testGlanceRequestsTheStationItShows(logger as Test.Logger) as Boolean {
    _Glance.configure("AAA", "BBB", "CCC", "DDD", 12);

    var mock = new MockWebRequester();
    var vm   = _Glance.openGlance(mock);

    var shownOrigin = vm.getTitle().substring(0, 3);
    var url         = mock.lastUrl;
    var asked       = url.substring(url.length() - 3, url.length());

    Test.assertMessage(asked.equals(shownOrigin),
        "Heading reads " + vm.getTitle() + " but the request was for " + asked);
    return true;
}

// --- A blank leg 2 keeps the glance on leg 1 ---

(:test)
function testGlanceStaysOnLegOneWhenLegTwoBlank(logger as Test.Logger) as Boolean {
    _Glance.configure("AAA", "BBB", "", "", 12);

    var mock = new MockWebRequester();
    var vm   = _Glance.openGlance(mock);

    var title = vm.getTitle();
    Test.assertMessage(title.equals(_Vm.route("AAA", "BBB")) || title.equals(_Vm.route("BBB", "AAA")),
        "Blank leg 2 should leave the glance on leg 1, got " + title);
    return true;
}

// --- An install predating leg 2 stores null, not a blank string ---

(:test)
function testGlanceNullLegTwoBehavesAsUnset(logger as Test.Logger) as Boolean {
    _Glance.configure("AAA", "BBB", null, null, 12);

    var mock = new MockWebRequester();
    var vm   = _Glance.openGlance(mock);

    var title = vm.getTitle();
    Test.assertMessage(title.equals(_Vm.route("AAA", "BBB")) || title.equals(_Vm.route("BBB", "AAA")),
        "Null leg 2 should leave the glance on leg 1, got " + title);
    return true;
}

// --- The caption is the next departure ---

(:test)
function testGlanceCaptionShowsNextDeparture(logger as Test.Logger) as Boolean {
    _Glance.configure("AAA", "BBB", "CCC", "DDD", 12);

    var mock = new MockWebRequester();
    var vm   = new TrainGlanceViewModel(mock);
    mock.enqueue(200, {
        "trainServices" => [
            { "std" => "06:04", "etd" => "On time" },
            { "std" => "06:34", "etd" => "On time" }
        ]
    });
    vm.refresh();

    var train = vm.getNextTrain();
    Test.assertMessage(train != null, "No train exposed for the view to colour");
    Test.assertEqual((train as Train).getExpected(), "06:04");
    // The caption is that same train, so the view can't colour one departure
    // while captioning another.
    Test.assertMessage(vm.getCaption().find("06:04") != null,
        "Caption " + vm.getCaption() + " doesn't describe the next train");
    return true;
}

// --- An empty board captions as status text, with no train to colour ---

(:test)
function testGlanceEmptyBoardHasNoTrain(logger as Test.Logger) as Boolean {
    _Glance.configure("AAA", "BBB", "CCC", "DDD", 12);

    var mock = new MockWebRequester();
    var vm   = _Glance.openGlance(mock);

    Test.assertMessage(vm.getNextTrain() == null,
        "Empty board should expose no train to colour");
    // Status text, not a departure — the view keys its colour off getNextTrain().
    Test.assertMessage(vm.getCaption().find("[") != null,
        "Expected bracketed status text, got " + vm.getCaption());
    return true;
}
