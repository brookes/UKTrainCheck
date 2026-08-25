import Toybox.Lang;

(:glance)
class Train {
    private var expected_        as String;
    private var actual_          as String;
    private var delayed_         as Boolean;
    private var expectedMinutes_ as Number or Null;
    // Minutes-since-midnight the train actually departs: the delayed (etd) time
    // when known, otherwise the scheduled time. Used for the countdown.
    private var actualMinutes_   as Number or Null;
    // The etd parsed as a time, or null when etd isn't one ("On time",
    // "Cancelled", "Delayed"). Distinct from actualMinutes_, which falls back to
    // the scheduled time so the countdown still works.
    private var actualParsed_    as Number or Null;
    // Optional extra detail from the feed; null when unavailable.
    private var destination_     as String or Null = null;
    private var platform_        as String or Null = null;

    function initialize(expected as String, actual as String) {
        expected_        = expected;
        expectedMinutes_ = _parseMinutes(expected);
        if (!actual.equals("???") && (actual.equals("On time") || actual.equals(expected))) {
            actual_  = "On time";
            delayed_ = false;
        } else {
            actual_  = _abbreviate(actual);
            delayed_ = true;
        }
        // Prefer the delayed time for the countdown; fall back to scheduled when
        // etd is "On time" or a non-time status (e.g. "Cancelled").
        actualParsed_  = _parseMinutes(actual_);
        actualMinutes_ = actualParsed_ != null ? actualParsed_ : expectedMinutes_;
    }

    function getExpected() as String  { return expected_; }
    function getActual()   as String  { return actual_;   }
    function isDelayed()   as Boolean { return delayed_;  }

    // destination is the terminating station's CRS code; platform as reported.
    function setDetails(destination as String or Null, platform as String or Null) as Void {
        destination_ = destination;
        platform_    = platform;
    }

    function getDestination() as String or Null { return destination_; }
    function getPlatform()    as String or Null { return platform_;    }

    function isPast(nowMinutes as Number) as Boolean {
        return expectedMinutes_ != null && (expectedMinutes_ as Number) < nowMinutes;
    }

    // Whole minutes late, or null when the delay isn't a parseable time
    // (on time, or a status like "Cancelled").
    function delayMinutes() as Number or Null {
        if (!delayed_ || actualParsed_ == null || expectedMinutes_ == null) {
            return null;
        }
        return (actualParsed_ as Number) - (expectedMinutes_ as Number);
    }

    // Minutes until departure (using the delayed time when known), or null when
    // the departure time is unparseable. Negative once the train has left.
    function minutesUntil(nowMinutes as Number) as Number or Null {
        return actualMinutes_ != null ? (actualMinutes_ as Number) - nowMinutes : null;
    }

    // Full-view row: "08:45 WAT p1 +7 (5m)". Each part is optional; on-time trains
    // omit the "+N", already-departed trains omit the countdown.
    function detailLabel(nowMinutes as Number, showDest as Boolean, showPlatform as Boolean, showCountdown as Boolean) as String {
        var s = expected_;
        if (showDest && destination_ != null) {
            s += " " + destination_;
        }
        if (showPlatform && platform_ != null) {
            s += " p" + platform_;
        }
        if (delayed_) {
            var dm = delayMinutes();
            s += (dm != null && dm > 0) ? " +" + (dm as Number) : " " + actual_;
        }
        if (showCountdown) {
            var mu = minutesUntil(nowMinutes);
            if (mu != null && mu >= 0) {
                s += " (" + (mu as Number) + "m)";
            }
        }
        return s;
    }

    // Glance caption: "08:45 +7  5m". The route already appears in the glance
    // title, so destination/platform are left out to save width.
    function glanceLabel(nowMinutes as Number) as String {
        var s = expected_;
        if (delayed_) {
            var dm = delayMinutes();
            s += (dm != null && dm > 0) ? " +" + (dm as Number) : " " + actual_;
        }
        var mu = minutesUntil(nowMinutes);
        if (mu != null && mu >= 0) {
            s += "  " + (mu as Number) + "m";
        }
        return s;
    }

    function toStorage() as String {
        return expected_ + "," + actual_;
    }

    static function fromStorage(persisted as String) as Train {
        var comma = persisted.find(",");
        if (comma == null) {
            return new Train(persisted, "???");
        }
        return new Train(persisted.substring(0, comma), persisted.substring(comma + 1, persisted.length()));
    }

    // The departure board returns free-text status words; shorten the long
    // ones so they fit alongside the time on a watch screen.
    private static function _abbreviate(actual as String) as String {
        var lower = actual.toLower();
        if (lower.equals("cancelled")) { return "CNX";   }
        if (lower.equals("delayed"))   { return "Delay"; }
        return actual;
    }

    // Returns minutes since midnight for a "HH:MM" string, or null if unparseable.
    private static function _parseMinutes(time as String) as Number or Null {
        var colon = time.find(":");
        if (colon == null) {
            return null;
        }
        var h = time.substring(0, colon).toNumber();
        var m = time.substring(colon + 1, time.length()).toNumber();
        if (h == null || m == null) {
            return null;
        }
        return h * 60 + m;
    }
}
