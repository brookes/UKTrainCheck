# UKTrainCheck

A Garmin Connect IQ widget that shows live UK train departure times for one or two
journeys, automatically switching direction based on time of day.
(note - the time of day switch is deliberate - this is useful as a glance app, and the time/energy cost of GPS to determine which end of the 
trip you're at would interfere with the experience.)

## Features

- Shows upcoming departures between two configured stations
- Takes a second journey as well, for a commute that changes trains partway
- Automatically switches outward/return direction at a configurable time, or swap it by hand with a key press
- Colour-codes each departure: green on time, orange delayed, grey departed
- Glance view shows the next departure at a glance
- Falls back to show if a replacement bus service is running.

## Settings

| Setting | Description |
|---|---|
| **Leg 1 Station A (CRS)** | Your home station's [CRS code](https://www.nationalrail.co.uk/stations_destinations/48541.aspx) (e.g. `GLD`) |
| **Leg 1 Station B (CRS)** | Where leg 1 takes you (e.g. `WAT`) |
| **Leg 2 Station A (CRS)** | Optional. Where the second leg starts — often the same as Leg 1 Station B |
| **Leg 2 Station B (CRS)** | Optional. Where leg 2 takes you |
| **Switch direction after** | Time after which the app shows return trains instead of outward (24h, default 12:00) |
| **Show destination CRS** | Append each train's terminating station code, e.g. `WAT` (default on) |
| **Show platform** | Append the platform, e.g. `p2` (default on) |
| **Show countdown** | Append minutes-to-departure, e.g. `(12m)` (default on) |

Turn the last three off on narrow screens if a row would otherwise overflow.

CRS codes are the 3-letter codes shown on tickets and departure boards. You can look them up on the [National Rail website](https://www.nationalrail.co.uk).

## Display

The heading shows the journey on screen as `FROM 🚞 TO`. Below it each row shows the
scheduled departure, plus (when enabled) destination, platform, delay and a
countdown:

```
08:45 WAT p2 (12m)      on time, 12 min to go
08:45 WAT p2 +7 (5m)    7 min late, leaves in 5
08:45 WAT p2 +7         already departed (greyed)
```

Delay is shown as `+N` minutes; the countdown always counts to the *actual*
(delayed) departure. Status is also colour-coded:

- **Green** — on time or within expected time
- **Orange** — delayed
- **Grey** — already departed (trains from up to 45 minutes ago are shown)
- **BUS** — replacement bus service
- **CNX** — cancelled service
- **Delay** — delayed, no revised time given yet

Arrows either side of the heading appear when there are more departures above or
below.

How many rows fit is worked out from the screen size at draw time, so it
adapts across devices — around five on a 240x240 round watch. Scroll with
UP/DOWN if a busy route returns more than that.

The glance view shows the next departure compactly, e.g. `08:45 +7  5m` (the
route is already in the glance title).

## Controls

| Key | Action |
|---|---|
| **UP** / **DOWN** | Scroll the departure list |
| **START** | Step to the next journey in the cycle |
| **MENU** (long-press UP) | Refresh |

START walks a cycle of every journey and direction you have configured. Before
the switch hour it opens on the outward leg 1 and works away from home:

```
Leg 1 A > B   →   Leg 1 B > A   →   Leg 2 A > B   →   Leg 2 B > A   →   (round again)
```

After the switch hour it runs the same list backwards, opening on the furthest
return — the train you actually want on the way home:

```
Leg 2 B > A   →   Leg 2 A > B   →   Leg 1 B > A   →   Leg 1 A > B   →   (round again)
```

Leave the leg 2 stations blank and the cycle is just the two leg-1 directions,
still opening on the outward one in the morning and the return in the afternoon.

Stepping by hand overrides the automatic switch time for as long as the widget
is open — refreshing won't undo it. Close and reopen the widget (or change the
stations in settings) to go back to following the clock.

## Supported Devices

See devices in manifest.xml.  Note - many of these devices don't support glance, so that will not work, however the full app functionality does.

## Building

Requires the [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/)
and a developer key (VS Code: *Monkey C: Generate a Developer Key*). The SDK
tools live under `~/Library/Application Support/Garmin/ConnectIQ/Sdks/<version>/bin`
on macOS, `~/AppData/Roaming/Garmin/ConnectIQ/Sdks/<version>/bin` on Windows.

Build a sideloadable `.prg` for one device:

```bash
monkeyc -f monkey.jungle -o bin/UKTrainCheck.prg -y <developer_key> -d fr945 -r
```

Build a store package covering every device in the manifest:

```bash
monkeyc -e -o UKTrainCheck.iq -f monkey.jungle -y <developer_key> -r
```

Run the unit tests, with the simulator already running (`connectiq`):

```bash
monkeyc -f monkey.jungle -o bin/test.prg -y <developer_key> -d fr945 -w -t
monkeydo bin/test.prg fr945 -t
```

Two things that look like faults but aren't:

- `Invalid device id found in the application manifest` is emitted for every
  device whose bundle isn't installed in the SDK Manager. The manifest lists
  more devices than you are likely to have downloaded, so expect a wall of
  these. The build still succeeds.
- `monkeydo` **with** `-t` runs the test harness, not the UI, so the simulator
  window stays blank. Drop `-t` to see the app. For a glance-capable app the
  simulator may also open the glance rather than the main view.

## Installing

Copy the `.prg` into `GARMIN/APPS/` on the watch over USB. Recent devices
present as MTP rather than mass storage, so on macOS they never appear in
`/Volumes` — use [OpenMTP](https://openmtp.ganeshrvel.com/) or similar.

Sideloaded apps are not registered against a Garmin account, so they don't
appear in the Connect IQ settings list in Garmin Connect and their properties
can't be edited from the phone. Change the defaults in
`resources/properties.xml` and rebuild instead.

Note that an existing install keeps its own copy of the settings in
`GARMIN/APPS/SETTINGS/`, and those win over rebuilt defaults. The filenames
there are opaque, so identify the right one by its contents — the file holding
this app's settings contains the property keys (`Stop1`, `Stop2`,
`SwitchHour`, ...) as plain strings. Delete it to pick up new defaults.

## Notes

- Times are compared against device local time. The watch should be configured to UK/London timezone for the "past train" greying to be accurate.
- The full view queries from 45 minutes ago to 75 minutes ahead, so recently departed services remain visible (so you can tell how late your train was!). Darwin serves a 120-minute window from the requested offset and ignores any larger `timeWindow`, so lookback and lookahead trade directly against each other — `FETCH_OFFSET` in `TrainViewModel.mc` sets where that window starts.
