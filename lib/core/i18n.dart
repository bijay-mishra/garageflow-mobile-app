import 'package:flutter/widgets.dart';

/// English and Nepali, as flat key → string maps.
///
/// The same approach the dashboard uses in `src/lib/i18n.ts`, and deliberately
/// so: the two products say the same things to the same people, and a phrase
/// translated once should read identically on the web screen and the phone.
///
/// No code generation and no ARB files. This app has a few hundred strings, one
/// translator, and no plural or gender rules to speak of — `intl`'s machinery
/// would be more moving parts than the problem has.
///
/// A missing key falls back to English, then to the key itself. Nothing ever
/// throws and nothing renders blank, so a half-finished translation degrades to
/// English rather than to an empty screen.
class AppText {
  const AppText(this.languageCode);

  final String languageCode;

  static AppText of(BuildContext context) =>
      _Localization.of(context)?.text ?? const AppText('en');

  /// Looks up [key], substituting `{0}`, `{1}`… with [args].
  String call(String key, [List<Object?> args = const []]) {
    final table = languageCode == 'ne' ? _ne : _en;
    var value = table[key] ?? _en[key] ?? key;

    for (var i = 0; i < args.length; i++) {
      value = value.replaceAll('{$i}', '${args[i]}');
    }

    return value;
  }

  /// Every language the app offers, in its own script — a person looking for
  /// Nepali is looking for "नेपाली", not for the word "Nepali".
  static const languages = [
    (code: 'en', label: 'English', native: 'English'),
    (code: 'ne', label: 'Nepali', native: 'नेपाली'),
  ];

  /// Every key, so a test can check the tables agree.
  ///
  /// English is the source of truth: a key that exists only in Nepali would be
  /// dead weight nothing renders, while one missing from Nepali is a line of
  /// English on an otherwise Nepali screen. Only the second is a bug worth
  /// failing a build over, so this lists the English keys.
  static Iterable<String> get keys => _en.keys;
}

/// Puts the active [AppText] in the tree so `AppText.of(context)` can find it.
class AppLocalizations extends StatelessWidget {
  const AppLocalizations({
    super.key,
    required this.languageCode,
    required this.child,
  });

  final String languageCode;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      _Localization(text: AppText(languageCode), child: child);
}

class _Localization extends InheritedWidget {
  const _Localization({required this.text, required super.child});

  final AppText text;

  static _Localization? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Localization>();

  @override
  bool updateShouldNotify(_Localization old) =>
      old.text.languageCode != text.languageCode;
}

// ── English ──────────────────────────────────────────────────────────────────

