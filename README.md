# GarageFlow Mobile

One Flutter app, two audiences. The role on the login response decides which
shell you get — a **mechanic** works the jobs assigned to them, a **customer**
books services and follows their vehicle. Staff belong on the
[dashboard](../garageflow-dashboard) and the app tells them so rather than
dropping them into an empty screen.

Backed by [garageflow-api](../garageflow-api).

## Run it

The API has to be running first:

```bash
cd ../garageflow-api/src/GarageFlow.Api
dotnet run --launch-profile http
```

Then:

```bash
flutter pub get
flutter run
```

### Pointing it at your server

The default is `http://202.51.3.68:8013` — the live API server. A build made
with no flags at all reaches something real, which is the point of the default.
It is plain HTTP for now, so passwords and tokens are not encrypted in transit;
that changes when `https://app.bijayamishra.com.np` is serving the API, at
which point `apiBaseUrl` in [config.dart](lib/core/config.dart) goes back to it.

To develop against an API on your own machine instead:

| Where you are running | Pass this |
| --- | --- |
| Android emulator | `--dart-define=API_BASE_URL=http://10.0.2.2:5100` |
| iOS simulator | `--dart-define=API_BASE_URL=http://localhost:5100` |
| Real phone on your wifi | `--dart-define=API_BASE_URL=http://192.168.x.x:5100` |

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:5100
```

`10.0.2.2` is the emulator's alias for the host machine, and this trips everyone
up once: inside the emulator `localhost` is the *emulator*, not your PC, so a
server that is plainly running looks dead.

Any host you point at over plain HTTP must also be listed in
`android/app/src/main/res/xml/network_security_config.xml` (and
`ios/Runner/Info.plist` for iOS), or the request never leaves the phone and the
failure reads like a dead network rather than a blocked one.

## Continue with Google

Off unless a client ID is compiled in, and *silently* off: the button, the
"or continue with email" divider and the space around them all disappear
together, so a build without the flag looks like an app that never had the
feature rather than one with something broken in it.

```bash
flutter run \
  --dart-define=API_BASE_URL=http://localhost:5100 \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=848081241872-cvgj8m47gh0kj959qoskak8pq1bmclip.apps.googleusercontent.com
```

That is the **Web** client, not the Android one, and the distinction is the
single thing most likely to cost you an afternoon. The Android client
(`...-83p0j954...`) is matched by package name plus SHA-1 and never appears in
code; the Web client is what the ID token is minted for, which is what the API
checks the audience against. Passing the Android id here returns no ID token at
all.

Both ids are registered in the API's `GoogleAuth:ClientIds`. Neither is a
secret — the Web client's *secret* is unused by this flow and must not be
committed. Register both SHA-1s on the Android client, debug and release, or the
flow works in one build and not the other:

```
debug     4B:46:A7:5F:4D:13:4F:43:79:C9:75:0D:4E:4D:53:96:64:A3:26:4A
release   9D:D1:E9:07:C4:59:C5:C7:9B:5A:D1:FB:4A:EA:AE:7D:C4:46:FF:F9
```

While the OAuth consent screen is in **Testing**, only accounts on its test-user
list can sign in — everyone else is refused before the app sees anything.

The button shows on the customer side only. Staff accounts are issued by their
workshop and a Google account proves an email address rather than employment, so
`AuthController.GoogleSignIn` refuses anyone who is not a customer.

## Signing in

Three fields, same as the dashboard. Company code is easy to miss.

| | Company | Email | Password |
| --- | --- | --- | --- |
| Mechanic | `DEMO` | `mechanic@garageflow.demo` | `demo1234` |
| Customer | `DEMO` | `customer@garageflow.demo` | `demo1234` |

Both are seeded by `DbSeeder.cs` on first run. The login screen lists them in
debug builds and compiles that panel out of a release build.

New accounts are created by the workshop from the dashboard
(`POST /api/users`) — there is no public sign-up anywhere in the API, which is
how a garage actually onboards people.

## What each side does

**Mechanic** — a summary of what is assigned, overdue first; a job detail with
the complaint, parts and photos; a status sheet that also records the odometer
and a work note; camera or gallery upload against a job.

**Customer** — vehicles and the work in progress on them with a progress bar;
book a service; the workshop's photos; a service-history timeline; the
notification feed.

Notifications are **polled, not pushed**. `GET /api/notifications` every 30
seconds while the app is open, with the badge refreshed from a cheap
`unread-count` call and the full feed pulled only when that number moves. It
needs no Firebase project and no credentials — the trade is that nothing
arrives while the app is closed. Adding FCM later means sending a copy of these
rows, not replacing them.

## Layout

```
lib/
  core/          config, dio client with refresh, secure storage, theme, formatters
  models/        the API's shapes
  services/      one class per API area — screens never touch dio
  state/         AuthController and NotificationController (ChangeNotifier)
  features/
    auth/        login, splash
    mechanic/    jobs, detail, status sheet, photo upload
    customer/    home, booking, job detail, history
    notifications/
    shared/      account, photo viewer
  widgets/       chips, states, tiles
```

Two rules hold the thing together:

**Every request goes through `core/api_client.dart`.** It unwraps the
`{ data, status, message }` envelope, refreshes an expired access token exactly
once for a burst of parallel 401s, and turns every failure into an
`ApiException` carrying the server's own sentence. Screens show `message`
verbatim — the API writes those to be read by a person.

**The server decides what you can see.** No mobile endpoint takes a mechanic
name or a customer id; each one scopes to the signed-in account, read from the
database rather than the token so a staff edit takes effect immediately. A job
belonging to another mechanic answers exactly as one that does not exist.

## Tests

```bash
flutter analyze   # clean
flutter test      # 15 tests
```

`test/app_smoke_test.dart` imports every screen so the whole tree has to
compile, and boots the app to prove the provider graph is wired.

## Building

Producing an APK needs the Android SDK (`ANDROID_HOME`), which is separate from
the Flutter SDK:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.yourshop.com
```
