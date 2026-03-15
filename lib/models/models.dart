class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String role; // 'customer' or 'collector'
  final int coins;

  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.coins = 0,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] ?? '',
      fullName: map['full_name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'customer',
      coins: (map['coins'] ?? 0) is int ? map['coins'] ?? 0 : (map['coins'] as num).toInt(),
    );
  }

  bool get isCollector => role == 'collector';
  bool get isCustomer => role == 'customer';
}

class SmartBin {
  final String id;
  final String ownerId;
  final String? ownerName;
  final String? locationName;
  final double latitude;
  final double longitude;
  final double currentWeight;
  final double threshold;
  final bool isFull;
  final DateTime? lastCollectedAt;

  SmartBin({
    required this.id,
    required this.ownerId,
    this.ownerName,
    this.locationName,
    required this.latitude,
    required this.longitude,
    required this.currentWeight,
    required this.threshold,
    required this.isFull,
    this.lastCollectedAt,
  });

  factory SmartBin.fromMap(Map<String, dynamic> map) {
    return SmartBin(
      id: map['id'] ?? '',
      ownerId: map['owner_id'] ?? '',
      ownerName: map['owner_name'],
      locationName: map['location_name'],
      latitude: (map['location_lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['location_lng'] as num?)?.toDouble() ?? 0.0,
      currentWeight: (map['current_weight'] as num?)?.toDouble() ?? 0.0,
      threshold: (map['threshold'] as num?)?.toDouble() ?? 10.0,
      isFull: map['is_full'] ?? false,
      lastCollectedAt: map['last_collected_at'] != null
          ? DateTime.tryParse(map['last_collected_at'])
          : null,
    );
  }

  double get fillPercentage =>
      threshold > 0 ? (currentWeight / threshold).clamp(0.0, 1.0) : 0.0;
}

class Reward {
  final String id;
  final String title;
  final String description;
  final int cost;
  final String sponsor;
  final String? imageUrl;

  Reward({
    required this.id,
    required this.title,
    required this.description,
    required this.cost,
    required this.sponsor,
    this.imageUrl,
  });

  factory Reward.fromMap(Map<String, dynamic> map) {
    return Reward(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      cost: (map['cost'] ?? 0) is int ? map['cost'] ?? 0 : (map['cost'] as num).toInt(),
      sponsor: map['sponsor'] ?? '',
      imageUrl: map['image_url'],
    );
  }
}

class CoinTransaction {
  final String id;
  final String userId;
  final int amount;
  final String type; // 'reward', 'redemption', 'purchase'
  final String description;
  final DateTime createdAt;

  CoinTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.description,
    required this.createdAt,
  });

  factory CoinTransaction.fromMap(Map<String, dynamic> map) {
    return CoinTransaction(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      amount: (map['amount'] ?? 0) is int ? map['amount'] ?? 0 : (map['amount'] as num).toInt(),
      type: map['type'] ?? '',
      description: map['description'] ?? '',
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
