import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

(:glance :glanceExclusive)
class TrainGlanceView extends WatchUi.GlanceView {

    private static const REFRESH_MS = 60000;

    private var viewModel_ as TrainGlanceViewModel;
    private var timer_     as Timer.Timer;

    function initialize(viewModel as TrainGlanceViewModel) {
        GlanceView.initialize();
        viewModel_ = viewModel;
        timer_ = new Timer.Timer();
    }

    function onShow() as Void {
        viewModel_.refresh();
        timer_.start(method(:onTimer), REFRESH_MS, true);
    }

    function onHide() as Void {
        timer_.stop();
    }

    function onTimer() as Void {
        viewModel_.refresh();
    }

    function onUpdate(dc as Dc) as Void {
        GlanceView.onUpdate(dc);
        _draw(dc);
    }

    private function _draw(dc as Dc) as Void {
        var cy   = dc.getHeight() / 2;
        var font = Graphics.FONT_GLANCE;
        var fh   = dc.getFontHeight(font);
        // Status text stays white; a real departure is coloured like the full list.
        var next    = viewModel_.getNextTrain();
        var caption = Graphics.COLOR_WHITE;
        if (next != null) {
            caption = (next as Train).isDelayed() ? Graphics.COLOR_ORANGE : Graphics.COLOR_GREEN;
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(0, cy - fh, font,              viewModel_.getTitle(),   Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(caption, Graphics.COLOR_BLACK);
        dc.drawText(0, cy,      Graphics.FONT_TINY, viewModel_.getCaption(), Graphics.TEXT_JUSTIFY_LEFT);
    }
}
