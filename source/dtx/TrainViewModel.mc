import Toybox.Lang;
import Toybox.Time;

using Toybox.Application.Properties;
using Toybox.Time.Gregorian;
using Toybox.WatchUi;

// Filtering to trains that call at the far station cuts the board right down,
// so 30 covers even a busy route across the window below.
const FETCH_ROWS   = 30;
// Darwin serves a 120-minute window starting at timeOffset, and caps timeWindow
// at 120 however much you ask for — so lookback and lookahead trade directly
// against each other. -45 keeps 45 minutes of already-departed trains and leaves
// 75 minutes ahead. Move it towards 0 for more lookahead, away for more history.
const FETCH_OFFSET = -45;

class TrainViewModel {

    private var service_    as TrainService;
    private var stop1_      as String;
    private var stop2_      as String;
    // Leg 2 is optional. An install that predates these properties has no value
    // stored for them, so the API hands back null rather than the built-in
    // default — treated here the same as blank: leg 2 simply doesn't exist.
    private var stop3_      as String or Null;
    private var stop4_      as String or Null;
    // Position in the cycle below. Leg and direction are both read off it, so
    // there is only ever one thing to move.
    private var step_       as Number;
    private var switchHour_ as Number;
    private var offset_     as Number = 0;
    // How many rows the view can draw; set by the view on each redraw.
    private var visibleRows_ as Number = 1;
    // Set once the user swaps direction by hand. Widgets are short-lived, so the
    // choice deliberately lasts only until this one is closed — reopening it
    // goes back to following the clock.
    private var manualSelection_ as Boolean = false;

    function initialize(stop1 as String, stop2 as String, stop3 as String or Null, stop4 as String or Null, switchHour as Number, requester as WebRequester) {
        stop1_      = stop1;
        stop2_      = stop2;
        stop3_      = stop3;
        stop4_      = stop4;
        switchHour_ = switchHour;
        step_       = _clockStep();
        service_ = new TrainService(method(:onDataChanged), requester);
    }

    function onSettingsChanged(stop1 as String, stop2 as String, stop3 as String or Null, stop4 as String or Null, switchHour as Number) as Void {
        stop1_      = stop1;
        stop2_      = stop2;
        stop3_      = stop3;
        stop4_      = stop4;
        switchHour_ = switchHour;
        // New stations mean the old manual choice no longer means anything.
        manualSelection_ = false;
        refresh();
    }

    // Blank or absent either side means there is no second journey to show.
    private function _hasLeg2() as Boolean {
        return stop3_ != null && (stop3_ as String).length() > 0
            && stop4_ != null && (stop4_ as String).length() > 0;
    }

    // The cycle runs outbound-first through both legs:
    //
    //   0  stop1 > stop2     leg 1 out
    //   1  stop2 > stop1     leg 1 back
    //   2  stop3 > stop4     leg 2 out
    //   3  stop4 > stop3     leg 2 back
    //
    // Mornings walk it forwards from 0. Afternoons are the same journeys in
    // reverse, so they walk it backwards from the end — starting on the far
    // return, which is the train you actually want after the switch hour.
    // Without a leg 2 the cycle is just steps 0 and 1, and the same rule leaves
    // the afternoon starting on step 1, the way it did before leg 2 existed.
    private function _steps() as Number {
        return _hasLeg2() ? 4 : 2;
    }

    private function _forwards() as Boolean {
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return now.hour < switchHour_;
    }

    private function _clockStep() as Number {
        return _forwards() ? 0 : _steps() - 1;
    }

    function refresh() as Void {
        offset_ = 0;
        // A manual selection wins over the clock, so a refresh doesn't undo it.
        if (!manualSelection_) {
            step_ = _clockStep();
        }
        _request();
    }

    // Move one place along the cycle and reload. Sticks until the widget closes.
    function toggleDirection() as Void {
        var n = _steps();
        // Guards the step a shrinking cycle leaves out of range: dropping leg 2
        // in settings clears the manual flag, but a stale step must not survive
        // to index a station that is no longer there.
        if (step_ >= n) { step_ = n - 1; }
        step_ = _forwards() ? (step_ + 1) % n : (step_ + n - 1) % n;

        manualSelection_ = true;
        offset_          = 0;
        _request();
    }

    function isOutward() as Boolean { return (step_ % 2) == 0; }

    private function _isLeg1() as Boolean { return step_ < 2; }

    private function _request() as Void {
        var from;
        var to;

        if (_isLeg1()) {
            from = isOutward() ? stop1_ : stop2_;
            to   = isOutward() ? stop2_ : stop1_;
        } else {
            from = isOutward() ? stop3_ : stop4_;
            to   = isOutward() ? stop4_ : stop3_;
        }
        service_.request(from, to, FETCH_ROWS, FETCH_OFFSET);
    }

    function getOffset() as Number {
        return offset_;
    }

    // The view reports how many rows it can draw, so scrolling stops with the
    // last page full instead of trailing off to a single row.
    function setVisibleRows(rows as Number) as Void {
        visibleRows_ = rows > 0 ? rows : 1;
    }

    function scrollDown() as Void {
        // Bound on the list the view actually draws, not the raw service list —
        // getTrains() drops past trains beyond the most recent 3, so the raw
        // size let the offset run past the end and blank the screen.
        var max = getTrains().size() - visibleRows_;
        if (max < 0) { max = 0; }
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
        if (_isLeg1()) {
            return isOutward() ? stop1_ + " > " + stop2_
                               : stop2_ + " > " + stop1_;
        }
        return isOutward() ? stop3_ + " > " + stop4_
                           : stop4_ + " > " + stop3_;
    }
}
