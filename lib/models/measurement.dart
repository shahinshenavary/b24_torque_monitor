class Measurement {
  final String id;
  final String projectId;
  final String pileId;
  final String operatorCode;
  final int timestamp;
  final double torque;
  final double force;
  final double mass;
  final double depth;

  Measurement({
    required this.id,
    required this.projectId,
    required this.pileId,
    required this.operatorCode,
    required this.timestamp,
    required this.torque,
    required this.force,
    required this.mass,
    required this.depth,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'pileId': pileId,
      'operatorCode': operatorCode,
      'timestamp': timestamp,
      'torque': torque,
      'force': force,
      'mass': mass,
      'depth': depth,
    };
  }

  factory Measurement.fromMap(Map<String, dynamic> map) {
    return Measurement(
      id: map['id'] as String,
      projectId: map['projectId'] as String,
      pileId: map['pileId'] as String,
      operatorCode: map['operatorCode'] as String,
      timestamp: map['timestamp'] as int,
      torque: (map['torque'] as num).toDouble(),
      force: (map['force'] as num).toDouble(),
      mass: (map['mass'] as num).toDouble(),
      depth: (map['depth'] as num).toDouble(),
    );
  }

  Measurement copyWith({
    String? id,
    String? projectId,
    String? pileId,
    String? operatorCode,
    int? timestamp,
    double? torque,
    double? force,
    double? mass,
    double? depth,
  }) {
    return Measurement(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      pileId: pileId ?? this.pileId,
      operatorCode: operatorCode ?? this.operatorCode,
      timestamp: timestamp ?? this.timestamp,
      torque: torque ?? this.torque,
      force: force ?? this.force,
      mass: mass ?? this.mass,
      depth: depth ?? this.depth,
    );
  }
}
