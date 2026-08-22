import Toybox.Lang;
import Toybox.WatchUi;

class TrainDelegate extends WatchUi.BehaviorDelegate {

    private var viewModel_ as TrainViewModel;

    function initialize(viewModel as TrainViewModel) {
        BehaviorDelegate.initialize();
        viewModel_ = viewModel;
    }

    //! START/STOP — swap the direction of travel (this refetches too)
    function onSelect() as Boolean {
        viewModel_.toggleDirection();
        return true;
    }

    function onNextPage()     as Boolean { viewModel_.scrollDown(); return true; }
    function onPreviousPage() as Boolean { viewModel_.scrollUp();   return true; }
    //! MENU (long-press UP) — manual refresh. Not delivered on every device in
    //! widget mode, which is why the direction swap sits on START instead.
    function onMenu() as Boolean {
        viewModel_.refresh();
        return true;
    }

    function onBack()         as Boolean { return false; }
}
