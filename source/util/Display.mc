import Toybox.Lang;

// Separator between the two station codes in the heading, e.g. "WRH 🚞 ECR".
// Shared so the widget and the glance can never drift apart, and so the glyph
// is one edit away if a device turns out not to have it in its font — Connect
// IQ's built-in fonts are bitmap fonts, and anything missing draws as a blank.
(:glance)
const HEADING_SEP = " 🚞 ";
