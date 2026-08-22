import Toybox.Lang;
import Toybox.Test;

(:test)
function testOnTimeString(logger as Test.Logger) as Boolean {
    var t = new Train("14:35", "On time");
    Test.assertEqual(t.getExpected(), "14:35");
    Test.assertEqual(t.getActual(),   "On time");
    Test.assert(!t.isDelayed());
    return true;
}

(:test)
function testExpectedMatchingActualIsOnTime(logger as Test.Logger) as Boolean {
    var t = new Train("14:35", "14:35");
    Test.assertEqual(t.getActual(),  "On time");
    Test.assert(!t.isDelayed());
    return true;
}

(:test)
function testDelayed(logger as Test.Logger) as Boolean {
    var t = new Train("14:35", "14:52");
    Test.assertEqual(t.getActual(),  "14:52");
    Test.assertEqual(t.isDelayed(), true);
    return true;
}

(:test)
function testStorageRoundTrip(logger as Test.Logger) as Boolean {
    var t1 = new Train("14:35", "14:52");
    var t2 = Train.fromStorage(t1.toStorage());
    Test.assertEqual(t2.getExpected(), "14:35");
    Test.assertEqual(t2.getActual(),   "14:52");
    return true;
}

(:test)
function testOnTimeRoundTrip(logger as Test.Logger) as Boolean {
    var t1 = new Train("14:35", "On time");
    var t2 = Train.fromStorage(t1.toStorage());
    Test.assertEqual(t2.getExpected(), "14:35");
    Test.assertEqual(t2.getActual(),   "On time");
    Test.assert(!t2.isDelayed());
    return true;
}

// --- Delay in minutes ---

(:test)
function testDelayMinutes(logger as Test.Logger) as Boolean {
    Test.assertEqual(new Train("14:35", "14:52").delayMinutes(), 17);
    // On time and non-time statuses have no numeric delay.
    Test.assertEqual(new Train("14:35", "On time").delayMinutes(), null);
    Test.assertEqual(new Train("14:35", "Cancelled").delayMinutes(), null);
    return true;
}

// --- Countdown uses the delayed time when the train is late ---

(:test)
function testMinutesUntil(logger as Test.Logger) as Boolean {
    var now = 14 * 60 + 30;   // 14:30
    // On time: counts to 14:35.
    Test.assertEqual(new Train("14:35", "On time").minutesUntil(now), 5);
    // Delayed to 14:52: counts to the actual time, not the scheduled one.
    Test.assertEqual(new Train("14:35", "14:52").minutesUntil(now), 22);
    // Already departed: negative.
    Test.assertEqual(new Train("14:20", "On time").minutesUntil(now), -10);
    return true;
}

// --- Full-view detail label composition ---

(:test)
function testDetailLabelAllParts(logger as Test.Logger) as Boolean {
    var now = 14 * 60 + 30;   // 14:30
    var t = new Train("14:35", "14:52");
    t.setDetails("WAT", "2");
    // scheduled, dest, platform, +delay, countdown-to-actual
    Test.assertEqual(t.detailLabel(now, true, true, true), "14:35 WAT p2 +17 (22m)");
    return true;
}

(:test)
function testDetailLabelOnTimeOmitsDelay(logger as Test.Logger) as Boolean {
    var now = 14 * 60 + 30;
    var t = new Train("14:35", "On time");
    t.setDetails("WAT", "2");
    Test.assertEqual(t.detailLabel(now, true, true, true), "14:35 WAT p2 (5m)");
    return true;
}

(:test)
function testDetailLabelTogglesOff(logger as Test.Logger) as Boolean {
    var now = 14 * 60 + 30;
    var t = new Train("14:35", "On time");
    t.setDetails("WAT", "2");
    Test.assertEqual(t.detailLabel(now, false, false, false), "14:35");
    return true;
}

(:test)
function testDetailLabelPastOmitsCountdownKeepsDelay(logger as Test.Logger) as Boolean {
    var now = 15 * 60;        // 15:00, after the train has gone
    var t = new Train("14:35", "14:52");
    t.setDetails("WAT", "2");
    // No "(Nm)" once departed, but the "+17" is still useful.
    Test.assertEqual(t.detailLabel(now, true, true, true), "14:35 WAT p2 +17");
    return true;
}

(:test)
function testDetailLabelMissingDetailsSkipped(logger as Test.Logger) as Boolean {
    var now = 14 * 60 + 30;
    var t = new Train("14:35", "On time");   // no setDetails call
    Test.assertEqual(t.detailLabel(now, true, true, true), "14:35 (5m)");
    return true;
}

// --- Glance label leaves out route detail ---

(:test)
function testGlanceLabel(logger as Test.Logger) as Boolean {
    var now = 14 * 60 + 30;
    Test.assertEqual(new Train("14:35", "On time").glanceLabel(now), "14:35  5m");
    Test.assertEqual(new Train("14:35", "14:52").glanceLabel(now),   "14:35 +17  22m");
    return true;
}