const Map<String, String> _en = {
  // Common
  'common.retry': 'Try again',
  'common.cancel': 'Cancel',
  'common.more': 'More',
  'common.save': 'Save',
  'common.saving': 'Saving…',
  'common.close': 'Close',
  'common.confirm': 'Confirm',
  'common.delete': 'Delete',
  'common.free': 'Free',
  'common.refresh': 'Refresh',
  'common.back': 'Back',
  'common.loading': 'Loading…',
  'common.couldNotLoad': 'Could not load',
  'common.notSet': 'Not set',
  'common.on': 'On',
  'common.off': 'Off',
  'common.done': 'Done',

  // Sign in
  'auth.title': 'GarageFlow',
  'auth.tagline': 'Your workshop, in your pocket',
  'auth.customer': 'Customer',
  'auth.staff': 'Workshop staff',
  'auth.companyCode': 'Company code',
  'auth.companyCodeHint': 'Given to you by your workshop',
  'auth.email': 'Email',
  'auth.password': 'Password',
  'auth.signIn': 'Sign in',
  'auth.signOut': 'Sign out',
  'auth.signOutConfirm': 'You will need your password to sign back in.',
  'auth.newHere': 'New here?',
  'auth.createAccount': 'Create a free account',
  'auth.haveAccount': 'Already have an account?',
  'auth.enterEmail': 'Enter your email',
  'auth.enterPassword': 'Enter your password',
  'auth.badEmail': 'That does not look like an email address',
  'auth.enterCompanyCode': 'Enter your company code',
  'auth.showPassword': 'Show password',
  'auth.hidePassword': 'Hide password',
  'auth.or': 'or',
  'auth.orWithEmail': 'or continue with email',
  'auth.sessionExpired': 'Your session has expired. Please sign in again.',
  'auth.passwordChangedNotice':
      'Your password was changed. Please sign in again.',

  // ── Chat with the garage ────────────────────────────────────────────────
  'support.title': 'Help',
  'support.subtitle': 'Ask about your vehicle or a bill',
  'support.withGarage': 'The garage is answering',
  'support.past': 'Past conversations',
  'support.newChat': 'New conversation',
  'support.loading': 'Loading…',
  'support.thinking': 'Thinking…',
  'support.placeholder': 'Type your question…',
  'support.talkToGarage': 'Talk to the garage instead',
  'support.garageHasIt': 'The garage has this. They will reply here.',
  'support.waiting': 'waiting',
  'support.aiAnswer': 'AI answer',
  'support.introTitle': 'Ask us anything',
  'support.introBody':
      'When your vehicle will be ready, what is on a bill, how to book a '
      'service. The assistant answers straight away and passes anything it '
      'cannot to the garage.',

  // The sign-in screen is a customer screen. Staff reach their form through a
  // door off the side of it, rather than everyone having to answer "who are
  // you" before they can type — see the note on _SignInAs in login_screen.dart.
  'auth.staffPrompt': 'Work at a garage?',
  'auth.staffLink': 'Staff sign-in',
  'auth.staffTitle': 'Staff sign-in',
  'auth.staffSubtitle':
      'For mechanics and workshop staff. You will need the company code your '
      'workshop gave you.',
  'auth.backToCustomer': 'Back to customer sign-in',
  'auth.continueWithGoogle': 'Continue with Google',
  'auth.forgotPassword': 'Forgot password?',
  'auth.rememberMe': 'Remember me',
  'auth.rememberMeHint':
      'Your email and password stay on this phone, in its encrypted store, so '
          'this form opens filled in. Untick to remove them.',
  'forgot.title': 'Reset password',
  'forgot.intro': 'Tell us the email on your account and we will send a six-digit code.',
  'forgot.send': 'Send code',
  'forgot.checkEmail': 'Check your email',
  'forgot.noEmailNote': 'Nothing arrived? Check your spam folder, or ask the workshop — they can reset it for you.',

  // Step two: the code
  'forgot.codeTitle': 'Enter the code',
  'forgot.codeSent': 'We sent a six-digit code to {0}. It expires in {1} minutes.',
  'forgot.code': 'Six-digit code',
  'forgot.enterCode': 'Enter the code from your email',
  'forgot.badCode': 'The code is six digits',
  'forgot.continue': 'Continue',
  'forgot.resend': 'Send a new code',
  'forgot.resendIn': 'Resend in {0}s',
  'forgot.wrongAddress': 'Wrong address?',

  // Step three: the new password
  'forgot.newTitle': 'Choose a new password',
  'forgot.newIntro': 'You will need to sign in again on your other devices.',
  'forgot.newPassword': 'New password',
  'forgot.confirmPassword': 'Confirm new password',
  'forgot.enterNewPassword': 'Choose a password',
  'forgot.shortPassword': 'Use at least 8 characters',
  'forgot.mismatch': 'Both passwords must match',
  'forgot.save': 'Reset password',
  'forgot.done': 'Password updated',
  'forgot.doneNote': 'Sign in with your new password.',

  // First sign-in on an account somebody else created. The wording avoids
  // "temporary password", because the person usually does not know theirs was
  // one — they were simply handed a password by whoever set the account up.
  'setPassword.title': 'Choose your password',
  'setPassword.greeting': 'Welcome, {0}',
  'setPassword.intro':
      'Your account was set up for you, so the password you just signed in with '
      'is known to whoever created it. Choose one only you know to carry on.',
  'setPassword.newPassword': 'New password',
  'setPassword.confirmPassword': 'Confirm new password',
  'setPassword.enterNewPassword': 'Choose a password',
  'setPassword.shortPassword': 'Use at least 8 characters',
  'setPassword.mismatch': 'Both passwords must match',
  'setPassword.save': 'Save and continue',
  'setPassword.done': 'Password set. You are signed in.',
  'setPassword.signOut': 'Sign out instead',

  // Sign up
  'signup.title': 'Create your account',
  'signup.subtitle': 'Then pick your garage',
  'signup.fullName': 'Full name',
  'signup.nameHint': 'Rita Shrestha',
  'signup.phone': 'Phone',
  'signup.phoneHelp': 'So the garage can reach you about your vehicle',
  'signup.passwordHelp': 'At least 8 characters',
  'signup.passwordShort': 'Use at least 8 characters',
  'signup.enterName': 'Enter your name',
  'signup.submit': 'Create account',
  'signup.footnote':
      'Free for customers. You choose which garages you use, and you can use '
          'more than one.',
  'signup.created': 'Your account is ready. Sign in to get started.',

  // Closing an account. Customers only — a mechanic's login belongs to the
  // workshop that issued it.
  'deleteAccount.title': 'Delete account',
  'deleteAccount.rowSub': 'Close your GarageFlow account for good',
  'deleteAccount.graceTitle': 'You have 30 days to change your mind',
  'deleteAccount.graceBody':
      'Nothing is deleted today. Your account is removed for good 30 days from '
          'now. Sign in again before then and it stays, exactly as it is.',
  'deleteAccount.whatGoes': 'What is deleted',
  'deleteAccount.goesLogin': 'Your login, name, email, phone and photo',
  'deleteAccount.goesGarages': 'Your membership of every garage you joined',
  'deleteAccount.goesMessages': 'Your notifications and support messages',
  'deleteAccount.whatStays': 'What the garage keeps',
  'deleteAccount.staysInvoices':
      'Past job cards and invoices, with your name removed',
  'deleteAccount.staysWhy':
      'A garage has to keep its own sales records for tax. Yours stay in its '
          'books with nothing on them that says who you were.',
  'deleteAccount.confirmPassword':
      'Type your password to confirm this is you.',
  'deleteAccount.action': 'Delete my account',
  'deleteAccount.keep': 'Keep my account',
  'deleteAccount.confirmTitle': 'Delete your account?',
  'deleteAccount.confirmBody':
      'You will be signed out now, and your account is deleted in 30 days. '
          'Signing in again before then cancels it.',
  'deleteAccount.confirmAction': 'Delete',
  'deleteAccount.scheduled':
      'Your account will be deleted on {0}. Sign in before then and it stays.',
  'deleteAccount.cancelled':
      'Welcome back. Your account is no longer being deleted.',

  // Garage directory
  'garages.choose': 'Choose a garage',
  'garages.find': 'Find a garage',
  'garages.chooseSubtitle': 'Pick where your vehicle is serviced',
  'garages.listed': 'Garages using GarageFlow',
  'garages.search': 'Search by name or area',
  'garages.join': 'Join this garage',
  'garages.joining': 'Joining…',

  // Asked before joining. {0} is the garage's name — named rather than "this
  // garage", because on a list of look-alike cards the whole point of the
  // question is to show which one the tap landed on.
  'garages.joinConfirmTitle': 'Join {0}?',
  'garages.joinConfirm':
      'They will be able to see your name, phone number and the vehicles you '
      'add here, so they can service them.',
  'garages.joinConfirmLeave': 'You can leave again at any time from your profile.',
  'garages.joinConfirmAction': 'Join',
  'garages.switchTo': 'Switch to this garage',
  'garages.viewing': 'You are viewing this garage',
  'garages.current': 'Current',
  'garages.joined': 'Joined',
  'garages.services': '{0} services',
  'garages.away': '{0} km away',
  'garages.noneTitle': 'No garages listed yet',
  'garages.noneMessage': 'Garages appear here once they choose to be listed.',
  'garages.sortedAZ': 'Sorted A–Z',
  'garages.finding': 'Finding garages…',
  'garages.noAddress': 'Address not published',
  'garages.sortNearest': 'Sort by nearest',
  'garages.noneJoined': 'You have not joined a garage yet',

  // Rewards, points and offers
  'rewards.title': 'Rewards',
  'rewards.rowSub': 'Your stamps, points and this garage\'s offers',
  'rewards.rowWorth': 'Worth {0} off your next bill',
  'rewards.rowToGo': '{0} more service(s) fills your card',
  'rewards.rowFree': '{0} free service waiting for you',
  'rewards.pillPoints': '{0} pts',
  'rewards.loading': 'Loading your rewards…',
  'rewards.noneTitle': 'No rewards scheme here',
  'rewards.noneMessage':
      'This garage does not run a loyalty scheme or any offers at the moment.',
  'rewards.freeService': 'A free service',
  'rewards.running': 'ON RIGHT NOW',
  'rewards.history': 'YOUR ACTIVITY',
  'rewards.readyOne': 'Ready to use — ask for your free {0}',
  'rewards.readyMany': '{0} free services waiting for you',
  'rewards.oneToGo': 'One more service and your {0} is free',
  'rewards.manyToGo': '{0} more services and your {1} is free',
  'rewards.askAtCounter':
      'Mention it when you collect the vehicle and the garage takes it off the bill.',
  'rewards.points': 'Points',
  'rewards.worth': 'worth {0}',
  'rewards.canSpend': 'You can put these towards your next bill.',
  'rewards.needMore': '{0} more points to start spending — {1} needed.',
  'rewards.until': 'Until {0}',

  // Rating a finished job
  'rate.title': 'How did we do?',
  'rate.subtitle': 'Your rating is shown to the workshop, never to other customers.',
  'rate.garage': 'The garage overall',
  'rate.mechanic': '{0}\'s work',
  'rate.comment': 'Anything to add?',
  'rate.commentHint': 'Optional',
  'rate.submit': 'Send rating',
  'rate.update': 'Update rating',
  'rate.thanks': 'Thank you for the feedback.',
  'rate.prompt': 'Rate this service',
  'rate.promptSub': 'Two quick questions — the garage, and the mechanic.',
  'rate.yours': 'Your rating',
  'rate.tapToChange': 'Tap to change',
  'rate.myRating': 'My rating',
  'rate.fromCount': 'From {0} customer rating(s)',
  'rate.notRatedYet': 'No ratings yet',

  // Mechanic
  'jobs.greeting': 'Hi, {0}',
  'jobs.active': 'Active jobs',
  'jobs.assigned': 'Assigned',
  'jobs.inProgress': 'In progress',
  'jobs.awaitingParts': 'Awaiting parts',
  'jobs.loading': 'Loading your jobs…',
  'jobs.emptyTitle': 'Nothing on your ramp',
  'jobs.emptyMessage': 'Jobs assigned to you will appear here.',
  'jobs.clearFilter': 'Clear',
  'jobs.overdueOne': '1 job is past its promised time',
  'jobs.overdueMany': '{0} jobs are past their promised time',
  'jobs.doneOne': '1 job finished today — nice work',
  'jobs.doneMany': '{0} jobs finished today — nice work',

  // Customer home
  'home.inWorkshop': 'In the workshop',
  'home.readyForYou': 'Ready for you',
  'home.yourBookings': 'Your bookings',
  'home.yourVehicles': 'Your vehicles',
  'home.bookService': 'Book service',
  'home.nothingIn': 'Nothing in the workshop',
  'home.tapToBook': 'Tap to book your next service',
  'home.askWorkshop': 'Add your vehicle to book a service',
  'home.loading': 'Loading your vehicles…',
  'home.noVehiclesTitle': 'No vehicles yet',
  'home.noVehiclesMessage':
      'Add the vehicle you want serviced. The workshop confirms the details '
          'when you first bring it in.',
  'home.percentComplete': '{0}% complete',
  'home.ready': 'Ready {0}',
  'home.photosFrom': '{0} photos from the workshop',
  'home.photoFrom': '1 photo from the workshop',
  'home.cancelBooking': 'Cancel booking',
  'home.yourGarages': 'Your garages',

  // Handover
  'handover.readyTitle': 'Your vehicle is ready',
  'handover.collect': 'I will collect it',
  'handover.collectSub': 'Come to the workshop whenever suits you',
  'handover.deliver': 'Deliver to my address',
  'handover.checking': 'Checking delivery to your address…',
  'handover.onBill': 'Added to your bill',
  'handover.fromWorkshop': '{0} km from the workshop',
  'handover.changeNote': 'You can change this by asking the workshop.',
  'handover.chooseCta': 'Choose how to get it back',
  'handover.workFinished': 'Work finished',
  'handover.workFinishedBody':
      'Tell the workshop whether you are collecting it or would like it '
          'delivered to you.',
  'handover.title': 'Handover',
  'handover.method': 'Method',
  'handover.homeDelivery': 'Home delivery',
  'handover.collection': 'Collection at the workshop',
  'handover.status': 'Status',
  'handover.address': 'Address',
  'handover.distance': 'Distance',
  'handover.fee': 'Delivery fee',
  'handover.driver': 'Driver',
  'handover.setOff': 'Set off',
  'handover.delivered': 'Delivered',
  'handover.collected': 'Collected',
  'handover.callWorkshop': 'Call the workshop',
  'handover.trackingNote':
      'Tracking updates while the driver has the app open. It can pause if '
          'they lose signal.',
  'handover.bringId': 'Bring some identification when you come to collect.',
  'handover.finding': 'Finding your vehicle…',
  'handover.notStarted': 'Not started yet',
  'handover.live': 'Live now',
  'handover.bringingIt': '{0} is bringing it',
  'handover.trip': '{0} km trip',

  // Driver
  'driver.handovers': 'Handovers',
  'driver.outForDelivery': '{0} out for delivery',
  'driver.waiting': '{0} waiting',
  'driver.nothingOut': 'Nothing waiting to go out',
  'driver.startRun': 'Start the run',
  'driver.starting': 'Starting…',
  'driver.openTrip': 'Open trip',
  'driver.markDelivered': 'Mark as delivered',
  'driver.collectedIt': 'Customer collected it',
  'driver.waitingCustomer': 'Waiting on the customer to choose',
  'driver.sharing': 'Sharing your location',
  'driver.sharingStops': 'Stops when you leave this screen',
  'driver.sent': '{0} sent',
  'driver.cannotSee': 'The customer cannot see where you are',
  'driver.stillWorks': 'You can still make the delivery and mark it done.',
  'driver.dropOff': 'Drop-off',
  'driver.navigate': 'Navigate',
  'driver.call': 'Call',
  'driver.emptyTitle': 'Nothing to hand over',
  'driver.emptyMessage':
      'Finished jobs appear here once the customer says how they want the '
          'vehicle back.',

  // Notifications
  'alerts.title': 'Notifications',
  'alerts.markAllRead': 'Mark all read',
  'alerts.emptyTitle': 'Nothing yet',

  // Bills & history
  'bills.title': 'Bills',
  'history.title': 'Service history',
  'booking.title': 'Book a service',

  // ── Profile ────────────────────────────────────────────────────────────────
  'profile.title': 'Profile',
  'profile.account': 'Account',
  'profile.accountSub': 'Your name, email and phone',
  'profile.security': 'Security',
  'profile.securitySub': 'App lock and password',
  'profile.appearance': 'Appearance',
  'profile.appearanceSub': 'Theme and text size',
  'profile.language': 'Language',
  'profile.featureRequest': 'Send feedback',
  'profile.featureRequestSub': 'Suggest a feature or report a problem',
  'profile.help': 'Help',
  'profile.helpSub': 'Contact your workshop',
  'profile.about': 'About',
  'profile.settings': 'Settings',
  'profile.workshop': 'The workshop',

  'profile.editPhoto': 'Change photo',
  'profile.takePhoto': 'Take a photo',
  'profile.choosePhoto': 'Choose from gallery',
  'profile.removePhoto': 'Remove photo',
  'profile.photoUpdated': 'Photo updated.',
  'profile.photoRemoved': 'Photo removed.',

  'account.title': 'Your account',
  'account.name': 'Name',
  'account.email': 'Email',
  'account.phone': 'Phone',
  'account.role': 'Role',
  'account.emailNote': 'Changing this changes what you sign in with.',
  'account.saved': 'Your details are saved.',
  'account.customerRef': 'Customer',
  'account.assignedAs': 'Assigned as',
  'account.companyCode': 'Company code',

  'security.title': 'Security',
  'security.appLock': 'Unlock with biometrics',
  'security.appLockSub':
      'Ask for your fingerprint or face before showing the app.',
  'security.appLockUnavailable':
      'This phone has no fingerprint or face unlock set up.',
  'security.locked': 'GarageFlow is locked',
  'security.unlock': 'Unlock',
  'security.unlockReason': 'Unlock GarageFlow',
  'security.unlockFailed': 'Could not verify. Try again.',
  'security.useSignOut': 'Sign out instead',
  'security.changePassword': 'Change password',
  'security.currentPassword': 'Current password',
  'security.newPassword': 'New password',
  'security.confirmPassword': 'Confirm new password',
  'security.passwordsDiffer': 'Those two passwords do not match',
  'security.passwordChanged': 'Password changed. Please sign in again.',
  'security.sessionNote':
      'Changing your password signs you out everywhere, including this phone.',

  'appearance.title': 'Appearance',
  'appearance.theme': 'Theme',
  'appearance.system': 'Follow the phone',
  'appearance.light': 'Light',
  'appearance.dark': 'Dark',
  'appearance.textSize': 'Text size',
  'appearance.preview': 'Preview',
  'appearance.previewPlate': 'BA 12 PA 3456',
  'appearance.previewLine': 'Honda City · Due tomorrow',

  'language.title': 'Language',
  'language.note':
      'This changes the app\'s own words. Anything typed by the workshop — '
          'service names, notes, your vehicle details — stays as they wrote it.',

  'feedback.title': 'Send feedback',
  'feedback.intro':
      'Tell us what would make this app better, or what is going wrong. This '
          'opens your email app so you can see exactly what is sent.',
  'feedback.subject': 'GarageFlow feedback',
  'feedback.compose': 'Write feedback',
  'feedback.noEmailApp': 'No email app to open this in.',
  'feedback.includes': 'Your message will include:',
  'feedback.appVersion': 'App version',
  'feedback.role': 'Your role',
  'feedback.nothingElse':
      'Nothing else is attached — no vehicle data and no photos.',

  'about.version': 'App',
  'about.server': 'Server',
  'about.accountManaged':
      'To change your password or your details, ask the workshop — accounts '
          'are managed from the dashboard.',

  // ── Shells ─────────────────────────────────────────────────────────────────
  'tab.myVehicles': 'Vehicles',
  'tab.myJobs': 'My jobs',
  'tab.history': 'History',
  'tab.bills': 'Bills',
  'tab.garages': 'Garages',
  'profile.notifications': 'Notifications',
  'profile.notificationsOn': 'Alerts about your jobs and bills are on',
  'profile.notificationsOff': 'Alerts are off — you can still read them in the app',
  'tab.alerts': 'Alerts',
  'tab.account': 'Account',

  // ── Adding a vehicle ───────────────────────────────────────────────────────
  'vehicle.addTitle': 'Add a vehicle',
  'vehicle.addCta': 'Add a vehicle',
  'vehicle.plate': 'Number plate',
  'vehicle.plateHint': 'BA 2 CHA 1234',
  'vehicle.plateRequired': 'Enter the number plate.',
  'vehicle.makeAndModel': 'Make and model',
  'vehicle.makeHint': 'Toyota',
  'vehicle.makeRequired': 'Enter the make.',
  'vehicle.modelHint': 'Corolla',
  'vehicle.modelRequired': 'Enter the model.',
  'vehicle.year': 'Year',
  'vehicle.yearRange': 'Enter a year between {0} and {1}.',
  'vehicle.type': 'What kind of vehicle?',
  'vehicle.fuel': 'Fuel',
  'vehicle.optional': 'Colour and odometer (optional)',
  'vehicle.colourHint': 'White',
  'vehicle.odometerHint': 'km on the clock',
  'vehicle.addNote':
      'The workshop confirms the details when you first bring the vehicle in.',
  'vehicle.addSubmit': 'Add vehicle',
  'vehicle.added': '{0} added to your account.',
  'vehicle.editTitle': 'Edit vehicle',
  'vehicle.edit': 'Edit details',
  'vehicle.updated': '{0} updated.',
  'vehicle.remove': 'Remove',
  'vehicle.removeTitle': 'Remove {0}?',
  'vehicle.removeBody':
      'This takes the vehicle off your account. If the garage has already '
          'serviced it, they keep that record and you will be asked to contact '
          'them instead.',
  'vehicle.removed': '{0} removed from your account.',

  // Values, not labels — see `vehicleTypes` and `fuelTypes`. Translated here
  // for display only; the English value is what goes to the API.
  'vehicleType.Bike': 'Bike',
  'vehicleType.Car': 'Car',
  'vehicleType.Van': 'Van',
  'vehicleType.Bus': 'Bus',
  'vehicleType.Truck': 'Truck',
  'vehicleType.Tractor': 'Tractor',

  'fuel.Petrol': 'Petrol',
  'fuel.Diesel': 'Diesel',
  'fuel.Electric': 'Electric',
  'fuel.Hybrid': 'Hybrid',
  'fuel.CNG': 'CNG',

  // ── Customer home dialogs ──────────────────────────────────────────────────
  'home.noVehiclesSnack':
      'Add a vehicle first — then you can book a service for it.',
  'home.bookingRequested': 'Booking requested.',
  'home.cancelTitle': 'Cancel booking?',
  'home.cancelBody': 'Your booking for {0} on {1} will be cancelled.',
  'home.keepIt': 'Keep it',
  'home.bookingCancelled': 'Booking cancelled.',
  'home.chooseHandover': 'Choose collection or delivery',
  'home.followMap': 'Follow it on the map',
  'home.checkingVehicles': 'Checking your vehicles…',
  'home.oneMoment': 'One moment',
  'home.extrasEstimate': 'Extras estimate',
  'home.preferredTime': 'Preferred time: {0}',
  'home.lastService': 'Last service {0}',

  // ── Customer job detail ────────────────────────────────────────────────────
  'job.notFound': 'Job not found.',
  'job.lookingAt': 'What we are looking at',
  'job.noDetails': 'No details recorded.',
  'job.bookedIn': 'Booked in',
  'job.readyBy': 'Ready by',
  'job.stageOpen': 'Booked in, work has not started yet.',
  'job.stageProgress': 'Being worked on now.',
  'job.stageParts': 'Waiting for parts to arrive.',
  'job.stageDone': 'Work finished — ready for collection.',
  'job.stageCollected': 'Collected. Thank you!',
  'job.stageCancelled': 'This job was cancelled.',
  'job.workAndParts': 'Work & parts',
  'job.estimatedTotal': 'Estimated total',
  'job.beforeTax': 'Before tax. Your invoice is the final figure.',
  'job.photosFromWorkshop': 'Photos from the workshop',

  // ── Mechanic job detail ────────────────────────────────────────────────────
  'job.markedStatus': 'Job marked {0}.',
  'job.serviceAdded': 'Added to the job card. The customer has been told.',
  'job.photoAdded': 'Photo added.',
  'job.deletePhoto': 'Delete photo?',
  'job.cannotUndo': 'This cannot be undone.',
  'job.photoDeleted': 'Photo deleted.',
  'job.updateStatus': 'Update status',
  'job.complaintNotes': 'Complaint & notes',
  'job.noComplaint': 'No complaint recorded.',
  'job.customerLocation': 'Customer location',
  'job.workOnThis': 'Work on this job',
  'job.nothingCosted': 'Nothing costed yet.',
  'job.addAWash': 'Add a wash or a polish if the car needs one.',
  'job.photosCount': 'Photos ({0})',
  'job.noPhotos': 'No photos yet.',
  'job.photosHelp': 'Photos help the customer see the work.',

  // ── Update status sheet ────────────────────────────────────────────────────
  'status.odometer': 'Odometer (km)',
  'status.odometerHelp': 'Optional — recorded against the vehicle too',
  'status.workNote': 'Work note',
  'status.workNoteHint': 'Ordered front pads, waiting on delivery…',
  'status.workNoteHelp': 'Optional — added to the job card',
  'status.nothingToSave': 'Nothing to save',
  'status.notified': 'The customer is notified when the status changes.',

  // ── Add service sheet ──────────────────────────────────────────────────────
  'extras.addService': 'Add a service',
  'extras.noPriceList': 'The workshop has not set up a price list yet.',
  'extras.notUsuallyFor': 'Not usually for a {0}',
  'extras.chooseService': 'Choose a service',
  'extras.addToJob': 'Add to job card',
  'extras.pricedFrom':
      'Priced from the workshop price list. The customer is notified.',

  // ── Photo upload ───────────────────────────────────────────────────────────
  'photo.add': 'Add a photo',
  'photo.customerSees': 'The customer can see these on their job.',
  'photo.whatShowing': 'What is this showing?',
  'photo.captionHint': 'Worn front left pad',
  'photo.chooseFirst': 'Choose a photo first',
  'photo.couldNotLoad': 'Could not load this photo',

  // ── Booking ────────────────────────────────────────────────────────────────
  // Keyed by the value stored on the booking, so the chip can be translated
  // without changing what the API receives.
  'booking.slot.Morning': 'Morning',
  'booking.slot.Afternoon': 'Afternoon',
  'booking.slot.Evening': 'Evening',
  'booking.slot.Any time': 'Any time',
  'booking.whichVehicle': 'Which vehicle?',
  'booking.whatIsWrong': 'What is wrong?',
  'booking.complaintHint':
      'Describe what you have noticed — a noise, a warning light, a leak…',
  'booking.complaintRequired': 'Tell the workshop what to look at',
  'booking.whenSuits': 'When suits you?',
  'booking.anythingElse': 'Anything else while it is in?',
  'booking.extrasFor': 'Optional extras for your {0}.',
  'booking.pricesHeld': 'Prices are held at what you see here.',
  'booking.noExtras': 'The workshop has not listed any extras yet.',
  'booking.isRequest':
      'This is a request. The workshop will confirm the date, and the price '
          'once they have looked at the vehicle.',
  'booking.repairQuoted':
      'The repair itself is quoted after the workshop has looked at it.',
  'booking.submit': 'Request booking',

  // ── Paying ─────────────────────────────────────────────────────────────────
  'pay.title': 'Pay this bill',
  'pay.amountDue': 'Amount due',
  'pay.couldNotOpen': 'Could not open {0}. Is a browser installed?',
  'pay.waiting':
      'Waiting for {0} to confirm. Finish paying, then come back here.',
  'pay.checkAgain': 'Check again',
  'pay.differentWay': 'Pay a different way',
  'pay.notAvailable':
      'This workshop does not take online payment yet. Pay at the counter.',
  'pay.payWith': 'Pay with',
  'pay.authorise':
      'You will be taken to the app or website to authorise. Nothing is '
          'charged until you confirm there.',
  'pay.walletBankCard': 'Wallet, bank or card',
  'pay.online': 'Pay online',
  'pay.bankTransfer': 'Bank transfer',
  'pay.bankName': 'Bank',
  'pay.accountName': 'Account name',
  'pay.accountNumber': 'Account number',
  'pay.branch': 'Branch',
  'pay.iHaveTransferred': 'I have transferred it',
  'pay.bankNote': 'This tells the workshop to look for your transfer. The bill stays open until they confirm it against the account.',
  'pay.copied': 'Copied',
  'pay.copy': 'Copy',
  'pay.received': 'Payment received. Thank you.',
  'pay.payAmount': 'Pay {0}',
  'pay.paidBy': 'Paid by {0}',
  'bills.none': 'No bills yet.',
  'bills.viewBill': 'View bill',

  // ── One bill, in full ──────────────────────────────────────────────────────
  'bill.title': 'Bill',
  'bill.loading': 'Loading the bill…',
  'bill.taxInvoice': 'TAX INVOICE',
  'bill.pan': 'PAN',
  'bill.billedTo': 'Billed to',
  'bill.issued': 'Issued',
  'bill.vehicle': 'Vehicle',
  'bill.odometer': 'Odometer',
  'bill.jobRef': 'Job',
  'bill.workRequested': 'Work requested',
  'bill.mechanic': 'Mechanic',
  'bill.completed': 'Completed',
  'bill.description': 'Description',
  'bill.qty': 'Qty',
  'bill.rate': 'Rate',
  'bill.amount': 'Amount',
  'bill.subtotal': 'Subtotal',
  'bill.discount': 'Discount',
  'bill.pointsRedeemed': '{0} points redeemed',
  'bill.taxable': 'Taxable',
  'bill.vat': 'VAT {0}%',
  'bill.total': 'Total',
  'bill.paidLabel': 'Paid',
  'bill.dueLabel': 'Still to pay',
  'bill.payments': 'Payments received',
  'bill.noBreakdown':
      'The itemised breakdown is no longer on file. The totals are the record.',
  'bill.kind.labour': 'Labour',
  'bill.kind.part': 'Part',
  'bill.kind.service': 'Service',
  'bill.thanks': 'Thank you for your custom.',
  'bill.generated': 'Saved from the GarageFlow app on {0}.',
  'bill.saveImage': 'Save as image',
  'bill.savePdf': 'Save as PDF',
  'bill.preparing': 'Preparing…',
  'bill.saveFailed': 'Could not prepare the file. Please try again.',
  'bill.shareSubject': 'Bill {0} — {1}',

  // ── History ────────────────────────────────────────────────────────────────
  'history.loading': 'Loading your history…',
  'history.emptyTitle': 'No completed services yet',
  'history.emptyMessage':
      'Once the workshop finishes a job, it appears here as a record you can '
          'keep.',

  // ── Driver ─────────────────────────────────────────────────────────────────
  'driver.noPin': 'No pin on this address to navigate to.',
  'driver.noMapsApp': 'No maps app to open this in.',
  'driver.noDialler': 'Could not open the dialler.',
  'driver.locationUnavailable': 'Location is not available.',
  'driver.confirmDelivered': 'Confirm that {0} is with {1}.',
  'driver.notYet': 'Not yet',
  'driver.handedOver': 'Handed over. Nice work.',
  'driver.handedOverAt': 'Handed over at {0}.',
  'driver.loadingTrip': 'Loading the trip…',
  'driver.notFound': 'That handover could not be found.',
  'driver.appSettings': 'App settings',
  'driver.locationSettings': 'Location settings',
  'driver.deliveredQuestion': 'Delivered?',
  'driver.handedOverQuestion': 'Handed over?',
  'driver.deliveredBody': '{0} has been delivered to {1}.',
  'driver.collectedBody': '{0} has collected {1}.',

  // ── Handover ───────────────────────────────────────────────────────────────
  'handover.notAvailableNow': 'Not available right now',
  'handover.notAvailableAddress': 'Not available for your address',
  'handover.confirmDelivery': 'Confirm delivery',
  'handover.confirmFee': 'Confirm — {0}',
  'handover.yourVehicle': 'Your vehicle',
  'handover.stale': 'Showing the last known position. {0}',

  // ── Garages ────────────────────────────────────────────────────────────────
  'garages.nowViewing': 'Now viewing {0}.',
  'garages.noMatch': 'Nothing matches “{0}”',
  'garages.tryShorter': 'Try a shorter search, or the name of the area.',

  // ── Jobs ───────────────────────────────────────────────────────────────────
  'jobs.noneOfStatus': 'No {0} jobs',
  'jobs.tryClearing': 'Try clearing the filter.',

  // ── Alerts ─────────────────────────────────────────────────────────────────
  'alerts.emptyMessage': 'Updates about your jobs and bookings will appear here.',

  // ── Plans ──────────────────────────────────────────────────────────────────
  // The pitch, shown once on the way in. Deliberately about what the app does
  // for the person rather than about the feature names.
  'plansPitch.title': 'GarageFlow, without the waiting',
  'plansPitch.subtitle':
      'A few things a paid plan adds. Have a look — the free app carries on '
          'working exactly as it does now.',
  'plansPitch.noAds.title': 'No adverts',
  'plansPitch.noAds.body': 'Nothing between you and your vehicle.',
  'plansPitch.instant.title': 'Instant alerts',
  'plansPitch.instant.body':
      'Your phone buzzes the moment the workshop moves your job, instead of '
          'the next time you open the app.',
  'plansPitch.parts.title': 'Parts-change reminders',
  'plansPitch.parts.body':
      'A word before the brake pads or the oil are due, not after.',
  'plansPitch.history.title': 'Your whole history',
  'plansPitch.history.body':
      'Every service and every bill, however far back it goes, kept and '
          'searchable.',
  'plansPitch.explore': 'Explore plans',
  'plansPitch.notNow': 'Not now',

  'plans.title': 'Plans',
  'plans.rowSub': 'See what a paid plan adds',
  'plans.subtitle': 'Pay for as long as you like',
  'plans.popular': 'BEST VALUE',
  'plans.freePrice': 'Free',
  'plans.yourPlan': 'Your plan',
  'plans.worksOutAt': 'Works out at {0} a month',
  'plans.payWith': 'Pay with {0}',
  'plans.thanks': 'Thank you. Your plan is active.',
  'plans.activeUntil': 'Your plan runs until {0}',
  'plans.endingSoon': 'Your plan ends in {0} day(s). Renew to keep it running.',
  'plans.comingSoon': 'Coming soon',
  'plans.freeFallback':
      'What your account goes back to whenever a paid plan ends.',
  'plans.noWalletShort': 'Online payment not set up',
  'plans.noWallet':
      'This garage\'s server has no online wallet configured yet, so plans '
          'cannot be paid for from the app.',
  'plans.footnote':
      'Prices are in Nepali rupees and include tax. A plan covers your '
          'account, not a single vehicle, and renewing early adds to the time '
          'you already have.',
  'plans.noneTitle': 'No plans on offer',
  'plans.noneMessage': 'Everything in the app is free at the moment.',

  // How long one payment covers. Derived from the number of months the server
  // sends, so the figure and the word for it cannot disagree.
  'period.monthly': '/ month',
  'period.quarterly': '/ 3 months',
  'period.yearly': '/ year',
  'period.months': '/ {0} months',

  // Per-tier wording. Keyed by the code the server sends, so a price can change
  // without an app release and the words can be translated without a server
  // deploy. `features` is one `|`-separated string — see Plan.features.
  'plan.free.name': 'Free',
  'plan.free.tagline': 'Everything the app does today',
  'plan.free.features':
      'Book services and follow the work|Your bills, and paying them|'
          'Rewards and offers from your garage|Save any bill as a PDF',
  'plan.monthly.name': 'Monthly',
  'plan.monthly.tagline': 'Try it for a month',
  'plan.monthly.features':
      'No adverts, anywhere|Instant alerts the moment a job moves|'
          'Parts-change reminders before something is due|'
          'Your full service history, however far back',
  'plan.quarterly.name': 'Quarterly',
  'plan.quarterly.tagline': 'Three months, at half the monthly rate',
  'plan.quarterly.features':
      'Everything in the monthly plan|Three months for the price of one and a '
          'half|Every vehicle you own on one account',
  'plan.yearly.name': 'Yearly',
  'plan.yearly.tagline': 'The whole year, and the cheapest way to buy it',
  'plan.yearly.features':
      'Everything in the quarterly plan|A full year of cover|'
          'Priority booking at your garage|Bills exported for your accountant',
};

