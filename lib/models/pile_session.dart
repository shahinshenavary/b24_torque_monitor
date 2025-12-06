class PileSession {
  final String id;
  final String projectId;
  final String pileId;
  final String operatorCode;
  final int startTime;
  final int? endTime;
  final String status;

  PileSession({
    required this.id,
    required this.projectId,
    required this.pileId,
    required this.operatorCode,
    required this.startTime,
    this.endTime,
    this.status = 'active',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'pileId': pileId,
      'operatorCode': operatorCode,
      'startTime': startTime,
      'endTime': endTime,
      'status': status,
    };
  }

  factory PileSession.fromMap(Map<String, dynamic> map) {
    return PileSession(
      id: map['id'] as String,
      projectId: map['projectId'] as String,
      pileId: map['pileId'] as String,
      operatorCode: map['operatorCode'] as String,
      startTime: map['startTime'] as int,
      endTime: map['endTime'] as int?,
      status: map['status'] as String? ?? 'active',
    );
  }

  PileSession copyWith({
    String? id,
    String? projectId,
    String? pileId,
    String? operatorCode,
    int? startTime,
    int? endTime,
    String? status,
  }) {
    return PileSession(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      pileId: pileId ?? this.pileId,
      operatorCode: operatorCode ?? this.operatorCode,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
    );
  }
}
