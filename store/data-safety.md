# Play Console → Data safety

Answers for the Data safety form, derived from what the code actually does:
the entity definitions in `GarageFlow.Api/Domain`, the manifest permissions,
and the `pubspec.yaml` dependency list.

Keep this and the privacy policy saying the same thing. A mismatch between the
two is one of the most common causes of rejection.

---

## Account deletion — built, in-app

Google requires an app with a sign-up screen to offer account deletion. The
in-app half is done:

**Account → Delete account**, customer accounts only. The screen states what is
removed and what the workshop keeps, asks for the password, and confirms in a
dialog before anything happens. `POST /api/auth/delete-account` records the
request, revokes every session, and the account is erased for good 30 days
later by `AccountPurgeService` — a daily sweep, not a promise. Signing in
during those 30 days cancels it, which is the only way to cancel it and the
reason the endpoint ends the session rather than leaving the app signed in.

Mechanics do not get the option, and the endpoint refuses them with a 403. A
mechanic's login was issued by the workshop that employs them and is that
workshop's to withdraw, on the dashboard.

Deleting a customer was never a simple `DELETE`, and the split is deliberate —
see `AccountDeletion` in the API for the whole of it:

| Removed outright | Kept, anonymised |
|---|---|
| The login, password hash, name, email, phone, photo | The customer row each garage holds |
| Every refresh token and notification | Past job cards and invoices pointing at it |
| Support conversations they opened | |
| Membership of every garage joined | |

The customer row survives with its name, phone, email, address and map pin
cleared. A workshop's invoices are its own business records and it has tax
reasons to keep them; what the product can promise is that they stop naming
anybody.

### Still missing: the public deletion URL

Google asks for **two** routes, and only one exists. The second is a web page,
reachable without installing the app, where somebody can request deletion —
typically a form on the marketing site that reaches the same endpoint. There is
no such page yet, so the answer below is a qualified yes and the reviewer may
still ask for it. This is the remaining piece of the requirement.

---

## Section 1 — Data collection and security

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Not as the app is built today.** See the blocker below. |
| Do you provide a way for users to request that their data is deleted? | **Yes, in-app.** The public web URL is still outstanding — see above. |

---

## Blocker: the API is served over plain HTTP

`AppConfig.apiBaseUrl` points at `http://202.51.3.68:8013`, and
`network_security_config.xml` names that host so Android permits the cleartext.
The app works. Everything it sends — the password typed at sign-in, the bearer
token on every request afterwards, customer names, phone numbers, addresses,
invoice amounts — travels unencrypted, readable by anything between the phone
and the server.

That is a reasonable state for a test build. It is not one to publish:

- **The answer above becomes No.** Google asks the encryption question
  directly, and answering Yes on an HTTP build is a false declaration on a
  binding form, which is a worse problem than the missing encryption.
- Play flags cleartext during pre-launch review. It is not an automatic
  rejection, but on an app handling accounts and payment records it invites the
  scrutiny you least want.
- The privacy policy will claim data is protected in transit. It would not be.

The fix is a certificate on the server, not a change in the app. Once
`https://` works, three edits and the problem is gone for good:

1. `lib/core/config.dart` — change the scheme in `apiBaseUrl`.
2. `android/app/src/main/res/xml/network_security_config.xml` — delete the
   `202.51.3.68` line, putting the app back to HTTPS-only.
3. This file — set the encryption answer back to **Yes**.

A free Let's Encrypt certificate needs a hostname pointed at the box; it cannot
be issued for a bare IP address. So the real prerequisite is a domain name.

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
