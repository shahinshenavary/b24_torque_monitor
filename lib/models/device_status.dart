/// B24 Device Status - Parsed from Status Byte
/// Based on B24 Manual Table 2
class DeviceStatus {
  final int rawByte;
  final bool shuntCal;        // Bit 0
  final bool integrityError;  // Bit 1 - Sensor error!
  final bool isTared;         // Bit 2 - Net weight (Tare applied)
  final bool overRange;       // Bit 3 - Over sensitivity/display range!
  final bool fastMode;        // Bit 4
  final bool batteryLow;      // Bit 5 - Battery low!
  final bool digitalInput;    // Bit 6
  
  DeviceStatus({
    required this.rawByte,
    required this.shuntCal,
    required this.integrityError,
    required this.isTared,
    required this.overRange,
    required this.fastMode,
    required this.batteryLow,
    required this.digitalInput,
  });
  
  /// Parse status byte to individual flags
  factory DeviceStatus.fromByte(int statusByte) {
    return DeviceStatus(
      rawByte: statusByte,
      shuntCal: (statusByte & 0x01) != 0,      // Bit 0
      integrityError: (statusByte & 0x02) != 0, // Bit 1
      isTared: (statusByte & 0x04) != 0,        // Bit 2
      overRange: (statusByte & 0x08) != 0,      // Bit 3
      fastMode: (statusByte & 0x10) != 0,       // Bit 4
      batteryLow: (statusByte & 0x20) != 0,     // Bit 5
      digitalInput: (statusByte & 0x40) != 0,   // Bit 6
    );
  }
  
  /// Helper for mock data - all OK status
  static final DeviceStatus ok = DeviceStatus.fromByte(0x00);
  
  /// Check if there are any critical errors
  bool get hasCriticalError => integrityError || overRange;
  
  /// Check if there are any warnings
  bool get hasWarning => batteryLow;
  
  /// Get human-readable status summary
  String get summary {
    List<String> issues = [];
    
    if (integrityError) issues.add('⚠️ Sensor Error');
    if (overRange) issues.add('⚠️ Over Range');
    if (batteryLow) issues.add('🔋 Battery Low');
    if (isTared) issues.add('Net');
    if (fastMode) issues.add('Fast Mode');
    
    if (issues.isEmpty) return '✅ Normal';
    return issues.join(', ');
  }
  
  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'rawByte': rawByte,
      'shuntCal': shuntCal,
      'integrityError': integrityError,
      'isTared': isTared,
      'overRange': overRange,
      'fastMode': fastMode,
      'batteryLow': batteryLow,
      'digitalInput': digitalInput,
    };
  }
  
  /// Create from JSON (from database)
  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      rawByte: json['rawByte'] as int,
      shuntCal: json['shuntCal'] as bool,
      integrityError: json['integrityError'] as bool,
      isTared: json['isTared'] as bool,
      overRange: json['overRange'] as bool,
      fastMode: json['fastMode'] as bool,
      batteryLow: json['batteryLow'] as bool,
      digitalInput: json['digitalInput'] as bool,
    );
  }
}