// ── Nepali ───────────────────────────────────────────────────────────────────
// Written for a Kathmandu workshop rather than translated word for word. Where
// the English is an idiom ("Nothing on your ramp") the Nepali says the plain
// thing instead, because a literal rendering would be a puzzle.
//
// Left in English deliberately: "GarageFlow" (a product name), and the roles
// Owner/Mechanic/Customer, which the dashboard also shows in English and which
// staff use as-is when talking about accounts.

const Map<String, String> _ne = {
  'common.retry': 'फेरि प्रयास गर्नुहोस्',
  'common.cancel': 'रद्द गर्नुहोस्',
  'common.more': 'थप',
  'common.save': 'सेभ गर्नुहोस्',
  'common.saving': 'सेभ हुँदै…',
  'common.close': 'बन्द गर्नुहोस्',
  'common.confirm': 'पक्का गर्नुहोस्',
  'common.delete': 'हटाउनुहोस्',
  'common.free': 'निःशुल्क',
  'common.refresh': 'ताजा गर्नुहोस्',
  'common.back': 'पछाडि',
  'common.loading': 'लोड हुँदै…',
  'common.couldNotLoad': 'लोड गर्न सकिएन',
  'common.notSet': 'सेट गरिएको छैन',
  'common.on': 'खुला',
  'common.off': 'बन्द',
  'common.done': 'भयो',

  'auth.title': 'GarageFlow',
  'auth.tagline': 'तपाईंको वर्कशप, तपाईंको खल्तीमा',
  'auth.customer': 'ग्राहक',
  'auth.staff': 'वर्कशप कर्मचारी',
  'auth.companyCode': 'कम्पनी कोड',
  'auth.companyCodeHint': 'तपाईंको वर्कशपले दिएको',
  'auth.email': 'इमेल',
  'auth.password': 'पासवर्ड',
  'auth.signIn': 'साइन इन',
  'auth.signOut': 'साइन आउट',
  'auth.signOutConfirm': 'फेरि साइन इन गर्न पासवर्ड चाहिन्छ।',
  'auth.newHere': 'नयाँ हुनुहुन्छ?',
  'auth.createAccount': 'निःशुल्क खाता खोल्नुहोस्',
  'auth.haveAccount': 'पहिले नै खाता छ?',
  'auth.enterEmail': 'इमेल लेख्नुहोस्',
  'auth.enterPassword': 'पासवर्ड लेख्नुहोस्',
  'auth.badEmail': 'यो इमेल ठेगाना जस्तो देखिँदैन',
  'auth.enterCompanyCode': 'कम्पनी कोड लेख्नुहोस्',
  'auth.showPassword': 'पासवर्ड देखाउनुहोस्',
  'auth.hidePassword': 'पासवर्ड लुकाउनुहोस्',
  'auth.or': 'वा',
  'auth.orWithEmail': 'वा इमेलबाट जारी राख्नुहोस्',
  'auth.sessionExpired': 'तपाईंको सेसन सकियो। फेरि साइन इन गर्नुहोस्।',
  'auth.passwordChangedNotice':
      'तपाईंको पासवर्ड परिवर्तन भयो। फेरि साइन इन गर्नुहोस्।',

  'support.title': 'सहयोग',
  'support.subtitle': 'सवारी वा बिलबारे सोध्नुहोस्',
  'support.withGarage': 'ग्यारेजले जवाफ दिँदैछ',
  'support.past': 'पुराना कुराकानी',
  'support.newChat': 'नयाँ कुराकानी',
  'support.loading': 'लोड हुँदै…',
  'support.thinking': 'सोच्दै…',
  'support.placeholder': 'आफ्नो प्रश्न लेख्नुहोस्…',
  'support.talkToGarage': 'ग्यारेजसँग कुरा गर्नुहोस्',
  'support.garageHasIt': 'ग्यारेजले हेर्दैछ। यहीँ जवाफ आउनेछ।',
  'support.waiting': 'पर्खिँदै',
  'support.aiAnswer': 'AI जवाफ',
  'support.introTitle': 'जे पनि सोध्नुहोस्',
  'support.introBody':
      'सवारी कहिले तयार हुन्छ, बिलमा के छ, सेवा कसरी बुक गर्ने। सहायकले तुरुन्तै '
      'जवाफ दिन्छ र नसकेको कुरा ग्यारेजलाई पठाउँछ।',
  'auth.staffPrompt': 'ग्यारेजमा काम गर्नुहुन्छ?',
  'auth.staffLink': 'कर्मचारी साइन इन',
  'auth.staffTitle': 'कर्मचारी साइन इन',
  'auth.staffSubtitle':
      'मेकानिक र वर्कशप कर्मचारीका लागि। तपाईंको वर्कशपले दिएको कम्पनी कोड '
      'चाहिन्छ।',
  'auth.backToCustomer': 'ग्राहक साइन इनमा फर्कनुहोस्',
  'auth.continueWithGoogle': 'Google बाट जारी राख्नुहोस्',
  'auth.forgotPassword': 'पासवर्ड बिर्सनुभयो?',
  'auth.rememberMe': 'मलाई सम्झनुहोस्',
  'auth.rememberMeHint':
      'तपाईंको इमेल र पासवर्ड यही फोनको इन्क्रिप्टेड स्टोरमा रहन्छ, ताकि यो '
          'फारम भरिएकै अवस्थामा खुल्छ। हटाउन टिक निकाल्नुहोस्।',
  'forgot.title': 'पासवर्ड रिसेट',
  'forgot.intro': 'आफ्नो खाताको इमेल लेख्नुहोस्, हामी छ अंकको कोड पठाउँछौं।',
  'forgot.send': 'कोड पठाउनुहोस्',
  'forgot.checkEmail': 'इमेल हेर्नुहोस्',
  'forgot.noEmailNote': 'आएन? स्प्याम फोल्डर हेर्नुहोस्, वा वर्कशपलाई भन्नुहोस् — उनीहरूले रिसेट गरिदिन सक्छन्।',

  // Step two: the code
  'forgot.codeTitle': 'कोड लेख्नुहोस्',
  'forgot.codeSent': '{0} मा छ अंकको कोड पठाइयो। {1} मिनेटमा समाप्त हुन्छ।',
  'forgot.code': 'छ अंकको कोड',
  'forgot.enterCode': 'इमेलमा आएको कोड लेख्नुहोस्',
  'forgot.badCode': 'कोड छ अंकको हुन्छ',
  'forgot.continue': 'अगाडि बढ्नुहोस्',
  'forgot.resend': 'नयाँ कोड पठाउनुहोस्',
  'forgot.resendIn': '{0} सेकेन्डपछि पुनः पठाउनुहोस्',
  'forgot.wrongAddress': 'इमेल फरक छ?',

  // Step three: the new password
  'forgot.newTitle': 'नयाँ पासवर्ड छान्नुहोस्',
  'forgot.newIntro': 'अन्य यन्त्रहरूमा फेरि साइन इन गर्नुपर्नेछ।',
  'forgot.newPassword': 'नयाँ पासवर्ड',
  'forgot.confirmPassword': 'नयाँ पासवर्ड पुष्टि गर्नुहोस्',
  'forgot.enterNewPassword': 'पासवर्ड छान्नुहोस्',
  'forgot.shortPassword': 'कम्तीमा ८ अक्षर राख्नुहोस्',
  'forgot.mismatch': 'दुवै पासवर्ड मिल्नुपर्छ',
  'forgot.save': 'पासवर्ड रिसेट गर्नुहोस्',
  'forgot.done': 'पासवर्ड अपडेट भयो',
  'forgot.doneNote': 'नयाँ पासवर्डले साइन इन गर्नुहोस्।',

  'setPassword.title': 'आफ्नो पासवर्ड छान्नुहोस्',
  'setPassword.greeting': 'स्वागत छ, {0}',
  'setPassword.intro':
      'तपाईंको खाता अरूले खोलिदिएको हो, त्यसैले भर्खर प्रयोग गर्नुभएको पासवर्ड '
      'खाता खोल्नेलाई थाहा छ। अगाडि बढ्न आफूलाई मात्र थाहा हुने पासवर्ड छान्नुहोस्।',
  'setPassword.newPassword': 'नयाँ पासवर्ड',
  'setPassword.confirmPassword': 'नयाँ पासवर्ड पुष्टि गर्नुहोस्',
  'setPassword.enterNewPassword': 'पासवर्ड छान्नुहोस्',
  'setPassword.shortPassword': 'कम्तीमा ८ अक्षर राख्नुहोस्',
  'setPassword.mismatch': 'दुवै पासवर्ड मिल्नुपर्छ',
  'setPassword.save': 'सुरक्षित गरी अगाडि बढ्नुहोस्',
  'setPassword.done': 'पासवर्ड सेट भयो। तपाईं साइन इन हुनुभयो।',
  'setPassword.signOut': 'बरु साइन आउट गर्नुहोस्',

  'signup.title': 'खाता खोल्नुहोस्',
  'signup.subtitle': 'त्यसपछि ग्यारेज छान्नुहोस्',
  'signup.fullName': 'पूरा नाम',
  // A Nepali reader is prompted with a name written the way they would write it.
  'signup.nameHint': 'रिता श्रेष्ठ',
  'signup.phone': 'फोन',
  'signup.phoneHelp': 'ग्यारेजले तपाईंको सवारीबारे सम्पर्क गर्न',
  'signup.passwordHelp': 'कम्तीमा ८ अक्षर',
  'signup.passwordShort': 'कम्तीमा ८ अक्षर राख्नुहोस्',
  'signup.enterName': 'नाम लेख्नुहोस्',
  'signup.submit': 'खाता खोल्नुहोस्',
  'signup.footnote':
      'ग्राहकका लागि निःशुल्क। कुन ग्यारेज प्रयोग गर्ने तपाईं छान्नुहुन्छ, र '
          'एकभन्दा बढी पनि प्रयोग गर्न सक्नुहुन्छ।',
  'signup.created': 'तपाईंको खाता तयार भयो। सुरु गर्न साइन इन गर्नुहोस्।',

  'deleteAccount.title': 'खाता मेट्नुहोस्',
  'deleteAccount.rowSub': 'आफ्नो GarageFlow खाता सधैंका लागि बन्द गर्नुहोस्',
  'deleteAccount.graceTitle': 'विचार बदल्न ३० दिन छ',
  'deleteAccount.graceBody':
      'आज केही पनि मेटिँदैन। अबका ३० दिनपछि तपाईंको खाता सधैंका लागि हट्नेछ। '
          'त्यसअघि फेरि साइन इन गर्नुभयो भने खाता जस्ताको तस्तै रहन्छ।',
  'deleteAccount.whatGoes': 'के मेटिन्छ',
  'deleteAccount.goesLogin': 'तपाईंको लगइन, नाम, इमेल, फोन र फोटो',
  'deleteAccount.goesGarages': 'तपाईं सामेल भएका सबै ग्यारेजको सदस्यता',
  'deleteAccount.goesMessages': 'तपाईंका सूचना र सहयोग सन्देशहरू',
  'deleteAccount.whatStays': 'ग्यारेजसँग के रहन्छ',
  'deleteAccount.staysInvoices':
      'पुराना जब कार्ड र बिलहरू, तपाईंको नाम हटाएर',
  'deleteAccount.staysWhy':
      'करका लागि ग्यारेजले आफ्नो बिक्रीको हिसाब राख्नैपर्छ। ती हिसाबमा '
          'तपाईं को हुनुहुन्थ्यो भन्ने कुनै विवरण रहँदैन।',
  'deleteAccount.confirmPassword':
      'यो तपाईं नै हो भनी पुष्टि गर्न पासवर्ड लेख्नुहोस्।',
  'deleteAccount.action': 'मेरो खाता मेट्नुहोस्',
  'deleteAccount.keep': 'खाता राख्नुहोस्',
  'deleteAccount.confirmTitle': 'खाता मेट्ने हो?',
  'deleteAccount.confirmBody':
      'तपाईं अहिले नै साइन आउट हुनुहुनेछ, र ३० दिनपछि खाता मेटिनेछ। '
          'त्यसअघि फेरि साइन इन गर्नुभयो भने यो रद्द हुन्छ।',
  'deleteAccount.confirmAction': 'मेट्नुहोस्',
  'deleteAccount.scheduled':
      'तपाईंको खाता {0} मा मेटिनेछ। त्यसअघि साइन इन गर्नुभयो भने खाता रहन्छ।',
  'deleteAccount.cancelled':
      'फेरि स्वागत छ। तपाईंको खाता अब मेटिँदैन।',

  'garages.choose': 'ग्यारेज छान्नुहोस्',
  'garages.find': 'ग्यारेज खोज्नुहोस्',
  'garages.chooseSubtitle': 'सवारी कहाँ सर्भिस गराउने छान्नुहोस्',
  'garages.listed': 'GarageFlow प्रयोग गर्ने ग्यारेजहरू',
  'garages.search': 'नाम वा ठाउँले खोज्नुहोस्',
  'garages.join': 'यो ग्यारेजमा जोडिनुहोस्',
  'garages.joining': 'जोडिँदै…',
  'garages.joinConfirmTitle': '{0} मा जोडिने?',
  'garages.joinConfirm':
      'तपाईंको नाम, फोन नम्बर र यहाँ थपिएका सवारीहरू उनीहरूले देख्न सक्नेछन्, '
      'ताकि सर्भिस गर्न सकियोस्।',
  'garages.joinConfirmLeave':
      'जुनसुकै बेला प्रोफाइलबाट हट्न सकिन्छ।',
  'garages.joinConfirmAction': 'जोडिनुहोस्',
  'garages.switchTo': 'यो ग्यारेजमा जानुहोस्',
  'garages.viewing': 'तपाईं यही ग्यारेज हेर्दै हुनुहुन्छ',
  'garages.current': 'हालको',
  'garages.joined': 'जोडिएको',
  'garages.services': '{0} सेवाहरू',
  'garages.away': '{0} किमी टाढा',
  'garages.noneTitle': 'अहिलेसम्म कुनै ग्यारेज छैन',
  'garages.noneMessage': 'ग्यारेजले आफूलाई सूचीमा राखेपछि यहाँ देखिन्छ।',
  'garages.sortedAZ': 'क–ज्ञ क्रममा',
  'garages.finding': 'ग्यारेज खोज्दै…',
  'garages.noAddress': 'ठेगाना राखिएको छैन',
  'garages.sortNearest': 'नजिकको अनुसार',
  'garages.noneJoined': 'तपाईं अझै कुनै ग्यारेजमा सामेल हुनुभएको छैन',

  'rewards.title': 'पुरस्कार',
  'rewards.rowSub': 'तपाईंका स्ट्याम्प, पोइन्ट र यो ग्यारेजका अफर',
  'rewards.rowWorth': 'अर्को बिलमा {0} छुट हुने',
  'rewards.rowToGo': 'कार्ड भर्न अझै {0} सर्भिस',
  'rewards.rowFree': '{0} निःशुल्क सर्भिस पर्खिरहेको',
  'rewards.pillPoints': '{0} अंक',
  'rewards.loading': 'पुरस्कार लोड हुँदैछ…',
  'rewards.noneTitle': 'यहाँ पुरस्कार योजना छैन',
  'rewards.noneMessage':
      'यो ग्यारेजले अहिले कुनै पुरस्कार योजना वा अफर चलाएको छैन।',
  'rewards.freeService': 'एउटा निःशुल्क सेवा',
  'rewards.running': 'अहिले चलिरहेको',
  'rewards.history': 'तपाईंको गतिविधि',
  'rewards.readyOne': 'प्रयोग गर्न तयार — निःशुल्क {0} माग्नुहोस्',
  'rewards.readyMany': '{0} निःशुल्क सेवा तपाईंको पर्खाइमा',
  'rewards.oneToGo': 'अझै एक सेवा, अनि तपाईंको {0} निःशुल्क',
  'rewards.manyToGo': 'अझै {0} सेवा, अनि तपाईंको {1} निःशुल्क',
  'rewards.askAtCounter':
      'सवारी लिन आउँदा भन्नुहोस्, ग्यारेजले बिलबाट घटाइदिन्छ।',
  'rewards.points': 'पोइन्ट',
  'rewards.worth': 'मूल्य {0}',
  'rewards.canSpend': 'यी पोइन्ट अर्को बिलमा प्रयोग गर्न सक्नुहुन्छ।',
  'rewards.needMore': 'खर्च गर्न अझै {0} पोइन्ट चाहिन्छ — जम्मा {1} चाहिन्छ।',
  'rewards.until': '{0} सम्म',

  'rate.title': 'हाम्रो काम कस्तो लाग्यो?',
  'rate.subtitle':
      'तपाईंको मूल्याङ्कन ग्यारेजले मात्र देख्छ, अरू ग्राहकले देख्दैनन्।',
  'rate.garage': 'ग्यारेज समग्रमा',
  'rate.mechanic': '{0} को काम',
  'rate.comment': 'केही थप्नु छ?',
  'rate.commentHint': 'वैकल्पिक',
  'rate.submit': 'पठाउनुहोस्',
  'rate.update': 'अद्यावधिक गर्नुहोस्',
  'rate.thanks': 'प्रतिक्रियाका लागि धन्यवाद।',
  'rate.prompt': 'यो सेवाको मूल्याङ्कन गर्नुहोस्',
  'rate.promptSub': 'दुई छोटा प्रश्न — ग्यारेज, र मेकानिक।',
  'rate.yours': 'तपाईंको मूल्याङ्कन',
  'rate.tapToChange': 'बदल्न थिच्नुहोस्',
  'rate.myRating': 'मेरो मूल्याङ्कन',
  'rate.fromCount': '{0} ग्राहक मूल्याङ्कनबाट',
  'rate.notRatedYet': 'अहिलेसम्म मूल्याङ्कन छैन',

  'jobs.greeting': 'नमस्ते, {0}',
  'jobs.active': 'चालु कामहरू',
  'jobs.assigned': 'तोकिएको',
  'jobs.inProgress': 'चलिरहेको',
  'jobs.awaitingParts': 'पार्ट्स पर्खाइमा',
  'jobs.loading': 'तपाईंका कामहरू लोड हुँदै…',
  'jobs.emptyTitle': 'अहिले कुनै काम छैन',
  'jobs.emptyMessage': 'तपाईंलाई तोकिएका कामहरू यहाँ देखिन्छन्।',
  'jobs.clearFilter': 'हटाउनुहोस्',
  'jobs.overdueOne': '१ काम तोकिएको समय नाघेको छ',
  'jobs.overdueMany': '{0} काम तोकिएको समय नाघेका छन्',
  'jobs.doneOne': 'आज १ काम सकियो — राम्रो',
  'jobs.doneMany': 'आज {0} काम सकिए — राम्रो',

  'home.inWorkshop': 'वर्कशपमा',
  'home.readyForYou': 'तयार छ',
  'home.yourBookings': 'तपाईंका बुकिङ',
  'home.yourVehicles': 'तपाईंका सवारी',
  'home.bookService': 'सर्भिस बुक गर्नुहोस्',
  'home.nothingIn': 'वर्कशपमा केही छैन',
  'home.tapToBook': 'अर्को सर्भिस बुक गर्न थिच्नुहोस्',
  'home.askWorkshop': 'सर्भिस बुक गर्न सवारी थप्नुहोस्',
  'home.loading': 'तपाईंका सवारी लोड हुँदै…',
  'home.noVehiclesTitle': 'अहिलेसम्म सवारी छैन',
  'home.noVehiclesMessage':
      'सर्भिस गर्नुपर्ने सवारी थप्नुहोस्। पहिलो पटक ल्याउँदा वर्कशपले विवरण '
          'पक्का गर्नेछ।',
  'home.percentComplete': '{0}% सकियो',
  'home.ready': 'तयार {0}',
  'home.photosFrom': 'वर्कशपबाट {0} फोटो',
  'home.photoFrom': 'वर्कशपबाट १ फोटो',
  'home.cancelBooking': 'बुकिङ रद्द गर्नुहोस्',
  'home.yourGarages': 'तपाईंका ग्यारेज',

  'handover.readyTitle': 'तपाईंको सवारी तयार छ',
  'handover.collect': 'म आफैं लिन आउँछु',
  'handover.collectSub': 'जुनसुकै बेला वर्कशपमा आउनुहोस्',
  'handover.deliver': 'मेरो ठेगानामा पुर्‍याउनुहोस्',
  'handover.checking': 'तपाईंको ठेगानामा डेलिभरी हेर्दै…',
  'handover.onBill': 'बिलमा थपिन्छ',
  'handover.fromWorkshop': 'वर्कशपबाट {0} किमी',
  'handover.changeNote': 'वर्कशपलाई भनेर यो परिवर्तन गर्न सकिन्छ।',
  'handover.chooseCta': 'कसरी फिर्ता लिने छान्नुहोस्',
  'handover.workFinished': 'काम सकियो',
  'handover.workFinishedBody':
      'तपाईं आफैं लिन आउने कि घरमै पुर्‍याइदिने, वर्कशपलाई भन्नुहोस्।',
  'handover.title': 'फिर्ता',
  'handover.method': 'तरिका',
  'handover.homeDelivery': 'घरमा डेलिभरी',
  'handover.collection': 'वर्कशपबाट लिने',
  'handover.status': 'अवस्था',
  'handover.address': 'ठेगाना',
  'handover.distance': 'दूरी',
  'handover.fee': 'डेलिभरी शुल्क',
  'handover.driver': 'चालक',
  'handover.setOff': 'हिँडेको',
  'handover.delivered': 'पुर्‍याइयो',
  'handover.collected': 'लगियो',
  'handover.callWorkshop': 'वर्कशपलाई फोन गर्नुहोस्',
  'handover.trackingNote':
      'चालकले एप खोलिराखेसम्म ट्र्याकिङ अपडेट हुन्छ। सिग्नल गएमा रोकिन सक्छ।',
  'handover.bringId': 'लिन आउँदा परिचयपत्र ल्याउनुहोस्।',
  'handover.finding': 'तपाईंको सवारी खोज्दै…',
  'handover.notStarted': 'अझै सुरु भएको छैन',
  'handover.live': 'अहिले लाइभ',
  'handover.bringingIt': '{0} ले ल्याउँदै हुनुहुन्छ',
  'handover.trip': '{0} किमी यात्रा',

  'driver.handovers': 'फिर्ता गर्नुपर्ने',
  'driver.outForDelivery': '{0} डेलिभरीमा',
  'driver.waiting': '{0} पर्खाइमा',
  'driver.nothingOut': 'पठाउनुपर्ने केही छैन',
  'driver.startRun': 'यात्रा सुरु गर्नुहोस्',
  'driver.starting': 'सुरु हुँदै…',
  'driver.openTrip': 'यात्रा खोल्नुहोस्',
  'driver.markDelivered': 'पुर्‍याइयो भनी राख्नुहोस्',
  'driver.collectedIt': 'ग्राहकले लगे',
  'driver.waitingCustomer': 'ग्राहकले छान्ने पर्खाइमा',
  'driver.sharing': 'तपाईंको स्थान पठाइँदै',
  'driver.sharingStops': 'यो स्क्रिनबाट निस्केपछि रोकिन्छ',
  'driver.sent': '{0} पठाइयो',
  'driver.cannotSee': 'ग्राहकले तपाईं कहाँ हुनुहुन्छ देख्न सक्दैनन्',
  'driver.stillWorks': 'डेलिभरी गरेर सकियो भनी राख्न अझै सक्नुहुन्छ।',
  'driver.dropOff': 'पुर्‍याउने ठाउँ',
  'driver.navigate': 'बाटो देखाउनुहोस्',
  'driver.call': 'फोन',
  'driver.emptyTitle': 'फिर्ता गर्नुपर्ने केही छैन',
  'driver.emptyMessage':
      'ग्राहकले सवारी कसरी फिर्ता लिने भनेपछि सकिएका कामहरू यहाँ देखिन्छन्।',

  'alerts.title': 'सूचनाहरू',
  'alerts.markAllRead': 'सबै पढेको बनाउनुहोस्',
  'alerts.emptyTitle': 'अहिलेसम्म केही छैन',

  'bills.title': 'बिलहरू',
  'history.title': 'सर्भिस इतिहास',
  'booking.title': 'सर्भिस बुक गर्नुहोस्',

  'profile.title': 'प्रोफाइल',
  'profile.account': 'खाता',
  'profile.accountSub': 'नाम, इमेल र फोन',
  'profile.security': 'सुरक्षा',
  'profile.securitySub': 'एप लक र पासवर्ड',
  'profile.appearance': 'देखावट',
  'profile.appearanceSub': 'थिम र अक्षरको आकार',
  'profile.language': 'भाषा',
  'profile.featureRequest': 'सुझाव पठाउनुहोस्',
  'profile.featureRequestSub': 'नयाँ सुविधा सुझाउनुहोस् वा समस्या बताउनुहोस्',
  'profile.help': 'सहयोग',
  'profile.helpSub': 'वर्कशपलाई सम्पर्क गर्नुहोस्',
  'profile.about': 'बारेमा',
  'profile.settings': 'सेटिङ',
  'profile.workshop': 'वर्कशप',

  'profile.editPhoto': 'फोटो बदल्नुहोस्',
  'profile.takePhoto': 'फोटो खिच्नुहोस्',
  'profile.choosePhoto': 'ग्यालरीबाट छान्नुहोस्',
  'profile.removePhoto': 'फोटो हटाउनुहोस्',
  'profile.photoUpdated': 'फोटो अपडेट भयो।',
  'profile.photoRemoved': 'फोटो हटाइयो।',

  'account.title': 'तपाईंको खाता',
  'account.name': 'नाम',
  'account.email': 'इमेल',
  'account.phone': 'फोन',
  'account.role': 'भूमिका',
  'account.emailNote': 'यो बदल्दा साइन इन गर्ने इमेल पनि बदलिन्छ।',
  'account.saved': 'तपाईंको विवरण सेभ भयो।',
  'account.customerRef': 'ग्राहक',
  'account.assignedAs': 'यस नाममा तोकिएको',
  'account.companyCode': 'कम्पनी कोड',

  'security.title': 'सुरक्षा',
  'security.appLock': 'बायोमेट्रिकले खोल्नुहोस्',
  'security.appLockSub': 'एप देखाउनुअघि फिंगरप्रिन्ट वा अनुहार माग्नुहोस्।',
  'security.appLockUnavailable':
      'यो फोनमा फिंगरप्रिन्ट वा फेस अनलक सेट गरिएको छैन।',
  'security.locked': 'GarageFlow लक छ',
  'security.unlock': 'खोल्नुहोस्',
  'security.unlockReason': 'GarageFlow खोल्नुहोस्',
  'security.unlockFailed': 'पुष्टि गर्न सकिएन। फेरि प्रयास गर्नुहोस्।',
  'security.useSignOut': 'साइन आउट गर्नुहोस्',
  'security.changePassword': 'पासवर्ड बदल्नुहोस्',
  'security.currentPassword': 'हालको पासवर्ड',
  'security.newPassword': 'नयाँ पासवर्ड',
  'security.confirmPassword': 'नयाँ पासवर्ड फेरि लेख्नुहोस्',
  'security.passwordsDiffer': 'दुई पासवर्ड मिलेनन्',
  'security.passwordChanged': 'पासवर्ड बदलियो। फेरि साइन इन गर्नुहोस्।',
  'security.sessionNote':
      'पासवर्ड बदल्दा यो फोनसहित सबै ठाउँबाट साइन आउट हुन्छ।',

  'appearance.title': 'देखावट',
  'appearance.theme': 'थिम',
  'appearance.system': 'फोनअनुसार',
  'appearance.light': 'उज्यालो',
  'appearance.dark': 'अँध्यारो',
  'appearance.textSize': 'अक्षरको आकार',
  'appearance.preview': 'नमुना',
  'appearance.previewPlate': 'बा १२ प ३४५६',
  'appearance.previewLine': 'होन्डा सिटी · भोलि तयार',

  'language.title': 'भाषा',
  'language.note':
      'यसले एपका आफ्नै शब्द बदल्छ। वर्कशपले लेखेका कुरा — सेवाको नाम, नोट, '
          'तपाईंको सवारीको विवरण — उनीहरूले लेखेकै रहन्छ।',

  'feedback.title': 'सुझाव पठाउनुहोस्',
  'feedback.intro':
      'यो एप कसरी अझ राम्रो बनाउन सकिन्छ वा के बिग्रिएको छ बताउनुहोस्। '
          'इमेल एप खुल्छ, त्यसैले के पठाइँदै छ तपाईं आफैं देख्न सक्नुहुन्छ।',
  'feedback.subject': 'GarageFlow सुझाव',
  'feedback.compose': 'सुझाव लेख्नुहोस्',
  'feedback.noEmailApp': 'खोल्न मिल्ने इमेल एप छैन।',
  'feedback.includes': 'तपाईंको सन्देशमा यी हुनेछन्:',
  'feedback.appVersion': 'एप संस्करण',
  'feedback.role': 'तपाईंको भूमिका',
  'feedback.nothingElse':
      'अरू केही जोडिँदैन — सवारीको डाटा र फोटो पठाइँदैन।',

  'about.version': 'एप',
  'about.server': 'सर्भर',
  'about.accountManaged':
      'पासवर्ड वा विवरण बदल्न वर्कशपलाई भन्नुहोस् — खाताहरू ड्यासबोर्डबाट '
          'व्यवस्थापन हुन्छन्।',

  'tab.myVehicles': 'सवारी',
  'tab.myJobs': 'मेरा काम',
  'tab.history': 'इतिहास',
  'tab.bills': 'बिल',
  'tab.garages': 'ग्यारेज',
  'profile.notifications': 'सूचनाहरू',
  'profile.notificationsOn': 'काम र बिलका सूचना खुला छन्',
  'profile.notificationsOff': 'सूचना बन्द छन् — एपभित्र भने पढ्न सकिन्छ',
  'tab.alerts': 'सूचना',
  'tab.account': 'खाता',

  'vehicle.addTitle': 'सवारी थप्नुहोस्',
  'vehicle.addCta': 'सवारी थप्नुहोस्',
  'vehicle.plate': 'नम्बर प्लेट',
  'vehicle.plateHint': 'बा २ च १२३४',
  'vehicle.plateRequired': 'नम्बर प्लेट लेख्नुहोस्।',
  'vehicle.makeAndModel': 'कम्पनी र मोडेल',
  'vehicle.makeHint': 'टोयोटा',
  'vehicle.makeRequired': 'कम्पनी लेख्नुहोस्।',
  'vehicle.modelHint': 'कोरोला',
  'vehicle.modelRequired': 'मोडेल लेख्नुहोस्।',
  'vehicle.year': 'साल',
  'vehicle.yearRange': '{0} र {1} बीचको साल लेख्नुहोस्।',
  'vehicle.type': 'कस्तो सवारी हो?',
  'vehicle.fuel': 'इन्धन',
  'vehicle.optional': 'रङ र मिटर (वैकल्पिक)',
  'vehicle.colourHint': 'सेतो',
  'vehicle.odometerHint': 'मिटरमा किमि',
  'vehicle.addNote':
      'पहिलो पटक सवारी ल्याउँदा वर्कशपले विवरण पक्का गर्नेछ।',
  'vehicle.addSubmit': 'सवारी थप्नुहोस्',
  'vehicle.added': '{0} तपाईंको खातामा थपियो।',
  'vehicle.editTitle': 'सवारी सम्पादन',
  'vehicle.edit': 'विवरण सम्पादन',
  'vehicle.updated': '{0} अद्यावधिक भयो।',
  'vehicle.remove': 'हटाउनुहोस्',
  'vehicle.removeTitle': '{0} हटाउने हो?',
  'vehicle.removeBody':
      'यसले सवारीलाई तपाईंको खाताबाट हटाउँछ। ग्यारेजले पहिले नै सर्भिस '
          'गरिसकेको छ भने त्यो रेकर्ड उनीहरूसँगै रहन्छ र तपाईंलाई उनीहरूलाई '
          'सम्पर्क गर्न भनिनेछ।',
  'vehicle.removed': '{0} तपाईंको खाताबाट हट्यो।',

  'vehicleType.Bike': 'मोटरसाइकल',
  'vehicleType.Car': 'कार',
  'vehicleType.Van': 'भ्यान',
  'vehicleType.Bus': 'बस',
  'vehicleType.Truck': 'ट्रक',
  'vehicleType.Tractor': 'ट्र्याक्टर',

  'fuel.Petrol': 'पेट्रोल',
  'fuel.Diesel': 'डिजेल',
  'fuel.Electric': 'बिजुली',
  'fuel.Hybrid': 'हाइब्रिड',
  'fuel.CNG': 'सीएनजी',

  'home.noVehiclesSnack':
      'पहिले सवारी थप्नुहोस् — त्यसपछि सर्भिस बुक गर्न सकिन्छ।',
  'home.bookingRequested': 'बुकिङ अनुरोध पठाइयो।',
  'home.cancelTitle': 'बुकिङ रद्द गर्ने?',
  'home.cancelBody': '{1} को {0} को बुकिङ रद्द हुनेछ।',
  'home.keepIt': 'राख्नुहोस्',
  'home.bookingCancelled': 'बुकिङ रद्द भयो।',
  'home.chooseHandover': 'आफैं लिने कि पुर्‍याउने छान्नुहोस्',
  'home.followMap': 'नक्सामा हेर्नुहोस्',
  'home.checkingVehicles': 'तपाईंका सवारी जाँच्दै…',
  'home.oneMoment': 'एक छिन',
  'home.extrasEstimate': 'थप सेवाको अनुमान',
  'home.preferredTime': 'चाहिएको समय: {0}',
  'home.lastService': 'अन्तिम सर्भिस {0}',

  'job.notFound': 'काम भेटिएन।',
  'job.lookingAt': 'हामी के हेर्दै छौं',
  'job.noDetails': 'विवरण राखिएको छैन।',
  'job.bookedIn': 'भित्रिएको',
  'job.readyBy': 'तयार हुने',
  'job.stageOpen': 'भित्रिएको छ, काम सुरु भएको छैन।',
  'job.stageProgress': 'अहिले काम भइरहेको छ।',
  'job.stageParts': 'पार्ट्स आउने पर्खाइमा।',
  'job.stageDone': 'काम सकियो — लिन आउन सकिन्छ।',
  'job.stageCollected': 'लगियो। धन्यवाद!',
  'job.stageCancelled': 'यो काम रद्द भएको थियो।',
  'job.workAndParts': 'काम र पार्ट्स',
  'job.estimatedTotal': 'अनुमानित जम्मा',
  'job.beforeTax': 'कर बाहेक। तपाईंको बिल अन्तिम रकम हो।',
  'job.photosFromWorkshop': 'वर्कशपबाट फोटो',

  'job.markedStatus': 'काम {0} भनी राखियो।',
  'job.serviceAdded': 'जब कार्डमा थपियो। ग्राहकलाई जानकारी दिइयो।',
  'job.photoAdded': 'फोटो थपियो।',
  'job.deletePhoto': 'फोटो हटाउने?',
  'job.cannotUndo': 'यो फर्काउन मिल्दैन।',
  'job.photoDeleted': 'फोटो हटाइयो।',
  'job.updateStatus': 'अवस्था अपडेट गर्नुहोस्',
  'job.complaintNotes': 'गुनासो र नोट',
  'job.noComplaint': 'गुनासो राखिएको छैन।',
  'job.customerLocation': 'ग्राहकको स्थान',
  'job.workOnThis': 'यो कामको विवरण',
  'job.nothingCosted': 'अझै कुनै रकम राखिएको छैन।',
  'job.addAWash': 'सवारीलाई चाहिन्छ भने वाश वा पोलिस थप्नुहोस्।',
  'job.photosCount': 'फोटो ({0})',
  'job.noPhotos': 'अझै फोटो छैन।',
  'job.photosHelp': 'फोटोले ग्राहकलाई काम देखाउन मद्दत गर्छ।',

  'status.odometer': 'ओडोमिटर (किमी)',
  'status.odometerHelp': 'ऐच्छिक — सवारीमा पनि राखिन्छ',
  'status.workNote': 'कामको नोट',
  'status.workNoteHint': 'अगाडिको प्याड अर्डर गरियो, आउने पर्खाइमा…',
  'status.workNoteHelp': 'ऐच्छिक — जब कार्डमा थपिन्छ',
  'status.nothingToSave': 'सेभ गर्न केही छैन',
  'status.notified': 'अवस्था बदलिँदा ग्राहकलाई जानकारी जान्छ।',

  'extras.addService': 'सेवा थप्नुहोस्',
  'extras.noPriceList': 'वर्कशपले मूल्य सूची राखेको छैन।',
  'extras.notUsuallyFor': 'सामान्यतया {0} लाई होइन',
  'extras.chooseService': 'सेवा छान्नुहोस्',
  'extras.addToJob': 'जब कार्डमा थप्नुहोस्',
  'extras.pricedFrom':
      'वर्कशपको मूल्य सूचीअनुसार। ग्राहकलाई जानकारी जान्छ।',

  'photo.add': 'फोटो थप्नुहोस्',
  'photo.customerSees': 'ग्राहकले यी फोटो आफ्नो कामसँगै देख्न सक्छन्।',
  'photo.whatShowing': 'यसमा के देखाइएको छ?',
  'photo.captionHint': 'अगाडि बायाँको घिसिएको प्याड',
  'photo.chooseFirst': 'पहिले फोटो छान्नुहोस्',
  'photo.couldNotLoad': 'यो फोटो लोड गर्न सकिएन',

  'booking.slot.Morning': 'बिहान',
  'booking.slot.Afternoon': 'दिउँसो',
  'booking.slot.Evening': 'साँझ',
  'booking.slot.Any time': 'कुनै पनि समय',
  'booking.whichVehicle': 'कुन सवारी?',
  'booking.whatIsWrong': 'के समस्या छ?',
  'booking.complaintHint':
      'तपाईंले जे देख्नुभयो लेख्नुहोस् — आवाज, बत्ती बल्नु, चुहावट…',
  'booking.complaintRequired': 'के हेर्नुपर्ने हो वर्कशपलाई बताउनुहोस्',
  'booking.whenSuits': 'कुन बेला मिल्छ?',
  'booking.anythingElse': 'भित्र हुँदा अरू केही?',
  'booking.extrasFor': 'तपाईंको {0} का लागि ऐच्छिक थप सेवा।',
  'booking.pricesHeld': 'यहाँ देखिएको मूल्य कायम रहन्छ।',
  'booking.noExtras': 'वर्कशपले अझै थप सेवा राखेको छैन।',
  'booking.isRequest':
      'यो अनुरोध मात्र हो। वर्कशपले मिति पक्का गर्नेछ, र सवारी हेरेपछि मूल्य '
          'बताउनेछ।',
  'booking.repairQuoted':
      'मर्मतको मूल्य वर्कशपले सवारी हेरेपछि मात्र तय हुन्छ।',
  'booking.submit': 'बुकिङ अनुरोध गर्नुहोस्',

  'pay.title': 'यो बिल तिर्नुहोस्',
  'pay.amountDue': 'तिर्नुपर्ने रकम',
  'pay.couldNotOpen': '{0} खोल्न सकिएन। ब्राउजर छ?',
  'pay.waiting':
      '{0} को पुष्टि पर्खाइमा। तिरिसकेपछि यहाँ फर्कनुहोस्।',
  'pay.checkAgain': 'फेरि जाँच्नुहोस्',
  'pay.differentWay': 'अर्को तरिकाले तिर्नुहोस्',
  'pay.notAvailable':
      'यो वर्कशपले अनलाइन भुक्तानी लिँदैन। काउन्टरमा तिर्नुहोस्।',
  'pay.payWith': 'यसबाट तिर्नुहोस्',
  'pay.authorise':
      'अनुमति दिन एप वा वेबसाइटमा लगिनेछ। त्यहाँ पुष्टि नगरेसम्म कुनै रकम '
          'काटिँदैन।',
  'pay.walletBankCard': 'वालेट, बैंक वा कार्ड',
  'pay.online': 'अनलाइन तिर्नुहोस्',
  'pay.bankTransfer': 'बैंक ट्रान्सफर',
  'pay.bankName': 'बैंक',
  'pay.accountName': 'खाताको नाम',
  'pay.accountNumber': 'खाता नम्बर',
  'pay.branch': 'शाखा',
  'pay.iHaveTransferred': 'मैले पठाइसकें',
  'pay.bankNote': 'यसले वर्कशपलाई तपाईंको रकम खोज्न भन्छ। उनीहरूले खातामा पुष्टि नगरेसम्म बिल खुला रहन्छ।',
  'pay.copied': 'कपी भयो',
  'pay.copy': 'कपी गर्नुहोस्',
  'pay.received': 'भुक्तानी प्राप्त भयो। धन्यवाद।',
  'pay.payAmount': '{0} तिर्नुहोस्',
  'pay.paidBy': '{0} बाट तिरियो',
  'bills.none': 'अझै बिल छैन।',
  'bills.viewBill': 'बिल हेर्नुहोस्',

  'bill.title': 'बिल',
  'bill.loading': 'बिल लोड हुँदै…',
  'bill.taxInvoice': 'कर बीजक',
  'bill.pan': 'स्थायी लेखा नम्बर',
  'bill.billedTo': 'बिल पाउने',
  'bill.issued': 'जारी मिति',
  'bill.vehicle': 'सवारी',
  'bill.odometer': 'ओडोमिटर',
  'bill.jobRef': 'जब',
  'bill.workRequested': 'भनिएको काम',
  'bill.mechanic': 'मेकानिक',
  'bill.completed': 'सकिएको',
  'bill.description': 'विवरण',
  'bill.qty': 'परिमाण',
  'bill.rate': 'दर',
  'bill.amount': 'रकम',
  'bill.subtotal': 'जम्मा',
  'bill.discount': 'छुट',
  'bill.pointsRedeemed': '{0} अंक सट्टा गरियो',
  'bill.taxable': 'कर लाग्ने रकम',
  'bill.vat': 'भ्याट {0}%',
  'bill.total': 'कुल',
  'bill.paidLabel': 'तिरिएको',
  'bill.dueLabel': 'तिर्न बाँकी',
  'bill.payments': 'प्राप्त भुक्तानी',
  'bill.noBreakdown':
      'कामको विस्तृत विवरण अब फाइलमा छैन। तलको जोडफल नै अभिलेख हो।',
  'bill.kind.labour': 'ज्याला',
  'bill.kind.part': 'पार्ट्स',
  'bill.kind.service': 'सर्भिस',
  'bill.thanks': 'तपाईंलाई धन्यवाद।',
  'bill.generated': 'GarageFlow एपबाट {0} मा सेभ गरिएको।',
  'bill.saveImage': 'फोटोका रूपमा सेभ गर्नुहोस्',
  'bill.savePdf': 'PDF मा सेभ गर्नुहोस्',
  'bill.preparing': 'तयार हुँदै…',
  'bill.saveFailed': 'फाइल तयार गर्न सकिएन। फेरि प्रयास गर्नुहोस्।',
  'bill.shareSubject': 'बिल {0} — {1}',

  'history.loading': 'तपाईंको इतिहास लोड हुँदै…',
  'history.emptyTitle': 'अझै सकिएको सर्भिस छैन',
  'history.emptyMessage':
      'वर्कशपले काम सकेपछि यहाँ अभिलेखका रूपमा देखिन्छ।',

  'driver.noPin': 'यो ठेगानामा नक्सामा पिन छैन।',
  'driver.noMapsApp': 'खोल्न मिल्ने नक्सा एप छैन।',
  'driver.noDialler': 'डायलर खोल्न सकिएन।',
  'driver.locationUnavailable': 'स्थान उपलब्ध छैन।',
  'driver.confirmDelivered': '{0} अब {1} सँग छ भनी पुष्टि गर्नुहोस्।',
  'driver.notYet': 'अझै भएको छैन',
  'driver.handedOver': 'हस्तान्तरण भयो। राम्रो।',
  'driver.handedOverAt': '{0} बजे हस्तान्तरण भयो।',
  'driver.loadingTrip': 'यात्रा लोड हुँदै…',
  'driver.notFound': 'त्यो हस्तान्तरण भेटिएन।',
  'driver.appSettings': 'एप सेटिङ',
  'driver.locationSettings': 'स्थान सेटिङ',
  'driver.deliveredQuestion': 'पुर्‍याइयो?',
  'driver.handedOverQuestion': 'हस्तान्तरण भयो?',
  'driver.deliveredBody': '{0} {1} लाई पुर्‍याइयो।',
  'driver.collectedBody': '{0} ले {1} लगे।',

  'handover.notAvailableNow': 'अहिले उपलब्ध छैन',
  'handover.notAvailableAddress': 'तपाईंको ठेगानाका लागि उपलब्ध छैन',
  'handover.confirmDelivery': 'डेलिभरी पक्का गर्नुहोस्',
  'handover.confirmFee': 'पक्का गर्नुहोस् — {0}',
  'handover.yourVehicle': 'तपाईंको सवारी',
  'handover.stale': 'अन्तिम थाहा भएको स्थान देखाइँदै। {0}',

  'garages.nowViewing': 'अब {0} हेर्दै।',
  'garages.noMatch': '“{0}” सँग मिल्ने केही भेटिएन',
  'garages.tryShorter': 'छोटो शब्द वा ठाउँको नाम प्रयोग गर्नुहोस्।',

  'jobs.noneOfStatus': '{0} काम छैन',
  'jobs.tryClearing': 'फिल्टर हटाएर हेर्नुहोस्।',

  'alerts.emptyMessage': 'तपाईंका काम र बुकिङका अपडेट यहाँ देखिनेछन्।',

  'plansPitch.title': 'GarageFlow, पर्खनु नपर्ने गरी',
  'plansPitch.subtitle':
      'सशुल्क प्लानले थप्ने केही कुरा। हेर्नुहोस् — निःशुल्क एप अहिलेकै जस्तै '
          'चलिरहन्छ।',
  'plansPitch.noAds.title': 'विज्ञापन छैन',
  'plansPitch.noAds.body': 'तपाईं र तपाईंको सवारीबीच केही आउँदैन।',
  'plansPitch.instant.title': 'तुरुन्तै सूचना',
  'plansPitch.instant.body':
      'वर्कशपले काम अघि बढाउनासाथ फोन बज्छ — एप खोल्दा मात्र होइन।',
  'plansPitch.parts.title': 'पार्ट्स फेर्ने सम्झना',
  'plansPitch.parts.body':
      'ब्रेक प्याड वा मोबिल फेर्ने समय आउनुअघि नै खबर, पछि होइन।',
  'plansPitch.history.title': 'सम्पूर्ण इतिहास',
  'plansPitch.history.body':
      'जति पुरानो भए पनि हरेक सर्भिस र हरेक बिल सुरक्षित र खोज्न मिल्ने।',
  'plansPitch.explore': 'प्लानहरू हेर्नुहोस्',
  'plansPitch.notNow': 'अहिले होइन',

  'plans.title': 'प्लानहरू',
  'plans.rowSub': 'सशुल्क प्लानले के थप्छ हेर्नुहोस्',
  'plans.subtitle': 'जति अवधिको चाहनुहुन्छ, त्यति तिर्नुहोस्',
  'plans.popular': 'सबैभन्दा फाइदाजनक',
  'plans.freePrice': 'निःशुल्क',
  'plans.yourPlan': 'तपाईंको प्लान',
  'plans.worksOutAt': 'महिनाको {0} पर्ने',
  'plans.payWith': '{0} बाट तिर्नुहोस्',
  'plans.thanks': 'धन्यवाद। तपाईंको प्लान सक्रिय भयो।',
  'plans.activeUntil': 'तपाईंको प्लान {0} सम्म चल्छ',
  'plans.endingSoon':
      'तपाईंको प्लान {0} दिनमा सकिन्छ। जारी राख्न नवीकरण गर्नुहोस्।',
  'plans.comingSoon': 'चाँडै आउँदै',
  'plans.freeFallback':
      'सशुल्क प्लान सकिएपछि तपाईंको खाता यसैमा फर्कन्छ।',
  'plans.noWalletShort': 'अनलाइन भुक्तानी मिलाइएको छैन',
  'plans.noWallet':
      'सर्भरमा अनलाइन वालेट मिलाइएको छैन, त्यसैले एपबाट प्लान किन्न मिल्दैन।',
  'plans.footnote':
      'मूल्य नेपाली रुपैयाँमा हो र करसहित हो। प्लान तपाईंको खातामा लागू हुन्छ, '
          'एउटा सवारीमा होइन, र समय बाँकी छँदै नवीकरण गर्दा बाँकी दिन जोडिन्छ।',
  'plans.noneTitle': 'कुनै प्लान छैन',
  'plans.noneMessage': 'अहिले एपका सबै कुरा निःशुल्क छन्।',

  'period.monthly': '/ महिना',
  'period.quarterly': '/ ३ महिना',
  'period.yearly': '/ वर्ष',
  'period.months': '/ {0} महिना',

  'plan.free.name': 'निःशुल्क',
  'plan.free.tagline': 'एपले अहिले गर्ने सबै कुरा',
  'plan.free.features':
      'सर्भिस बुक गरी काम हेर्ने|तपाईंका बिल र भुक्तानी|'
          'गाराजका इनाम र अफर|जुनसुकै बिल PDF मा सेभ गर्ने',
  'plan.monthly.name': 'मासिक',
  'plan.monthly.tagline': 'एक महिना चलाएर हेर्नुहोस्',
  'plan.monthly.features':
      'कतै पनि विज्ञापन छैन|काम अघि बढ्नासाथ तुरुन्तै सूचना|'
          'पार्ट्स फेर्ने समय आउनुअघि सम्झना|जति पुरानो भए पनि पूरा सर्भिस इतिहास',
  'plan.quarterly.name': 'त्रैमासिक',
  'plan.quarterly.tagline': 'तीन महिना, मासिकको आधा दरमा',
  'plan.quarterly.features':
      'मासिक प्लानका सबै कुरा|डेढ महिनाको पैसामा तीन महिना|'
          'एउटै खातामा तपाईंका सबै सवारी',
  'plan.yearly.name': 'वार्षिक',
  'plan.yearly.tagline': 'पूरा वर्ष, र सबैभन्दा सस्तो तरिका',
  'plan.yearly.features':
      'त्रैमासिक प्लानका सबै कुरा|पूरा एक वर्षको सुविधा|'
          'गाराजमा प्राथमिकतासहित बुकिङ|लेखापालका लागि बिल निर्यात',
};
