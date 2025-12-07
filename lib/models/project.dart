class Project {
  final String id;
  final String name;
  final String location;
  final int createdAt;
  final List<int> deviceDataTags; // List of DATA TAGs (hex values)
  final String viewPin; // VIEW PIN for XOR decryption

  Project({
    required this.id,
    required this.name,
    required this.location,
    required this.createdAt,
    this.deviceDataTags = const [], // Default empty
    this.viewPin = '0000', // Default VIEW PIN
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'createdAt': createdAt,
      'deviceDataTags': deviceDataTags.join(','), // Store as comma-separated string
      'viewPin': viewPin,
    };
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    // Parse comma-separated string back to List<int>
    final tagsString = map['deviceDataTags'] as String? ?? '';
    final tagsList = tagsString.isEmpty 
        ? <int>[]
        : tagsString.split(',').map((e) => int.parse(e)).toList();
    
    return Project(
      id: map['id'] as String,
      name: map['name'] as String,
      location: map['location'] as String,
      createdAt: map['createdAt'] as int,
      deviceDataTags: tagsList,
      viewPin: map['viewPin'] as String? ?? '0000',
    );
  }

  Project copyWith({
    String? id,
    String? name,
    String? location,
    int? createdAt,
    List<int>? deviceDataTags,
    String? viewPin,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      deviceDataTags: deviceDataTags ?? this.deviceDataTags,
      viewPin: viewPin ?? this.viewPin,
    );
  }
}
