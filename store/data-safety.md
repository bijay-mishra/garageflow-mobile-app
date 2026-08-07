# Play Console → Data safety

Answers for the Data safety form, derived from what the code actually does:
the entity definitions in `GarageFlow.Api/Domain`, the manifest permissions,
and the `pubspec.yaml` dependency list.

Keep this and the privacy policy saying the same thing. A mismatch between the
two is one of the most common causes of rejection.

---

## Blocker: account deletion does not exist yet

The app has a sign-up screen, so Google requires a way to delete the account —
**both** in-app and at a publicly reachable URL that works without installing
the app.

There is currently no delete-account route in the app and no endpoint in the
API. `AuthController` has `HttpDelete("photo")` and nothing else.

Until that is built, the honest answer to "Do you provide a way for users to
request that their data is deleted?" is **No**, and that answer on its own can
fail review for an app with accounts.

Deleting a customer is not a simple `DELETE`. Their job cards and invoices are
another tenant's business records, and a workshop has tax reasons to keep them.
The usual resolution is to delete the login and the personal fields, and keep
the invoice as an anonymised record. Worth deciding deliberately rather than
discovering at review.

---

## Section 1 — Data collection and security

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** — but only true if the shipped build points at HTTPS. `network_security_config.xml` permits cleartext for local development addresses only, so this holds as long as the release build is not aimed at an `http://` host. |
| Do you provide a way for users to request that their data is deleted? | **Not yet** — see the blocker above. |

---

## The form has three steps

Play Console shows each as "Not started" until you finish it:

1. **Overview** — the three questions in Section 1 above.
2. **Data types** — the checklist. Tick `Collected` (and `Shared`, which for
   this app is never) on each type in the tables below.
3. **Data usage and handling** — this is where the extra options appear. Every
   type you ticked gets its own panel asking the same four questions.

### The four follow-up questions, and the answer for this app

Whichever data type you are on, the panel asks:

**1. "Is this data processed ephemerally?"** → **No**, for every single type.

Ephemeral means held in memory, used, and thrown away without ever being
written down. GarageFlow writes everything to SQL Server, so nothing qualifies.
Answer No each time — even for location, because the customer map pin and the
driver's delivery points are both stored rows.

**2. "Is this data required, or can users choose?"** → varies; the
`Required / Optional` column in the tables below is this answer.

- *Required* — the user cannot turn it off and still use the app.
- *Users can choose* — the app works without it. Location belongs here: refuse
  it and the garage directory just sorts alphabetically instead.

**3. "Why is this user data collected?"** → the `Purpose` column below. Tick
every one that applies. Play offers seven; four are never ticked for this app:

| Purpose | Use it? |
|---|---|
| App functionality | **Yes** — on every type |
| Account management | **Yes** — on name, email and user IDs |
| Fraud prevention, security and compliance | **Yes** — on app interactions only, for the audit log |
| Analytics | No — there is no analytics SDK in the app |
| Advertising or marketing | No — no ads, no marketing messages |
| Personalisation | No — nothing profiles the user or recommends content |
| Developer communications | No — notifications are about the user's own job and bill, which is app functionality, not news about the app |

**4. "Why is this user data shared?"** → never appears, because nothing is
marked Shared.

---

## Section 2 — Data types

Only the rows marked **Yes** get ticked. Everything else is left unchecked.

### Location

| Data type | Collected | Shared | Optional? | Purpose |
|---|---|---|---|---|
| Approximate location | **Yes** | No | Optional | App functionality |
| Precise location | **Yes** | No | Optional | App functionality |

Collected rather than ephemeral: a customer's map pin is stored on
`Customer.Latitude/Longitude`, and a driver's position is written to
`DeliveryPoint` rows during a delivery.

### Personal info

| Data type | Collected | Shared | Optional? | Purpose |
|---|---|---|---|---|
| Name | **Yes** | No | Required | App functionality, Account management |
| Email address | **Yes** | No | Required | App functionality, Account management |
| User IDs | **Yes** | No | Required | App functionality, Account management |
| Phone number | **Yes** | No | Optional | App functionality |
| Address | **Yes** | No | Optional | App functionality |
| Race and ethnicity | No | | | |
| Political or religious beliefs | No | | | |
| Sexual orientation | No | | | |
| Other info | No | | | |

### Financial info

| Data type | Collected | Shared | Optional? | Purpose |
|---|---|---|---|---|
| User payment info | **No** | | | Payment is completed on eSewa's or Khalti's own page. The app never receives card or wallet credentials. |
| Purchase history | **Yes** | No | Required | App functionality — invoices and payment records |
| Credit score | No | | | |
| Other financial info | No | | | |

### Messages

| Data type | Collected | Shared | Optional? | Purpose |
|---|---|---|---|---|
| Emails | No | | | |
| SMS or MMS | No | | | |
| Other in-app messages | **Yes** | No | Optional | App functionality — the support chat |

### Photos and videos

| Data type | Collected | Shared | Optional? | Purpose |
|---|---|---|---|---|
| Photos | **Yes** | No | Optional | App functionality — job photos and profile picture |
| Videos | No | | | |

### App activity

| Data type | Collected | Shared | Optional? | Purpose |
|---|---|---|---|---|
| App interactions | **Yes** | No | Required | App functionality, Fraud prevention and security — the `Activity` audit log |
| Other user-generated content | **Yes** | No | Required | App functionality — vehicles, job cards, bookings, feedback |
| In-app search history | No | | | Search filters the list on the device; nothing is stored. |
| Installed apps | No | | | |
| Other actions | No | | | |

### Everything else — leave entirely unchecked

Health and fitness · Audio files · Files and docs · Calendar · Contacts ·
Web browsing · Device or other IDs

**App info and performance** (crash logs, diagnostics, other performance data)
is also **No**. There is no Crashlytics or analytics SDK in the app. Crash data
that Google Play gathers by itself does not have to be declared.

---

## Why "Shared" is No everywhere

"Shared" means transferred to a third party. Google excludes transfers to a
**service provider** processing data on your behalf, which covers every third
party this app touches:

| Third party | Why it is not "sharing" |
|---|---|
| Anthropic | Processes support-chat messages to generate a reply, on your instruction. A processor. |
| Email provider | Sends transactional mail on your instruction. |
| eSewa / Khalti | The user enters their own payment details on the provider's page. A user-initiated transfer, and a processor relationship for the reference and amount you keep. |
| Google Sign-In | Data flows *in* from Google. Nothing goes out. |
| OpenStreetMap | Receives tile requests, not user data you collected. |

Declare each of these in the **privacy policy** regardless — the Data safety
form's definition of sharing is narrower than what a policy should disclose.

---

## What is deliberately not declared

Data that never leaves the phone is not "collected" under Google's definition:

- Sign-in tokens in `flutter_secure_storage`
- Theme, language, text size and app-lock preference in `shared_preferences`
- Biometrics — `local_auth` checks against the phone's enrolled fingerprint or
  face. The app never receives biometric data, so there is nothing to declare.
