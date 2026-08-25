import Toybox.Lang;
import Toybox.Time;

using Toybox.Application.Properties;
using Toybox.Time.Gregorian;
using Toybox.WatchUi;

(:glance :glanceExclusive)
class TrainGlanceViewModel {

    private var stop1_   as String  = "";
    private var stop2_   as String  = "";
    private var outward_ as Boolean = true;
    private var service_ as TrainService;

    function initialize() {
        service_ = new TrainService(method(:onDataChanged), new WebRequester());
    }

    function refresh() as Void {
        stop1_ = Properties.getValue("Stop1") as String;
        stop2_ = Properties.getValue("Stop2") as String;
        var switchHour = Properties.getValue("SwitchHour") as Number;
        var now = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        outward_ = (now.hour < switchHour);
        if (outward_) {
            service_.request(stop1_, stop2_, 2, null);
        } else {
            service_.request(stop2_, stop1_, 2, null);
        }
    }

    function getTitle() as String {
        return _genTitle();
    }

    function getCaption() as String {
        var trains = service_.getTrains();
        if (trains.size() > 0) {
            var train = trains[0];
            // Always show actual status including "On time" — seeing it is
            // rewarding for the user, given that we're used to trains being late.
            var time = train.label();
            return service_.isBusService() ? "BUS " + time : time;
        }
        var error = service_.getError();
        return service_.isPending() ? "[Fetching]" : (error != null ? error : "[Unknown]");
    }

    function onDataChanged() as Void {
        WatchUi.requestUpdate();
    }

    private function _genTitle() as String {
        if (outward_) {
            return stop1_ + " 🚆 " + stop2_;
        }
        return stop2_ + " 🚆 " + stop1_;
    }
}
