class MiniTeam {
  final int id;
  final String name;
  final String shortCode;
  final String imagePath;

  MiniTeam({
    required this.id,
    required this.name,
    required this.shortCode,
    required this.imagePath,
  });

  factory MiniTeam.fromJson(Map<String, dynamic> json) {
    return MiniTeam(
      id: json['id'],
      name: json['name'],
      shortCode: json['short_code'],
      imagePath: json['image_path'],
    );
  }
}