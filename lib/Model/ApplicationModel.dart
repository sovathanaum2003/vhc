class ApplicationModel {
  final String id;
  final String name;
  final String description; // Added description in case you need it
  final String createdAt;
  final String updatedAt;

  ApplicationModel({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ApplicationModel.fromJson(Map<String, dynamic> json) {
    return ApplicationModel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Application',
      description: json['description'] ?? '',
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
    );
  }
}