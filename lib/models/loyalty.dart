/// Where this customer stands in one garage's scheme.
///
/// Both flags can be false, and that is the ordinary case: most workshops run
/// no scheme at all. The screen reads them rather than guessing from zeroes —
/// "0 points" and "this garage does not do points" look identical in the data
/// and mean completely different things to a person.
class LoyaltyCard {
  const LoyaltyCard({
    required this.stampCardRuns,
    required this.pointsRun,
    required this.jobsPerReward,
    required this.stampsOnCard,
    required this.completedJobs,
    required this.rewardsAvailable,
    required this.pointsBalance,
    required this.pointsValue,
    required this.minimumPointsToRedeem,
    this.rewardName,
    this.rewardValue = 0,
  });

  final bool stampCardRuns;
  final bool pointsRun;

  /// Completed jobs that fill one card.
  final int jobsPerReward;

  /// Stamps on the current card — 0 to [jobsPerReward] − 1.
  final int stampsOnCard;

  final int completedJobs;

  /// Free services earned and not yet spent.
  final int rewardsAvailable;

  final int pointsBalance;

  /// What the balance is worth in rupees at today's rate.
  final double pointsValue;

  final int minimumPointsToRedeem;

  /// The service the card pays out, when there is one.
  final String? rewardName;
  final double rewardValue;

  /// Whether there is anything at all to show.
  bool get runs => stampCardRuns || pointsRun;

  /// Jobs still needed to fill the card. Never negative.
  int get stampsToGo =>
      jobsPerReward <= 0 ? 0 : (jobsPerReward - stampsOnCard).clamp(0, jobsPerReward);

  /// True once there are enough points to be worth spending.
  bool get canRedeemPoints =>
      pointsRun && pointsBalance >= minimumPointsToRedeem && minimumPointsToRedeem >= 0;

  factory LoyaltyCard.fromJson(Map<String, dynamic> json) => LoyaltyCard(
    stampCardRuns: json['stampCardRuns'] as bool? ?? false,
    pointsRun: json['pointsRun'] as bool? ?? false,
    jobsPerReward: (json['jobsPerReward'] as num?)?.toInt() ?? 0,
    stampsOnCard: (json['stampsOnCard'] as num?)?.toInt() ?? 0,
    completedJobs: (json['completedJobs'] as num?)?.toInt() ?? 0,
    rewardsAvailable: (json['rewardsAvailable'] as num?)?.toInt() ?? 0,
    pointsBalance: (json['pointsBalance'] as num?)?.toInt() ?? 0,
    pointsValue: (json['pointsValue'] as num?)?.toDouble() ?? 0,
    minimumPointsToRedeem: (json['minimumPointsToRedeem'] as num?)?.toInt() ?? 0,
    rewardName: json['rewardName'] as String?,
    rewardValue: (json['rewardValue'] as num?)?.toDouble() ?? 0,
  );
}

/// One movement on the customer's loyalty account.
///
/// Exists because a balance cannot answer "where did my points go?", which is
/// the question a scheme generates most often.
class LoyaltyEntry {
  const LoyaltyEntry({
    required this.id,
    required this.kind,
    required this.note,
    required this.points,
    required this.at,
  });

  final int id;

  /// One of `stamp`, `reward-earned`, `reward-redeemed`, `points-earned`,
  /// `points-redeemed`.
  final String kind;

  /// The server's own sentence, shown verbatim.
  final String note;

  /// Positive when earned, negative when spent, 0 for a stamp.
  final int points;

  final DateTime at;

  bool get isSpend => points < 0 || kind == 'reward-redeemed';
  bool get isReward => kind == 'reward-earned' || kind == 'reward-redeemed';

  factory LoyaltyEntry.fromJson(Map<String, dynamic> json) => LoyaltyEntry(
    id: (json['id'] as num?)?.toInt() ?? 0,
    kind: json['kind'] as String? ?? '',
    note: json['note'] as String? ?? '',
    points: (json['points'] as num?)?.toInt() ?? 0,
    at: DateTime.parse(json['at'] as String).toLocal(),
  );
}

/// A promotion the garage is running right now.
///
/// Only live offers ever reach the app — the endpoint filters by date — so
/// there is no "starts next week" state to render.
class Offer {
  const Offer({
    required this.id,
    required this.name,
    required this.description,
    required this.percent,
    required this.categories,
    required this.vehicleTypes,
    this.maxDiscount,
    this.endsOn,
  });

  final String id;
  final String name;
  final String description;

  /// Whole percent — 15 means 15%.
  final double percent;

  /// Empty means every category.
  final List<String> categories;

  /// Empty means every vehicle.
  final List<String> vehicleTypes;

  final double? maxDiscount;
  final DateTime? endsOn;

  /// What the offer covers, as a short phrase. Empty filters mean everything.
  String get scope {
    final parts = [
      if (categories.isNotEmpty) categories.join(', '),
      if (vehicleTypes.isNotEmpty) vehicleTypes.join(', '),
    ];

    return parts.join(' · ');
  }

  factory Offer.fromJson(Map<String, dynamic> json) => Offer(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    percent: (json['percent'] as num?)?.toDouble() ?? 0,
    categories: ((json['categories'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    vehicleTypes: ((json['vehicleTypes'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    maxDiscount: (json['maxDiscount'] as num?)?.toDouble(),
    endsOn: json['endsOn'] == null
        ? null
        : DateTime.parse(json['endsOn'] as String),
  );
}

/// Stars left on a finished job.
class JobRating {
  const JobRating({
    required this.stars,
    required this.mechanic,
    required this.comment,
    this.mechanicStars,
  });

  final int stars;

  /// Null when the job had nobody assigned — there is no mechanic to score.
  final int? mechanicStars;

  final String mechanic;
  final String comment;

  factory JobRating.fromJson(Map<String, dynamic> json) => JobRating(
    stars: (json['stars'] as num?)?.toInt() ?? 0,
    mechanicStars: (json['mechanicStars'] as num?)?.toInt(),
    mechanic: json['mechanic'] as String? ?? '',
    comment: json['comment'] as String? ?? '',
  );
}

/// One mechanic's average, for their own screen.
class MechanicRating {
  const MechanicRating({
    required this.mechanic,
    required this.ratingCount,
    this.average,
  });

  final String mechanic;
  final int ratingCount;

  /// Null when nobody has rated them. Rendered as "not rated yet" rather than
  /// as 0.0, which would read as the worst score in the shop.
  final double? average;

  factory MechanicRating.fromJson(Map<String, dynamic> json) => MechanicRating(
    mechanic: json['mechanic'] as String? ?? '',
    ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
    average: (json['average'] as num?)?.toDouble(),
  );
}
