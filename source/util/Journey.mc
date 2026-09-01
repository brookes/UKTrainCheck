import Toybox.Lang;
import Toybox.Time;

using Toybox.Time.Gregorian;

// The widget cycles through every journey and direction that is configured:
//
//   0  stop1 > stop2     leg 1 out
//   1  stop2 > stop1     leg 1 back
//   2  stop3 > stop4     leg 2 out
//   3  stop4 > stop3     leg 2 back
//
// Mornings walk it forwards from step 0. Afternoons are the same journeys in
// reverse, so they walk it backwards from the end — opening on the furthest
// return, which is the train you actually want after the switch hour. Leg 2 is
// optional; without it the cycle is just steps 0 and 1, and the same rule still
// leaves the afternoon opening on the return.
//
// The glance has no toggle and only needs the opening step, but it has to agree
// with the widget about which step that is. Keeping the rule in one place is
// what stops the two drifting apart.
(:glance)
class Journey {

    // Blank or absent either side means there is no second journey to show. An
    // install predating these properties has no value stored for them, so the
    // API hands back null rather than the built-in default.
    static function hasLeg2(stop3 as String or Null, stop4 as String or Null) as Boolean {
        return stop3 != null && (stop3 as String).length() > 0
            && stop4 != null && (stop4 as String).length() > 0;
    }

    static function steps(stop3 as String or Null, stop4 as String or Null) as Number {
        return hasLeg2(stop3, stop4) ? 4 : 2;
    }

    // Before the switch hour the cycle runs forwards; after it, backwards.
    static function forwards(switchHour as Number) as Boolean {
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return now.hour < switchHour;
    }

    // Where the clock alone says to start, ignoring any manual choice.
    static function openingStep(stop3 as String or Null, stop4 as String or Null,
                                switchHour as Number) as Number {
        return forwards(switchHour) ? 0 : steps(stop3, stop4) - 1;
    }

    static function isLeg1(step as Number)    as Boolean { return step < 2;        }
    static function isOutward(step as Number) as Boolean { return (step % 2) == 0; }
}
