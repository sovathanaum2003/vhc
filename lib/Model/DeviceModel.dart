class DeviceModel {
  final String devEui;
  final String name;
  final String lastSeenAt;

  DeviceModel({
    required this.devEui,
    required this.name,
    required this.lastSeenAt,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      devEui: json['devEUI'] ?? json['devEui'] ?? 'No EUI',
      name: json['name'] ?? 'Unknown Device',
      lastSeenAt: json['lastSeenAt'] ?? '',
    );
  }
}