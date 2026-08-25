import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

using Toybox.Time.Gregorian;

class TrainView extends WatchUi.View {

    private var viewModel_ as TrainViewModel;

    function initialize(viewModel as TrainViewModel) {
        View.initialize();
        viewModel_ = viewModel;
    }

    function onShow() as Void {
        // No periodic refresh — data is fetched once on show and manually via select.
        // The glance refreshes every 60s; the main view is intentionally on-demand.
        viewModel_.refresh();
    }

    function onUpdate(dc as Dc) as Void {
        View.onUpdate(dc);
        _draw(dc);
    }

    function onHide() as Void {
    }

    private function _draw(dc as Dc) as Void {
        var w         = dc.getWidth();
        var h         = dc.getHeight();
        var titleFont = Graphics.FONT_TINY;
        var title = viewModel_.getTitle();
        var font      = Graphics.FONT_SMALL;
        var titleFh   = dc.getFontHeight(titleFont);
        var fh        = dc.getFontHeight(font);
        var lineH     = fh + 2;
        var gap       = 4;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var trains = viewModel_.getTrains();
        var count  = trains.size();

        if (count == 0) {
            // Status messages ([Fetching], errors) get a smaller font than the
            // train rows, and the title/message pair is centred on the screen.
            var statusFont = Graphics.FONT_TINY;
            var statusFh   = dc.getFontHeight(statusFont);
            var error      = viewModel_.getError();
            var msg        = viewModel_.isPending() ? "[Fetching]" : (error != null ? error : "[No trains]");
            var groupTop   = (h - (titleFh + gap + statusFh)) / 2;
            dc.drawText(w / 2, groupTop, titleFont, title, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(w / 2, groupTop + titleFh + gap + statusFh / 2, statusFont, msg,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        // How many train rows fit on screen — calculated from actual screen height
        // so this works across all device sizes without hardcoding.
        var maxVisible = (h - titleFh - gap) / lineH;
        if (maxVisible < 1) { maxVisible = 1; }

        var offset    = viewModel_.getOffset();
        var remaining = count - offset;
        var visible   = remaining < maxVisible ? remaining : maxVisible;

        // Vertically center the visible block (title + visible rows) so the title
        // lands in the wider part of the round screen rather than near the top.
        var blockH = titleFh + gap + visible * lineH;
        // Shift down slightly so the title lands in the wider part of round screens.
        var startY = (h - blockH) / 2 + 8;

        dc.drawText(w / 2, startY, titleFont, title, Graphics.TEXT_JUSTIFY_CENTER);

        var trainsY = startY + titleFh + gap;

        // Scroll indicators — shown in dark grey at the screen edges when
        // there are trains above or below the current window.
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        if (offset > 0) {
            dc.drawText(w / 2, startY - titleFh, titleFont, "^", Graphics.TEXT_JUSTIFY_CENTER);
        }
        if (offset + maxVisible < count) {
            dc.drawText(w / 2, trainsY + visible * lineH, titleFont, "v", Graphics.TEXT_JUSTIFY_CENTER);
        }

        var busPrefix  = viewModel_.isBusService() ? "BUS " : "";
        // Uses device local time. Correct when the watch is set to UK/London timezone,
        // which is the expected configuration for this app.
        var now        = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        var nowMinutes = now.hour * 60 + now.min;

        for (var i = 0; i < visible; i++) {
            var idx = offset + i;
            // Can't happen but let's check for free ;)
            if (idx >= count) { break; }
            var train = trains[idx] as Train;
            var label = busPrefix + train.shortLabel();
            if (train.isPast(nowMinutes)) {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
            } else if (train.isDelayed()) {
                dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_BLACK);
            } else {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            }
            dc.drawText(w / 2, trainsY + i * lineH, font, label, Graphics.TEXT_JUSTIFY_CENTER);
            busPrefix = "";  // only prefix the first row
        }
    }
}
