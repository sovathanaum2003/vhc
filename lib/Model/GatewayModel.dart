class Gateway {
  final String gatewayId;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final double altitude;
  final String createdAt;
  final String updatedAt;
  final String lastSeenAt;
  final String state;

  Gateway({
    required this.gatewayId,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.createdAt,
    required this.updatedAt,
    required this.lastSeenAt,
    required this.state,
  });

  factory Gateway.fromJson(Map<String, dynamic> json) {
    return Gateway(
      gatewayId: json['gatewayId'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      latitude: (json['location']?['latitude'] ?? 0).toDouble(),
      longitude: (json['location']?['longitude'] ?? 0).toDouble(),
      altitude: (json['location']?['altitude'] ?? 0).toDouble(),
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      lastSeenAt: json['lastSeenAt'] ?? '',
      state: json['state'] ?? 'UNKNOWN',
    );
  }
}
