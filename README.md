# UKTrainCheck

A Garmin Connect IQ widget that shows live UK train departure times for two stations, automatically switching direction based on time of day.
(note - the time of day switch is deliberate - this is useful as a glance app, and the time/energy cost of GPS to determine which end of the 
trip you're at would interfere with the experience.)

## Features

- Shows upcoming departures between two configured stations
- Automatically switches outward/return direction at a configurable time
- Highlights delayed trains in orange, past trains in grey
- Glance view shows the next departure at a glance
- Falls back to show if a replacement bus service is running.

## Settings

| Setting | Description |
|---|---|
| **Home Station (CRS)** | Your home station's [CRS code](https://www.nationalrail.co.uk/stations_destinations/48541.aspx) (e.g. `WTY`) |
| **Away Station (CRS)** | Your destination station's CRS code (e.g. `WAT`) |
| **Switch direction after** | Time after which the app shows return trains instead of outward (24h, default 12:00) |

CRS codes are the 3-letter codes shown on tickets and departure boards. You can look them up on the [National Rail website](https://www.nationalrail.co.uk).

## Display

The heading shows the current direction as `HOME 🚆 AWAY`. Below it the widget shows
scheduled departure times with status:

- **White** — on time or within expected time
- **Orange** — delayed
- **Grey** — already departed (trains from up to 60 minutes ago are shown)
- **BUS** — replacement bus service
- **CNX** — cancelled service
- **Delay** — delayed, no revised time given yet

## Supported Devices

See devices in manifest.xml.  Note - many of these devices don't support glance, so that will not work, however the full app functionality does.

## Building

Requires the [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/).

Set the `SDK` variable to your Connect IQ SDK path (e.g. `~/AppData/Roaming/Garmin/ConnectIQ/Sdks/<sdk-version>` on Windows, `~/Library/Application Support/Garmin/ConnectIQ/Sdks/<sdk-version>` on macOS).

## Notes

- Times are compared against device local time. The watch should be configured to UK/London timezone for the "past train" greying to be accurate.
- The full view queries for trains departing from up to 60 minutes ago, so recently departed services remain visible (so you can tell how late your train was!)
