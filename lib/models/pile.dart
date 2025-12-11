class Pile {
  final String id;
  final String projectId;
  final String pileId;
  final String pileNumber;
  final String pileType;
  final double expectedTorque;
  final double expectedDepth;
  final String status; // pending, in_progress, done, edited
  final double? finalDepth;
  final String? editReason; // ✅ توضیحات برای شمع‌های edit شده

  Pile({
    required this.id,
    required this.projectId,
    required this.pileId,
    required this.pileNumber,
    required this.pileType,
    required this.expectedTorque,
    required this.expectedDepth,
    this.status = 'pending',
    this.finalDepth,
    this.editReason, // ✅ اضافه شد
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'pileId': pileId,
      'pileNumber': pileNumber,
      'pileType': pileType,
      'expectedTorque': expectedTorque,
      'expectedDepth': expectedDepth,
      'status': status,
      'finalDepth': finalDepth,
      'editReason': editReason, // ✅ اضافه شد
    };
  }

  factory Pile.fromMap(Map<String, dynamic> map) {
    return Pile(
      id: map['id'] as String,
      projectId: map['projectId'] as String,
      pileId: map['pileId'] as String,
      pileNumber: map['pileNumber'] as String,
      pileType: map['pileType'] as String,
      expectedTorque: (map['expectedTorque'] as num).toDouble(),
      expectedDepth: (map['expectedDepth'] as num).toDouble(),
      status: map['status'] as String? ?? 'pending',
      finalDepth: map['finalDepth'] != null ? (map['finalDepth'] as num).toDouble() : null,
      editReason: map['editReason'] as String?, // ✅ اضافه شد
    );
  }

  Pile copyWith({
    String? id,
    String? projectId,
    String? pileId,
    String? pileNumber,
    String? pileType,
    double? expectedTorque,
    double? expectedDepth,
    String? status,
    double? finalDepth,
    String? editReason, // ✅ اضافه شد
  }) {
    return Pile(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      pileId: pileId ?? this.pileId,
      pileNumber: pileNumber ?? this.pileNumber,
      pileType: pileType ?? this.pileType,
      expectedTorque: expectedTorque ?? this.expectedTorque,
      expectedDepth: expectedDepth ?? this.expectedDepth,
      status: status ?? this.status,
      finalDepth: finalDepth ?? this.finalDepth,
      editReason: editReason ?? this.editReason, // ✅ اضافه شد
    );
  }
}