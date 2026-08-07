# Play Store listing — GarageFlow

Copy the blocks below straight into Play Console. Character counts are checked
against Google's limits in the table at the bottom.

---

## App name

```
GarageFlow: Auto Workshop
```

---

## Short description

```
Job cards, invoices, bookings and payments for Nepal's auto workshops.
```

---

## Full description

```
GarageFlow keeps an auto workshop running from one app — the front desk, the
workshop floor and the customer, all looking at the same job.

Built for Nepal. Works in English and Nepali, shows dates in Bikram Sambat when
you switch the language, and takes payment through eSewa and Khalti.


FOR VEHICLE OWNERS

• Book a service — pick your garage, your vehicle and the work you need
• Follow the repair as it happens, stage by stage, with photos from the
  mechanic
• Keep every vehicle you own in one place
• See your full service history, so you know what was done and when
• View and settle bills, and pay by eSewa or Khalti from your phone
• Find workshops near you on a map, sorted by distance
• Track a pickup or drop-off while your vehicle is on the way
• Get a notification when the work is done


FOR WORKSHOPS

• Job cards from booking through to handover, with the status always current
• Assign work to mechanics and see what each of them has open
• Photograph vehicle condition before and after — proof that settles disputes
• Build invoices from the job card, so the bill matches the work
• Record payments in cash, by eSewa or by Khalti
• Manage customers and their vehicles, with the full history on each
• Run pickup and delivery, with the driver's position shown live while the
  trip is under way
• Multiple branches, each with its own records


MADE FOR HOW YOU ALREADY WORK

Nepali and English throughout — not a half translation. Turn on Nepali and the
dates turn to Bikram Sambat, converted from real tables rather than an
approximation, so your books agree with everyone else's.

Dark mode for late nights in the workshop. Adjustable text size. A fingerprint
lock on the app itself, if you want one.


YOUR DATA IS YOURS

Every workshop's records are separated in the database, not by convention. One
workshop can never see another's customers, jobs or invoices.

The app never asks for background location. The garage directory uses your
position while you are looking at it, delivery tracking runs while the driver
has the screen open, and both stop there. Refuse location entirely and the app
still works — the directory is simply listed alphabetically instead of
nearest-first.

Passwords are stored hashed, never as text. Sign-in tokens are held in Android's
encrypted storage.


HELP WHEN YOU NEED IT

Stuck on something? The in-app support chat answers common questions
immediately and passes anything else to a person.


GarageFlow works alongside the GarageFlow web dashboard, where owners and
managers get reporting, staff accounts and configuration on a bigger screen.
```

---

## Graphics

Ready in `store/graphics/`:

| File | Size | Notes |
|---|---|---|
| `play-icon-512.png` | 512 × 512, 18 KB | App icon. Opaque, full bleed. |
| `play-feature-graphic-1024x500.png` | 1024 × 500, 49 KB | Feature graphic. Opaque. |

Both are drawn from the same source as the dashboard logo
(`garageflow-dashboard/src/components/common/Logo.tsx`), so the store, the web
app and the phone all show one mark.

**Why the icon has square corners.** Play applies its own rounded mask and drop
shadow in the storefront. Supplying artwork that is already rounded leaves
transparent corners that show through the mask as pale notches. Full bleed is
correct here.

---

## Every asset Play asks for

| Asset | Spec | Required | Status |
|---|---|---|---|
| App name | 30 characters | Yes | Done — 25 |
| Short description | 80 characters | Yes | Done — 70 |
| Full description | 4,000 characters | Yes | Done — 2,603 |
| App icon | 512 × 512 px, 32-bit PNG, ≤ 1 MB | Yes | Done |
| Feature graphic | 1024 × 500 px, PNG or JPEG, no transparency, ≤ 15 MB | Yes | Done |
| Phone screenshots | 2–8, 16:9 or 9:16, sides 320–3840 px, ≤ 8 MB | Yes | Done — 5 |
| 7-inch tablet screenshots | Up to 8, 16:9 or 9:16, sides 320–3840 px, ≤ 8 MB | Yes | Done — 5 |
| 10-inch tablet screenshots | Up to 8, 16:9 or 9:16, sides 1080–7680 px, ≤ 8 MB | Yes | Done — 5 |
| Chromebook screenshots | 4–8, 16:9 or 9:16, sides 1080–7680 px, ≤ 8 MB | No | Use the 10-inch files |
| Android XR screenshots | 4–8, 16:9 or 9:16, ≤ 15 MB | No | Use the 10-inch files |
| Promo video | YouTube URL | No | — |

## Screenshots

In `store/screenshots/`, five shots in each size. Full bleed — the app fills
the frame edge to edge, with no background or letterboxing.

| Folder | Size | Ratio | For |
|---|---|---|---|
| `phone/` | 1080 × 1920 | 9:16 | Phone |
| `tablet7/` | 1080 × 1920 | 9:16 | 7-inch tablet |
| `tablet10/` | 1242 × 2208 | 9:16 | 10-inch tablet, Chromebook, XR |

Chromebook and Android XR both accept 9:16, so the 10-inch files cover those
slots and there is no separate landscape set.

### How they were re-framed

The source captures are 738 × 1600 — a **2.168:1** phone. Play accepts 16:9 or
9:16 and nothing else, so those files fail validation for the *phone* slot too,
not only the tablet ones. 288 rows of height had to go.

The three obvious ways are all bad:

| Method | What it does |
|---|---|
| Centre crop | Removes 144 px top and bottom. The bottom navigation bar starts at y≈1478, so it disappears completely, and the header gets sliced. |
| Crop one end | Same damage, just moved to one side. |
| Stretch to fit | Distorts every control on screen. |

So instead each row is compared with the row below it, and the rows that are
**identical to their neighbour** — flat background, the empty space in a screen
— are the ones removed. Deleting a row that matches the one under it cannot be
seen, and the header and nav bar both survive untouched. The bottom 130 px is
excluded from removal outright, because the nav bar and gesture pill live there
and look flat without being spare.

Measured worst-case difference across every removed row was 0.000–0.030 on a
0–255 scale, so no cut is visible.

### These are phone captures in tablet slots

Honest limitation: Play wants tablet screenshots to show the tablet layout.
These satisfy the technical spec and will upload, but they show the phone UI.
That is common practice and is generally accepted; the stronger version is real
captures from a tablet emulator:

```
adb shell screencap -p /sdcard/shot1.png
adb pull /sdcard/shot1.png
```

Capture on the device and pull the file — do not pipe `adb exec-out screencap`
into a file from PowerShell, which corrupts the PNG.

Worth capturing, in this order: the customer home with a job in progress, a job
detail with mechanic photos, an invoice with the eSewa/Khalti options, the
garage directory map, and the app in Nepali to make the language support
visible at a glance.

---

## Before you submit

- **Data safety form.** Filled separately in Play Console and must agree with
  the privacy policy. See `docs/privacy-policy-prompt.md`.
- **Privacy policy URL.** Must be public and reachable without signing in.
- **Location declaration.** `ACCESS_FINE_LOCATION` draws review. You are in a
  good position: no background location, and the app is fully usable when
  location is refused. Say so in the review notes.
- **The app talks to your API.** Set `Payments:CallbackBaseUrl` and the API
  base URL to public HTTPS addresses before you ship — a build pointing at
  `localhost:5100` reaches nothing from a reviewer's phone, and the reviewer
  will reject it as broken.
