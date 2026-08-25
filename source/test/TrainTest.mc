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

(:test)
function testCancelledIsAbbreviated(logger as Test.Logger) as Boolean {
    var t = new Train("14:35", "Cancelled");
    Test.assertEqual(t.getActual(), "CNX");
    Test.assert(t.isDelayed());
    return true;
}

(:test)
function testDelayedIsAbbreviated(logger as Test.Logger) as Boolean {
    var t = new Train("14:35", "Delayed");
    Test.assertEqual(t.getActual(), "Delay");
    Test.assert(t.isDelayed());
    return true;
}

(:test)
function testCancelledRoundTrip(logger as Test.Logger) as Boolean {
    var t1 = new Train("14:35", "Cancelled");
    var t2 = Train.fromStorage(t1.toStorage());
    Test.assertEqual(t2.getExpected(), "14:35");
    Test.assertEqual(t2.getActual(),   "CNX");
    Test.assert(t2.isDelayed());
    return true;
}
