import Toybox.Lang;
import Toybox.Time;

using Toybox.Application.Properties;
using Toybox.Time.Gregorian;
using Toybox.WatchUi;

(:glance :glanceExclusive)
class TrainGlanceViewModel {

    private var stop1_   as String  = "";
    private var stop2_   as String  = "";
    // Leg 2 is optional, and an install predating these properties stores no
    // value for them, so null arrives here as readily as a blank string.
    private var stop3_   as String or Null = null;
    private var stop4_   as String or Null = null;
    private var currentLeg_ as Number = 1;
    private var outward_ as Boolean = true;
    private var service_ as TrainService;

    function initialize() {
        service_ = new TrainService(method(:onDataChanged), new WebRequester());
    }

    function refresh() as Void {
        stop1_ = Properties.getValue("Stop1") as String;
        stop2_ = Properties.getValue("Stop2") as String;
        stop3_ = Properties.getValue("Stop3") as String or Null;
        stop4_ = Properties.getValue("Stop4") as String or Null;
        var switchHour = Properties.getValue("SwitchHour") as Number;
        // The glance has no toggle, so it shows whatever the widget would open
        // on — including the afternoon's reversal onto the return leg.
        var step    = Journey.openingStep(stop3_, stop4_, switchHour);
        currentLeg_ = Journey.isLeg1(step) ? 1 : 2;
        outward_    = Journey.isOutward(step);

        var from;
        var to;
        if (currentLeg_ == 1) {
            from = outward_ ? stop1_ : stop2_;
            to   = outward_ ? stop2_ : stop1_;
        } else {
            from = outward_ ? (stop3_ as String) : (stop4_ as String);
            to   = outward_ ? (stop4_ as String) : (stop3_ as String);
        }
        service_.request(from, to, 2, null);
    }

    function getTitle() as String {
        return _genTitle();
    }

    // The departure the caption describes, or null when the caption is status
    // text instead ("[Fetching]", an error). Lets the view colour it to match
    // the full list: green on time, orange when late.
    function getNextTrain() as Train or Null {
        var trains = service_.getTrains();
        return trains.size() > 0 ? trains[0] as Train : null;
    }

    function getCaption() as String {
        var trains = service_.getTrains();
        if (trains.size() > 0) {
            var train = trains[0];
            var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var nowMinutes = now.hour * 60 + now.min;
            // Shows the scheduled time, any delay as "+N", and a minutes-to-go
            // countdown — the route itself is already in the glance title.
            var time = train.glanceLabel(nowMinutes);
            return service_.isBusService() ? "BUS " + time : time;
        }
        var error = service_.getError();
        return service_.isPending() ? "[Fetching]" : (error != null ? error : "[Unknown]");
    }

    function onDataChanged() as Void {
        WatchUi.requestUpdate();
    }

    private function _genTitle() as String {
        if (currentLeg_ == 1) {
            return outward_ ? stop1_ + HEADING_SEP + stop2_
                            : stop2_ + HEADING_SEP + stop1_;
        }
        return outward_ ? (stop3_ as String) + HEADING_SEP + (stop4_ as String)
                        : (stop4_ as String) + HEADING_SEP + (stop3_ as String);
    }
}
