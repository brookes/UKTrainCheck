import Toybox.Lang;
import Toybox.Test;

// Captures the onDataChanged callback so tests can assert it fired.
(:test)
class _Sink {
    var count as Number;
    function initialize() { count = 0; }
    function notify() as Void {
        count++;
    }
}

// --- Happy path: trains returned on first attempt ---

(:test)
function testHappyPathReturnsTrain(logger as Test.Logger) as Boolean {
    var mock = new MockWebRequester();
    mock.enqueue(200, {
        "trainServices" => [{ "std" => "14:35", "etd" => "On time" }]
    });

    var sink = new _Sink();
    var svc  = new TrainService(new Lang.Method(sink, :notify), mock);
    svc.request("WTY", "WAT", 2, null);

    Test.assertEqual(mock.callCount,         1);
    Test.assertEqual(sink.count,             1);
    Test.assert(!svc.isBusService());
    Test.assertEqual(svc.getTrains().size(), 1);

    var train = svc.getTrains()[0] as Train;
    Test.assertEqual(train.getExpected(), "14:35");
    Test.assertEqual(train.getActual(),   "On time");
    Test.assert(!train.isDelayed());
    return true;
}

// --- Bus fallback: no trainServices, retry finds busServices ---

(:test)
function testBusFallbackSetsBusServiceFlag(logger as Test.Logger) as Boolean {
    var mock = new MockWebRequester();
    // First call: filtered request, no trainServices
    mock.enqueue(200, { "areServicesAvailable" => true });
    // Second call: unfiltered retry, busServices present
    mock.enqueue(200, {
        "busServices" => [{ "std" => "10:00", "etd" => "10:15" }]
    });

    var sink = new _Sink();
    var svc  = new TrainService(new Lang.Method(sink, :notify), mock);
    svc.request("WTY", "WAT", 2, null);

    Test.assertEqual(mock.callCount,         2);
    Test.assertEqual(sink.count,             1);
    Test.assertEqual(svc.isBusService(),     true);
    Test.assertEqual(svc.getTrains().size(), 1);

    var train = svc.getTrains()[0] as Train;
    Test.assertEqual(train.getExpected(), "10:00");
    Test.assertEqual(train.getActual(),   "10:15");
    return true;
}

// --- No services at all: both attempts return nothing ---

(:test)
function testNoServicesReturnsEmptyTrains(logger as Test.Logger) as Boolean {
    var mock = new MockWebRequester();
    mock.enqueue(200, { "areServicesAvailable" => false });
    mock.enqueue(200, { "areServicesAvailable" => false });

    var sink = new _Sink();
    var svc  = new TrainService(new Lang.Method(sink, :notify), mock);
    svc.request("WTY", "WAT", 2, null);

    Test.assertEqual(mock.callCount,         2);
    Test.assertEqual(sink.count,             1);
    Test.assert(!svc.isBusService());
    Test.assertEqual(svc.getTrains().size(), 0);
    return true;
}

// --- HTTP error: non-200 clears trains and sets generic error message ---

(:test)
function testHttpErrorClearsTrains(logger as Test.Logger) as Boolean {
    var mock = new MockWebRequester();
    mock.enqueue(503, null);

    var sink = new _Sink();
    var svc  = new TrainService(new Lang.Method(sink, :notify), mock);
    svc.request("WTY", "WAT", 2, null);

    Test.assertEqual(mock.callCount,         1);   // no retry on HTTP error
    Test.assertEqual(sink.count,             1);
    Test.assertEqual(svc.getTrains().size(), 0);
    Test.assertEqual(svc.getError(),         "[Error 503]");
    return true;
}

// --- Error decoding: API message "Invalid crs code supplied" ---

(:test)
function testBadStopCodeError(logger as Test.Logger) as Boolean {
    var mock = new MockWebRequester();
    mock.enqueue(400, { "Message" => "Invalid crs code supplied" });

    var sink = new _Sink();
    var svc  = new TrainService(new Lang.Method(sink, :notify), mock);
    svc.request("XXX", "WAT", 2, null);

    Test.assertEqual(svc.getError(), "[Bad stop code]");
    return true;
}

// --- Error decoding: BLE_CONNECTION_UNAVAILABLE (-104) ---

(:test)
function testBleUnavailableError(logger as Test.Logger) as Boolean {
    var mock = new MockWebRequester();
    mock.enqueue(-104, null);   // Communications.BLE_CONNECTION_UNAVAILABLE

    var sink = new _Sink();
    var svc  = new TrainService(new Lang.Method(sink, :notify), mock);
    svc.request("WTY", "WAT", 2, null);

    Test.assertEqual(svc.getError(), "[No Bluetooth]");
    return true;
}

// --- Error decoding: NETWORK_REQUEST_TIMED_OUT (-300) ---

