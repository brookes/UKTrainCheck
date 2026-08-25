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
        var hasLeg2 = stop3_ != null && (stop3_ as String).length() > 0
                   && stop4_ != null && (stop4_ as String).length() > 0;
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        currentLeg_ = (hasLeg2 && now.hour >= switchHour) ? 2 : 1;
        outward_ = true;

        var from;
        var to;
        if (currentLeg_ == 1) {
            from = stop1_;
            to   = stop2_;
        } else {
            from = stop3_ as String;
            to   = stop4_ as String;
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
