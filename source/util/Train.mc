import Toybox.Lang;

(:glance)
class Train {
    private var expected_        as String;
    private var actual_          as String;
    private var delayed_         as Boolean;
    private var expectedMinutes_ as Number or Null;

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
    }

    function getExpected() as String  { return expected_; }
    function getActual()   as String  { return actual_;   }
    function isDelayed()   as Boolean { return delayed_;  }

    function isPast(nowMinutes as Number) as Boolean {
        return expectedMinutes_ != null && (expectedMinutes_ as Number) < nowMinutes;
    }

    function label() as String {
        return expected_ + " (" + actual_ + ")";
    }

    function shortLabel() as String {
        if (!delayed_) {
            return expected_;
        }
        return expected_ + " (" + actual_ + ")";
    }

    function toStorage() as String {
        return expected_ + "," + actual_;
    }

    static function fromStorage(persisted as String) as Train {
        var comma = persisted.find(",");
        if (comma == null) {
            return new Train(persisted, "???");
        }
        return new Train(persisted.substring(0, comma), persisted.substring(comma + 1, null));
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
        var m = time.substring(colon + 1, null).toNumber();
        if (h == null || m == null) {
            return null;
        }
        return h * 60 + m;
    }
}