(:test)
function testNetworkTimeoutError(logger as Test.Logger) as Boolean {
    var mock = new MockWebRequester();
    mock.enqueue(-300, null);   // Communications.NETWORK_REQUEST_TIMED_OUT

    var sink = new _Sink();
    var svc  = new TrainService(new Lang.Method(sink, :notify), mock);
    svc.request("WTY", "WAT", 2, null);

    Test.assertEqual(svc.getError(), "[No Network]");
    return true;
}

// --- Parsing: missing std/etd keys fall back to "???" ---

(:test)
function testMissingKeysProducePlaceholder(logger as Test.Logger) as Boolean {
    var mock = new MockWebRequester();
    mock.enqueue(200, {
        "trainServices" => [{ "platform" => "2" }]   // no std or etd
    });

    var sink = new _Sink();
    var svc  = new TrainService(new Lang.Method(sink, :notify), mock);
    svc.request("WTY", "WAT", 2, null);

    var train = svc.getTrains()[0] as Train;
    Test.assertEqual(train.getExpected(), "???");
    Test.assertEqual(train.getActual(),   "???");
    return true;
}

// --- Multiple trains parsed in order from a realistic response ---

(:test)
function testParsesMultipleTrains(logger as Test.Logger) as Boolean {
    var mock = new MockWebRequester();
    mock.enqueue(200, {
        "generatedAt"        => "2026-03-02T05:46:37+00:00",
        "locationName"       => "Witley",
        "crs"                => "WTY",
        "areServicesAvailable" => true,
        // Only WTY->WAT trains (destination=WAT), as filterCrs=WAT would return
        "trainServices" => [
            { "std" => "06:04", "etd" => "On time", "platform" => "1", "operator" => "South Western Railway", "isCancelled" => false },
            { "std" => "06:43", "etd" => "On time", "platform" => "1", "operator" => "South Western Railway", "isCancelled" => false },
            { "std" => "07:10", "etd" => "07:18",   "platform" => "1", "operator" => "South Western Railway", "isCancelled" => false }
        ]
    });

    var sink = new _Sink();
    var svc  = new TrainService(new Lang.Method(sink, :notify), mock);
    svc.request("WTY", "WAT", 3, null);

    Test.assertEqual(svc.getTrains().size(), 3);

    var t0 = svc.getTrains()[0] as Train;
    Test.assertEqual(t0.getExpected(), "06:04");
    Test.assertEqual(t0.getActual(),   "On time");
    Test.assert(!t0.isDelayed());

    var t1 = svc.getTrains()[1] as Train;
    Test.assertEqual(t1.getExpected(), "06:43");
    Test.assert(!t1.isDelayed());

    var t2 = svc.getTrains()[2] as Train;
    Test.assertEqual(t2.getExpected(), "07:10");
    Test.assertEqual(t2.getActual(),   "07:18");
    Test.assertEqual(t2.isDelayed(),  true);

    return true;
}

// --- Destination CRS and platform are parsed onto the Train ---

(:test)
function testParsesDestinationAndPlatform(logger as Test.Logger) as Boolean {
    var mock = new MockWebRequester();
    mock.enqueue(200, {
        "trainServices" => [{
            "std"         => "06:04",
            "etd"         => "On time",
            "platform"    => "1",
            "destination" => [{ "locationName" => "London Waterloo", "crs" => "WAT" }]
        }]
    });

    var sink = new _Sink();
    var svc  = new TrainService(new Lang.Method(sink, :notify), mock);
    svc.request("WTY", "WAT", 2, null);

    var train = svc.getTrains()[0] as Train;
    Test.assertEqual(train.getDestination(), "WAT");
    Test.assertEqual(train.getPlatform(),    "1");
    return true;
}

// --- Missing destination/platform leave the Train details null ---

(:test)
function testMissingDetailsAreNull(logger as Test.Logger) as Boolean {
    var mock = new MockWebRequester();
    mock.enqueue(200, {
        "trainServices" => [{ "std" => "06:04", "etd" => "On time" }]
    });

    var sink = new _Sink();
    var svc  = new TrainService(new Lang.Method(sink, :notify), mock);
    svc.request("WTY", "WAT", 2, null);

    var train = svc.getTrains()[0] as Train;
    Test.assertEqual(train.getDestination(), null);
    Test.assertEqual(train.getPlatform(),    null);
    return true;
}

// --- First call URL contains the from CRS code ---

(:test)
function testRequestUrlContainsFromCrs(logger as Test.Logger) as Boolean {
    var mock = new MockWebRequester();
    mock.enqueue(200, { "trainServices" => [] as Array });

    var sink = new _Sink();
    var svc  = new TrainService(new Lang.Method(sink, :notify), mock);
    svc.request("WTY", "WAT", 2, null);

    var url = mock.lastUrl;
    Test.assertMessage(
        url.substring(url.length() - 3, null).equals("WTY"),
        "Expected URL to end with WTY, got: " + url
    );
    return true;
}
