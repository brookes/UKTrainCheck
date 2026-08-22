import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

using Toybox.Math;
using Toybox.System;
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

    // On a round screen a line of text needs a chord wide enough to hold it, so
    // rows can't run to the physical top and bottom — the limit is horizontal,
    // not vertical. Returns how far below the top edge a line of the given width
    // has to start before the circle is wide enough for it. 0 on square screens.
    private function _inset(width as Number, radius as Number) as Number {
        var half = width / 2;
        if (half >= radius) { return 0; }
        var d = Math.sqrt(radius * radius - half * half);
        return (radius - d).toNumber();
    }

    private function _draw(dc as Dc) as Void {
        var w         = dc.getWidth();
        var h         = dc.getHeight();
        var titleFont = Graphics.FONT_TINY;
        var title = viewModel_.getTitle();
        var font      = Graphics.FONT_MEDIUM;
        var titleFh   = dc.getFontHeight(titleFont);
        var fh        = dc.getFontHeight(font);
        var lineH     = fh;
        var gap       = 2;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var trains = viewModel_.getTrains();
        var count  = trains.size();

        // Read display toggles once rather than per row.
        var showDest      = viewModel_.showDest();
        var showPlatform  = viewModel_.showPlatform();
        var showCountdown = viewModel_.showCountdown();

        var round  = System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND;
        var radius = h / 2;
        var titleW = dc.getTextWidthInPixels(title, titleFont);
        // Push the title as close to the top as the curve allows — it's short, so
        // that's only a few pixels down, which buys a row back for the list.
        var titleY = round ? _inset(titleW, radius) : 0;

        var trainsY = titleY + titleFh + gap;

        // Rows then use everything below. Note this deliberately ignores the
        // curve: insetting rows far enough that the longest label never clips
        // costs more rows than it saves, so the bottom row can lose its edges on
        // a long label. Turning ShowDest off keeps labels well inside that.
        var maxVisible = (h - trainsY) / lineH;
        if (maxVisible < 1) { maxVisible = 1; }
        viewModel_.setVisibleRows(maxVisible);

        var offset    = viewModel_.getOffset();
        var remaining = count - offset;
        var visible   = remaining < maxVisible ? remaining : maxVisible;
        // Defensive: a shrinking list between redraws must not draw -n rows.
        if (visible < 0) { visible = 0; }

        dc.drawText(w / 2, titleY, titleFont, title, Graphics.TEXT_JUSTIFY_CENTER);

        if (count == 0) {
            var error = viewModel_.getError();
            var msg = viewModel_.isPending() ? "[Fetching]" : (error != null ? error : "[No trains]");
            dc.drawText(w / 2, trainsY, font, msg, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        // Scroll indicators flank the title: the rows now fill the usable band,
        // so there's no spare line above or below them to put arrows on.
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        var arrowX = w / 2 + titleW / 2 + 8;
        if (offset > 0) {
            dc.drawText(w - arrowX, titleY, Graphics.FONT_XTINY, "^", Graphics.TEXT_JUSTIFY_RIGHT);
        }
        if (offset + maxVisible < count) {
            dc.drawText(arrowX, titleY, Graphics.FONT_XTINY, "v", Graphics.TEXT_JUSTIFY_LEFT);
        }

        var busPrefix  = viewModel_.isBusService() ? "BUS " : "";
        // Uses device local time. Correct when the watch is set to UK/London timezone,
        // which is the expected configuration for this app.
        var now        = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var nowMinutes = now.hour * 60 + now.min;

        for (var i = 0; i < visible; i++) {
            var idx = offset + i;
            // Can't happen but let's check for free ;)
            if (idx >= count) { break; }
            var train = trains[idx] as Train;
            var label = busPrefix + train.detailLabel(nowMinutes, showDest, showPlatform, showCountdown);
            if (train.isPast(nowMinutes)) {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
            } else if (train.isDelayed()) {
                dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_BLACK);
            } else {
                dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_BLACK);
            }
            dc.drawText(w / 2, trainsY + i * lineH, font, label, Graphics.TEXT_JUSTIFY_CENTER);
            busPrefix = "";  // only prefix the first row
        }
    }
}
