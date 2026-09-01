# Publishing to the Connect IQ store

Notes toward a first store submission. Ordered by what blocks what, not by the
order the upload form asks for things — the two hard problems are both outside
the code and worth settling before any of the packaging work.

## 1. The API proxy is the real blocker

`WebRequester` points every request at
`https://nre-proxy.lab27ukrail.workers.dev/departures/`, a personal Cloudflare
Worker that holds the RailData API key so the app doesn't have to ship it.

That is the right call for a sideloaded app used by one person. It does not
survive publication unchanged:

- **Every user's traffic lands on that Worker**, against its owner's Cloudflare
  account and quota. A free Worker's daily request ceiling is easy to reach with
  even modest uptake, and the failure mode is the app breaking for everyone at
  once with no way to push a fix faster than store review.
- **One API key serves all users.** RailData's rate limits apply per key, so
  users compete with each other, and any abuse is attributable to the key's
  owner.
- **Check what the licence actually permits.** Redistributing Darwin/LDBWS data
  through a third-party app to the public is a different proposition from
  personal use, and the free tier's terms may not cover it. This needs reading
  before anything is submitted, not after.

Options, roughly in increasing order of effort:

1. **Ship the app without a key and make each user supply their own.** Add a
   settings field for an API key and point `BASE_URL` back at RailData directly
   (the commented-out constants in `WebRequester` are already the right ones).
   Costs nothing, scales indefinitely, and puts each user under their own
   licence — at the price of a signup step that will lose most casual users.
2. **Keep the proxy but put limits on it.** Per-device rate limiting and a
   cost ceiling on the Cloudflare account. Still one key, still one throat to
   choke, but bounded.
3. **Both** — proxy by default, own-key as an option for heavy users.

Option 1 is the only one that doesn't put a personal account behind a public
app's traffic. Worth deciding before writing the store listing, because it
changes what the description has to say.

## 2. Device bundles

A store package covers every device in the manifest:

```bash
monkeyc -e -o UKTrainCheck.iq -f monkey.jungle -y <developer_key> -r
```

The manifest declares **42 devices**; only `fr945` has its bundle installed
here. The other 41 are what the `Invalid device id found in the application
manifest` warnings are about — the ids are fine, the local SDK just has nothing
to compile against.

Install them through the SDK Manager before packaging. Then, per device, at
minimum:

- Check the departure rows still fit. The layout derives row count from screen
  height at draw time, so it adapts, but a long label on a small round screen
  can still lose its edges — `ShowDest` off is the escape hatch and the defaults
  should suit the smallest supported screen, not the fr945.
- Check the heading glyph renders. `⇄` is in `HEADING_SEP`; the train emoji was
  dropped because it faces left on the fr945, and glyph coverage varies by
  device font.
- Check the glance. Many listed devices have no glance support at all — the
  widget works regardless, but the store description shouldn't promise it
  everywhere.

Cutting the device list to those actually tested is a legitimate first release.
Adding devices later is a normal update; shipping broken ones is a review risk.

## 3. Store listing assets

Not yet written. Needed:

- **Screenshots** from the simulator, per screen size the store asks for.
  Capture the populated departure board rather than the empty state.
- **Description** covering the two-leg cycle and the automatic switch — the
  behaviour is not self-evident from a screenshot, particularly the afternoon
  reversal.
- **A note that the app is UK-only**, since CRS codes will mean nothing to most
  of the store's audience.
- **Category** — most likely Widgets, though Connect IQ's categories shift; check
  what comparable transit apps use.
- **Launcher icon**: currently one SVG at `resources/drawables/launcher_icon.svg`.
  The build already warns it is scaled for fr945 (65x65 source, 40x40 target);
  other devices will want their own sizes.

## 4. Manifest and versioning

- App id `66ef5969-3c5e-4135-a773-a33d2e572412` is set and must stay stable —
  changing it makes a new app rather than an update.
- Version is `0.3.0`. Decide whether the first public release goes out as `1.0.0`.
- `minApiLevel` is `3.2.0`. Worth confirming it is still accurate given the
  SDK 9 fixes.
- Permissions are just `Communications`, which is the minimum for this app and
  easy to justify at review.

## 5. Before submitting

- Build the `.iq` package (not the sideload `.prg`) and keep the developer key
  safe — losing it means losing the ability to update the app.
- Run the tests: `monkeydo bin/test.prg fr945 -t`, currently 45 passing.
- Settings behave differently once published: a store install gets the Connect
  IQ settings UI in Garmin Connect, so `Stop3`/`Stop4` become editable on the
  phone rather than needing a rebuild. The README's sideloading caveats stop
  applying, and the description should not repeat them.
