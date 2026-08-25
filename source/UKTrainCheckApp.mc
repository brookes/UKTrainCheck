import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

using Toybox.Application.Properties;

(:glance)
class UKTrainCheckApp extends Application.AppBase {

    private var mainViewModel_ as TrainViewModel or Null;

    function initialize() {
        Log.println("Initialising");
        AppBase.initialize();
        mainViewModel_ = null;
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
        Log.println("On Start");
        if (state != null) {
            var a = state.get(:launchedFromGlance) as Boolean;
            if (a != null && a) {
                Log.println("Launched from glance");
            } else {
                Log.println("Not Launched from glance");
            }
        } else {
            // Launched from activity menu
            Log.println("Launched from activity");
        }
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
        Log.println("On Stop");
    }

    function onActive(state as Dictionary or Null) as Void {
        Log.println("On active");
    }

    function onInactive(state as Dictionary or Null) as Void {
        Log.println("On inactive");
    }

    function onSettingsChanged() as Void {
        Log.println("Settings changed");
        var stop1      = Properties.getValue("Stop1") as String;
        var stop2      = Properties.getValue("Stop2") as String;
        var stop3      = Properties.getValue("Stop3") as String;
        var stop4      = Properties.getValue("Stop4") as String;
        var switchHour = Properties.getValue("SwitchHour") as Number;
        if (mainViewModel_ != null) {
            (mainViewModel_ as TrainViewModel).onSettingsChanged(stop1, stop2, stop3, stop4, switchHour);
        }
        WatchUi.requestUpdate();
    }

    (:glance :glanceExclusive)
    function getGlanceView() as [GlanceView] or [GlanceView, GlanceViewDelegate] or Null {
        Log.println("Get glance view");
        var viewModel = new TrainGlanceViewModel();
        return [ new TrainGlanceView(viewModel) ];
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var stop1      = Properties.getValue("Stop1") as String;
        var stop2      = Properties.getValue("Stop2") as String;
        var stop3      = Properties.getValue("Stop3") as String;
        var stop4      = Properties.getValue("Stop4") as String;
        var switchHour = Properties.getValue("SwitchHour") as Number;
        mainViewModel_ = new TrainViewModel(stop1, stop2, stop3, stop4, switchHour, new WebRequester());
        var view = new TrainView(mainViewModel_);
        var delegate = new TrainDelegate(mainViewModel_);
        return [ view, delegate ];
    }
}

function getApp() as UKTrainCheckApp {
    return Application.getApp() as UKTrainCheckApp;
}
