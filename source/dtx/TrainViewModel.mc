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
    private var stop3_      as String;
    private var stop4_      as String;
    private var currentLeg_ as Number;   // 1 or 2
    private var outward_    as Boolean;
    private var switchHour_ as Number;
    private var offset_     as Number = 0;
    // How many rows the view can draw; set by the view on each redraw.
    private var visibleRows_ as Number = 1;
    // Set once the user swaps direction by hand. Widgets are short-lived, so the
    // choice deliberately lasts only until this one is closed — reopening it
    // goes back to following the clock.
    private var manualSelection_ as Boolean = false;

    function initialize(stop1 as String, stop2 as String, stop3 as String, stop4 as String, switchHour as Number, requester as WebRequester) {
        stop1_      = stop1;
        stop2_      = stop2;
        stop3_      = stop3;
        stop4_      = stop4;
        switchHour_ = switchHour;
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var beforeSwitch = (now.hour < switchHour_);
        currentLeg_ = beforeSwitch ? 1 : 2;
        outward_    = true;
        service_ = new TrainService(method(:onDataChanged), requester);
    }

    function onSettingsChanged(stop1 as String, stop2 as String, stop3 as String, stop4 as String, switchHour as Number) as Void {
        stop1_      = stop1;
        stop2_      = stop2;
        stop3_      = stop3;
        stop4_      = stop4;
        switchHour_ = switchHour;
        // New stations mean the old manual choice no longer means anything.
        manualSelection_ = false;
        refresh();
    }

    function refresh() as Void {
        offset_ = 0;
        // A manual selection wins over the clock, so a refresh doesn't undo it.
        if (!manualSelection_) {
            var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var beforeSwitch = (now.hour < switchHour_);
            currentLeg_ = beforeSwitch ? 1 : 2;
            outward_    = true;
        }
        _request();
    }

    // Cycle through legs and directions. Sticks until the widget closes.
    function toggleDirection() as Void {
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var beforeSwitch = (now.hour < switchHour_);

        if (beforeSwitch) {
            // Before switch: Leg1-Out → Leg1-Ret → Leg2-Out → Leg2-Ret
            if (currentLeg_ == 1) {
                if (outward_) {
                    outward_ = false;
                } else {
                    currentLeg_ = 2;
                    outward_    = true;
                }
            } else {
                if (outward_) {
                    outward_ = false;
                } else {
                    currentLeg_ = 1;
                    outward_    = true;
                }
            }
        } else {
            // After switch: Leg2-Out → Leg2-Ret → Leg1-Out → Leg1-Ret
            if (currentLeg_ == 2) {
                if (outward_) {
                    outward_ = false;
                } else {
                    currentLeg_ = 1;
                    outward_    = true;
                }
            } else {
                if (outward_) {
                    outward_ = false;
                } else {
                    currentLeg_ = 2;
                    outward_    = true;
                }
            }
        }

        manualSelection_ = true;
        offset_          = 0;
        _request();
    }

    function isOutward() as Boolean { return outward_; }

    private function _request() as Void {
        var from;
        var to;

        if (currentLeg_ == 1) {
            from = outward_ ? stop1_ : stop2_;
            to   = outward_ ? stop2_ : stop1_;
        } else {
            from = outward_ ? stop3_ : stop4_;
            to   = outward_ ? stop4_ : stop3_;
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
        if (currentLeg_ == 1) {
            if (outward_) {
                return stop1_ + " > " + stop2_;
            }
            return stop2_ + " > " + stop1_;
        } else {
            if (outward_) {
                return stop3_ + " > " + stop4_;
            }
            return stop4_ + " > " + stop3_;
        }
    }
}
