# Prompt for generating the GarageFlow privacy policy

Paste everything inside the fenced block below into Claude (or any capable
model). The facts in it were read out of this repository — the manifest, the
`pubspec.yaml` dependency list, and the API's entity definitions — so the policy
it produces describes what the app *actually* does rather than what a template
assumes.

**Before you use the output**, read the "After you generate it" section at the
bottom. Two things in there will get the app rejected if you skip them.

---

```
You are drafting a privacy policy for a mobile app that is about to be
submitted to the Google Play Store. Write the finished policy itself — not
advice about writing one.

## The product

GarageFlow is an auto-workshop management app for Nepal. It has an Android
app (package `com.codecraft.garageflow`) and a companion web dashboard.
The interface is available in English and Nepali.

It serves two different kinds of people, and the policy must keep them
distinct throughout:

1. **Workshop staff** — owners, managers, mechanics and delivery drivers who
   work for a garage that subscribes to GarageFlow.
2. **Vehicle owners (customers)** — members of the public who book services,
   track repairs on their vehicle, and pay invoices.

## The relationship that shapes this policy

GarageFlow is multi-tenant. Each subscribing workshop is a separate tenant,
and its records are isolated from every other workshop's at the database
level.

This matters legally and must be stated plainly:

- For records a **workshop creates about its own customers** (customer
  contact details, vehicles, job cards, invoices), the **workshop is the data
  controller** and GarageFlow is the **processor** acting on its instructions.
- For **accounts people create for themselves** in the app, and for
  operating the service overall, **GarageFlow is the controller**.

Explain this in plain language, and tell customers that questions about their
service records should go to their workshop first, with GarageFlow's contact
as a fallback.

## Data actually collected

### Account information
- Full name, email address, phone number
- Password — stored only as a PBKDF2 hash, never in plain text
- Optional profile photo
- Company code (which workshop the account belongs to)

### Workshop and customer records
- Customer name, phone, email, postal address
- An optional map pin (latitude/longitude) for a customer's location, used
  for pickup-and-drop navigation. Most customers never set one.
- Vehicles, job cards, job line items, services
- Invoices and payment records
- Bookings and appointments
- Deliveries and delivery waypoints
- Notifications
- An activity log of actions taken in the system

### Photos
- Job photos taken with the camera or chosen from the gallery, to document
  vehicle condition and repair work. Camera access is optional — the gallery
  alone works, and the app still functions on a device with no camera.

### Location
- Foreground precise and approximate location (`ACCESS_FINE_LOCATION`,
  `ACCESS_COARSE_LOCATION`).
- Two uses only: sorting the garage directory by how near each workshop is,
  and reporting a delivery driver's position while a delivery is in progress.
- **The app never requests background location.** Driver tracking runs only
  while the app is open on screen and stops when they leave it. State this
  explicitly and prominently — it is a meaningful limit, not boilerplate.
- Location is optional. Declining it leaves the whole app usable, with an
  alphabetical garage directory instead of a nearest-first one.

### Support conversations
- Messages sent to the in-app support chatbot, and the resulting threads.

### Stored on the device only
- Authentication tokens, held in the Android Keystore via
  EncryptedSharedPreferences — never in plain preferences.
- Display settings: theme, language, text size, and whether app lock is on.
- Biometric app lock authenticates against the fingerprint or face already
  enrolled on the phone. **The app never receives, sees or stores biometric
  data**, and biometrics never replace the GarageFlow password.

## Third parties that receive data

Cover each of these, saying what is shared and why:

- **Anthropic (Claude)** — support chatbot messages are sent to Anthropic's
  API to generate replies. Tell users not to put sensitive personal
  information into the chatbot. Note that when the AI is not enabled the
  chatbot answers from a scripted FAQ and passes anything else to a human,
  and no message leaves the server.
- **eSewa** and **Khalti** — Nepali payment gateways. Payment is completed on
  the provider's own page; GarageFlow records the transaction reference and
  amount and **never sees or stores card or wallet credentials**.
- **Google Sign-In** — optional. When a user chooses it, Google supplies their
  email, name and profile picture. It is an alternative to a password, not a
  requirement, and the button is hidden entirely when not configured.
- **OpenStreetMap** — supplies map tiles. Tile requests reach the tile server
  with the user's IP address and the area of the map being viewed. No API key
  and no Google Maps billing account is involved.
- **External map applications** — tapping "navigate" hands a destination to
  whatever map app the phone has installed, at which point that app's own
  privacy policy applies.
- **Email delivery** — transactional email only: password resets, booking
  confirmations, invoices.

## What does NOT happen

State each of these directly. They are true of this app and users benefit
from seeing them:

- No advertising SDKs, and no ads.
- No third-party analytics or behavioural tracking.
- No advertising identifier is collected.
- Personal data is never sold, and never shared for advertising.
- Data is not shared between workshops. Tenant isolation is enforced by the
  database, not by convention.

## Sections the policy must contain

1. Who we are and how to contact us (leave clear `[PLACEHOLDER]` markers for
   company legal name, postal address, support email, and a data-protection
   contact)
2. Which data is collected, in the two-audience split described above
3. Why each category is collected, and the legal basis for it
4. Third-party recipients and international transfer (note that some
   processors are outside Nepal)
5. How long data is kept, and what happens to a workshop's data when its
   subscription ends
6. Security measures — hashed passwords, encrypted token storage, tenant
   isolation, encryption in transit
7. User rights: access, correction, deletion, export, withdrawing consent
8. **How to request account deletion** — Google Play requires this to be
   reachable, so give a concrete route, not just an email address
9. Children — the app is not directed at children under 16 and does not
   knowingly collect their data
10. Permissions, each one named with the reason it is requested and what is
    lost by declining
11. How changes to the policy are communicated
12. Effective date and last-updated date (as `[PLACEHOLDER]`)

## Legal framing

Primary jurisdiction is **Nepal** — reference the Individual Privacy Act,
2075 (2018). Also satisfy **Google Play's User Data policy** and its Data
Safety requirements. Include a short GDPR section covering rights for any
users in the EU/UK.

## How to write it

- Plain language a vehicle owner can follow. No unexplained legal jargon.
- Headings and short paragraphs; bullet lists where they genuinely help.
- Specific, never hedged: say what happens, not what "may" happen. If
  something is optional, say what happens when it is declined.
- Do not invent facts. Anything not given above — retention periods, company
  name, addresses — must appear as an obvious `[PLACEHOLDER]` for me to fill.
- Output as Markdown.
- End with a short, clearly-labelled note listing every `[PLACEHOLDER]` I
  still need to complete, and any point you think a lawyer should review.
```

---

## After you generate it

**1. The Data safety form is separate, and must match.**
Play Console asks you to declare data collection in a form of its own. A
policy that says one thing and a form that says another is one of the most
common causes of rejection. Fill the form from the same facts listed above.

**2. The policy needs a public URL before you can submit.**
Play requires a link that is reachable without signing in. A page on your own
domain is the usual answer; the file has to stay at that URL for as long as
the app is listed.

**3. Location will attract scrutiny.**
Declaring `ACCESS_FINE_LOCATION` triggers review. Two things work in your
favour and are worth stating in the listing as well as the policy: the app
never asks for background location, and it remains fully usable if location
is refused.

**4. This is a draft, not legal advice.**
A generated policy is a solid starting point and is far better than a
template, because it describes what this app actually does. It is still worth
a lawyer's read before you publish — particularly the controller/processor
split, which is the part that decides who answers a complaint from a
workshop's customer.
