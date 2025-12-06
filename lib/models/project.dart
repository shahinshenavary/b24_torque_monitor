class Project {
  final String id;
  final String name;
  final String location;
  final int createdAt;

  Project({
    required this.id,
    required this.name,
    required this.location,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'createdAt': createdAt,
    };
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] as String,
      name: map['name'] as String,
      location: map['location'] as String,
      createdAt: map['createdAt'] as int,
    );
  }

  Project copyWith({
    String? id,
    String? name,
    String? location,
    int? createdAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
