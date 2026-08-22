import Toybox.Lang;
import Toybox.Time;

using Toybox.Application.Properties;
using Toybox.Time.Gregorian;
using Toybox.WatchUi;

// Fetch enough rows to cover busy routes (e.g. 30 trains/hour * 1-hour lookback).
const FETCH_ROWS   = 60;
// Show trains from up to 60 minutes ago so quiet routes (1/hour) still show 1 past train.
const FETCH_OFFSET = -60;

class TrainViewModel {

    private var service_    as TrainService;
    private var stop1_      as String;
    private var stop2_      as String;
    private var outward_    as Boolean;
    private var switchHour_ as Number;
    private var offset_     as Number = 0;

    function initialize(stop1 as String, stop2 as String, switchHour as Number, requester as WebRequester) {
        stop1_      = stop1;
        stop2_      = stop2;
        switchHour_ = switchHour;
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        outward_ = (now.hour < switchHour_);
        service_ = new TrainService(method(:onDataChanged), requester);
    }

    function onSettingsChanged(stop1 as String, stop2 as String, switchHour as Number) as Void {
        stop1_      = stop1;
        stop2_      = stop2;
        switchHour_ = switchHour;
        refresh();
    }

    function refresh() as Void {
        offset_ = 0;
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        outward_ = (now.hour < switchHour_);
        var from = outward_ ? stop1_ : stop2_;
        var to   = outward_ ? stop2_ : stop1_;
        service_.request(from, to, FETCH_ROWS, FETCH_OFFSET);
    }

    function getOffset() as Number {
        return offset_;
    }

    function scrollDown() as Void {
        var max = service_.getTrains().size() - 1;
        if (offset_ < max) {
            offset_++;
            WatchUi.requestUpdate();
        }
    }

    function scrollUp() as Void {
        if (offset_ > 0) {
            offset_--;
            WatchUi.requestUpdate();
        }
    }

    function getTitle() as String {
        return _genTitle();
    }

    function getTrains() as Array<Train> {
        var all = service_.getTrains();
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var nowMinutes = now.hour * 60 + now.min;

        // Find the index of the first future train.
        var firstFuture = 0;
        while (firstFuture < all.size() && (all[firstFuture] as Train).isPast(nowMinutes)) {
            firstFuture++;
        }

        // Cap past trains to 3 — older ones aren't useful on screen.
        var pastStart = firstFuture > 3 ? firstFuture - 3 : 0;
        var size = all.size() - pastStart;
        var result = new Array<Train>[size];
        for (var i = 0; i < size; i++) {
            result[i] = all[pastStart + i] as Train;
        }
        return result;
    }

    // Display toggles — default true when the property is missing (older installs).
    function showDest()      as Boolean { return _boolProp("ShowDest");      }
    function showPlatform()  as Boolean { return _boolProp("ShowPlatform");  }
    function showCountdown() as Boolean { return _boolProp("ShowCountdown"); }

    private function _boolProp(key as String) as Boolean {
        var v = Properties.getValue(key);
        return v == null ? true : v as Boolean;
    }

    function isPending() as Boolean {
        return service_.isPending();
    }

    function isBusService() as Boolean {
        return service_.isBusService();
    }

    function getError() as String or Null {
        return service_.getError();
    }

    function onDataChanged() as Void {
        WatchUi.requestUpdate();
    }

    private function _genTitle() as String {
        if (outward_) {
            return stop1_ + " -> " + stop2_;
        }
        return stop2_ + " -> " + stop1_;
    }
}
