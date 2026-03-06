class DeviceDetail {
  final String devEui;
  final String name;
  final String description;
  final Map<String, dynamic> variables;
  final String createdAt;
  final String updatedAt;
  final String lastSeenAt;

  DeviceDetail({
    required this.devEui,
    required this.name,
    required this.description,
    required this.variables,
    required this.createdAt,
    required this.updatedAt,
    required this.lastSeenAt,
  });

  factory DeviceDetail.fromJson(Map<String, dynamic> json) {
    // Safely extract the device object
    final device = json['device'] ?? {};

    return DeviceDetail(
      devEui: device['devEui'] ?? '',
      name: device['name'] ?? '',
      description: device['description'] ?? '',
      variables: device['variables'] ?? {},
      createdAt: device['createdAt'] ?? '',
      updatedAt: device['updatedAt'] ?? '',
      lastSeenAt: device['lastSeenAt'] ?? json['lastSeenAt'] ?? '', // Sometimes lastSeenAt is outside 'device'
    );
  }
}