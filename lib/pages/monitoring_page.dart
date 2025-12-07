import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/project.dart';
import '../models/pile.dart';
import '../models/measurement.dart';
import '../models/pile_session.dart';
import '../database/database_helper.dart';
import '../services/bluetooth_service.dart';

class MonitoringPage extends StatefulWidget {
  final Project project;
  final Pile pile;
  final String operatorCode;

  const MonitoringPage({
    Key? key,
    required this.project,
    required this.pile,
    required this.operatorCode,
  }) : super(key: key);

  @override
  State<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  static const int RECORDING_INTERVAL_MS = 1000;
  
  // ✅ Dynamic threshold loaded from settings
  double _recordingThreshold = 100.0;

  TorqueData _currentData = TorqueData(
    torque: 0,
    force: 0,
    mass: 0,
    timestamp: DateTime.now().millisecondsSinceEpoch,
  );

  // Debug info
  DebugInfo _debugInfo = DebugInfo(
    rawHex: '',
    decodedHex: '',
    status: '',
    error: '',
    isConnected: false,
    isMockData: false,
  );
  bool _showDebugPanel = true; // Show debug panel by default

  PileSession? _session;
  bool _isRecording = false;
  String _recordingStatus = 'idle'; // 'idle', 'recording', 'paused'
  int _recordCount = 0;
  double _currentDepth = 0;
  bool _isCompleted = false;
  bool _wasAboveThreshold = false;
  int _lastRecordTime = 0;
  
  StreamSubscription<TorqueData>? _dataSubscription;
  StreamSubscription<DebugInfo>? _debugSubscription;
  bool _isConnecting = false;
  String? _connectionError;

  @override
  void initState() {
    super.initState();
    _loadSession();
    _connectBluetooth();
    _loadRecordingThreshold();
  }

  Future<void> _loadRecordingThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    final threshold = prefs.getDouble('recording_threshold');
    if (threshold != null) {
      setState(() {
        _recordingThreshold = threshold;
      });
    }
  }

  Future<void> _loadSession() async {
    final session = await DatabaseHelper.instance.getActivePileSession(widget.pile.id);
    if (session != null) {
      setState(() {
        _session = session;
        _isRecording = session.status == 'active' || session.status == 'paused';
        _recordingStatus = session.status == 'active' ? 'recording' : 'paused';
      });

      final measurements = await DatabaseHelper.instance.getMeasurementsByPile(widget.pile.id);
      setState(() {
        _recordCount = measurements.length;
        if (measurements.isNotEmpty) {
          _currentDepth = measurements.last.depth;
        }
      });
    }
  }

  Future<void> _connectBluetooth() async {
    setState(() {
      _isConnecting = true;
      _connectionError = null;
    });

    try {
      // 🔐 Set VIEW PIN from project
      B24BluetoothService.instance.setViewPin(widget.project.viewPin);
      print("🔐 VIEW PIN set to: ${widget.project.viewPin}");
      
      // 🔐 Set allowed DATA TAGs from project
      if (widget.project.deviceDataTags.isNotEmpty) {
        B24BluetoothService.instance.setAllowedDataTags(widget.project.deviceDataTags);
        print("🔐 Filtering devices for project '${widget.project.name}':");
        print("   Allowed DATA TAGs: ${widget.project.deviceDataTags.map((t) => '0x${t.toRadixString(16).toUpperCase()}').join(', ')}");
      } else {
        B24BluetoothService.instance.clearDataTagFilter();
        print("⚠️ No DATA TAGs configured for this project - accepting all devices");
      }
      
      // Start listening to data stream first
      _dataSubscription = B24BluetoothService.instance.dataStream.listen((data) {
        setState(() => _currentData = data);
        _handleAutoRecording(data);
      });

      // Listen to debug info stream
      _debugSubscription = B24BluetoothService.instance.debugStream.listen((info) {
        setState(() => _debugInfo = info);
      });

      // 📡 Start Broadcast Monitoring (NO CONNECTION - just listen to advertising packets)
      try {
        print("📡 Starting Broadcast Monitoring (View Mode - No Connection)...");
        await B24BluetoothService.instance.startBroadcastMonitoring();
        
        print("✅ Broadcast Monitoring started successfully");
        print("📡 Now listening to B24 advertising packets");
        print("✅ Other apps can still connect to the device!");
        
        setState(() => _isConnecting = false);
      } catch (e) {
        print("❌ Broadcast Monitoring failed: $e");
        setState(() {
          _connectionError = 'Failed to start monitoring: $e\n\nPlease check Bluetooth permissions';
          _isConnecting = false;
        });
      }
    } catch (e) {
      setState(() {
        _connectionError = 'Connection error: $e';
        _isConnecting = false;
      });
    }
  }

  void _handleAutoRecording(TorqueData data) {
    if (_isCompleted) return;

    // ✅ Use absolute value to handle both clockwise (+) and counter-clockwise (-) rotation
    final isAboveThreshold = data.torque.abs() >= _recordingThreshold;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (isAboveThreshold && !_wasAboveThreshold) {
      _startOrResumeRecording();
    } else if (!isAboveThreshold && _wasAboveThreshold) {
      _pauseRecording();
    }

    _wasAboveThreshold = isAboveThreshold;

    if (_recordingStatus == 'recording' && _session != null) {
      if (now - _lastRecordTime >= RECORDING_INTERVAL_MS) {
        _saveMeasurement(data);
        _lastRecordTime = now;
      }
    }
  }

  Future<void> _startOrResumeRecording() async {
    try {
      PileSession currentSession = _session ?? PileSession(
        id: 'session-${DateTime.now().millisecondsSinceEpoch}',
        projectId: widget.project.id,
        pileId: widget.pile.id,
        operatorCode: widget.operatorCode,
        startTime: DateTime.now().millisecondsSinceEpoch,
        status: 'active',
      );

      if (_session == null) {
        await DatabaseHelper.instance.insertPileSession(currentSession);
      } else {
        currentSession = currentSession.copyWith(status: 'active');
        await DatabaseHelper.instance.updatePileSession(currentSession);
      }

      setState(() {
        _session = currentSession;
        _isRecording = true;
        _recordingStatus = 'recording';
      });
    } catch (e) {
      debugPrint('Error starting/resuming recording: $e');
    }
  }

  Future<void> _pauseRecording() async {
    if (_session == null) return;

    try {
      final updatedSession = _session!.copyWith(status: 'paused');
      await DatabaseHelper.instance.updatePileSession(updatedSession);
      
      setState(() {
        _session = updatedSession;
        _recordingStatus = 'paused';
      });
    } catch (e) {
      debugPrint('Error pausing recording: $e');
    }
  }

  Future<void> _saveMeasurement(TorqueData data) async {
    if (_session == null) return;

    try {
      final measurement = Measurement(
        id: 'measurement-${DateTime.now().millisecondsSinceEpoch}-$_recordCount',
        projectId: widget.project.id,
        pileId: widget.pile.id,
        operatorCode: widget.operatorCode,
        timestamp: data.timestamp,
        torque: data.torque,
        force: data.force,
        mass: data.mass,
        depth: _currentDepth + 0.1,
      );

      await DatabaseHelper.instance.insertMeasurement(measurement);
      
      setState(() {
        _recordCount++;
        _currentDepth += 0.1;
      });
    } catch (e) {
      debugPrint('Error saving measurement: $e');
    }
  }

  Future<void> _handleComplete() async {
    if (_session == null) return;

    // ✅ نمایش دیالوگ برای دریافت عمق نهایی
    final finalDepthController = TextEditingController(text: _currentDepth.toStringAsFixed(2));
    
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter Final Depth'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please enter the final depth of the pile:', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: finalDepthController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Final Depth (m)',
                hintText: 'e.g., 12.50',
                suffixText: 'm',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final finalDepth = double.tryParse(finalDepthController.text);
    if (finalDepth == null || finalDepth <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid depth'),
          backgroundColor: Color(0xFFF87171),
        ),
      );
      return;
    }

    try {
      final completedSession = _session!.copyWith(
        status: 'completed',
        endTime: DateTime.now().millisecondsSinceEpoch,
      );
      
      await DatabaseHelper.instance.updatePileSession(completedSession);
      
      // ✅ ذخیره عمق نهایی در Pile
      final updatedPile = widget.pile.copyWith(
        status: 'completed',
        finalDepth: finalDepth,
      );
      await DatabaseHelper.instance.updatePile(updatedPile);
      
      setState(() {
        _session = completedSession;
        _isCompleted = true;
        _isRecording = false;
        _recordingStatus = 'idle';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pile completed successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error completing session: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final torquePercent = (_currentData.torque / 250 * 100).clamp(0, 100);
    // ✅ Use absolute value to detect recording state in UI
    final isAboveThreshold = _currentData.torque.abs() >= _recordingThreshold;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.pile.pileId),
            Text(
              '${widget.project.name} - No. ${widget.pile.pileNumber}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
        actions: [
          if (_isCompleted)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, size: 16),
                  SizedBox(width: 4),
                  Text('Completed', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
      body: _isConnecting
          ? const Center(child: CircularProgressIndicator())
          : _connectionError != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bluetooth_disabled, size: 64, color: Color(0xFF9CA3AF)),
                      const SizedBox(height: 16),
                      Text(_connectionError!, style: const TextStyle(color: Color(0xFFF87171))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _connectBluetooth,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // 🔐 Device Filter Status Banner
                      if (widget.project.deviceDataTags.isNotEmpty)
                        Card(
                          color: const Color(0xFF1E3A8A),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.security, size: 20, color: Color(0xFF60A5FA)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Device Filter Active',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Only ${widget.project.deviceDataTags.length} authorized device(s): ${widget.project.deviceDataTags.map((t) => '0x${t.toRadixString(16).toUpperCase()}').join(', ')}',
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (widget.project.deviceDataTags.isEmpty)
                        Card(
                          color: const Color(0xFF78350F),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.warning, size: 20, color: Color(0xFFFBBF24)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'No Device Filter',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Accepting data from all B24 devices - configure device filters in project settings',
                                        style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                _recordingStatus == 'recording'
                                    ? Icons.fiber_manual_record
                                    : _recordingStatus == 'paused'
                                        ? Icons.pause_circle
                                        : Icons.play_circle_outline,
                                color: _recordingStatus == 'recording'
                                    ? const Color(0xFF10B981)
                                    : _recordingStatus == 'paused'
                                        ? const Color(0xFFFBBF24)
                                        : const Color(0xFF9CA3AF),
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _recordingStatus == 'recording'
                                          ? 'Auto Recording'
                                          : _recordingStatus == 'paused'
                                              ? 'Paused'
                                              : 'Ready',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _recordingStatus == 'recording'
                                          ? 'Torque ≥ ±${_recordingThreshold.toStringAsFixed(1)} Nm - Recording data'
                                          : _recordingStatus == 'paused'
                                              ? 'Torque < ±${_recordingThreshold.toStringAsFixed(1)} Nm - Waiting for drill'
                                              : 'Recording starts at ±${_recordingThreshold.toStringAsFixed(1)} Nm (both directions)',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  const Text('Records', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                  Text(
                                    '$_recordCount',
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.speed, color: Colors.blue[400]),
                                  const SizedBox(width: 8),
                                  const Text('Torque', style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 24),
                              
                              // 🔴 Expected Torque Reached Alert
                              if (_currentData.torque >= widget.pile.expectedTorque)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Blinking Circle Animation
                                      TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 0.3, end: 1.0),
                                        duration: const Duration(milliseconds: 800),
                                        builder: (context, value, child) {
                                          return Opacity(
                                            opacity: value,
                                            child: Container(
                                              width: 16,
                                              height: 16,
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          );
                                        },
                                        onEnd: () {
                                          // Trigger rebuild to restart animation
                                          if (mounted) setState(() {});
                                        },
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'EXPECTED TORQUE REACHED',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              
                              Text(
                                _currentData.torque.toStringAsFixed(5), // ✅ 5 decimal places
                                style: TextStyle(
                                  fontSize: 64,
                                  fontWeight: FontWeight.bold,
                                  color: isAboveThreshold ? const Color(0xFF10B981) : Colors.white,
                                ),
                              ),
                              const Text('Nm', style: TextStyle(color: Color(0xFF9CA3AF))),
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: torquePercent / 100,
                                  minHeight: 16,
                                  backgroundColor: const Color(0xFF374151),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isAboveThreshold ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('0', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                  Text(
                                    'Recording Threshold: ${_recordingThreshold.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isAboveThreshold ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
                                    ),
                                  ),
                                  const Text('250', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Expected Values', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Pile Type', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                      Text(widget.pile.pileType),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Number', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                      Text(widget.pile.pileNumber),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Torque', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                      Text('${widget.pile.expectedTorque} Nm'),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Depth', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                      Text('${widget.pile.expectedDepth} m'),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_isRecording && !_isCompleted)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _handleComplete,
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Complete & Finish'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      if (_isCompleted)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF064E3B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.check_circle, size: 48, color: Color(0xFF10B981)),
                              const SizedBox(height: 12),
                              const Text(
                                'Pile Completed Successfully',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$_recordCount records saved - Final depth: ${widget.pile.finalDepth?.toStringAsFixed(2) ?? _currentDepth.toStringAsFixed(2)} m',
                                style: const TextStyle(color: Color(0xFF9CA3AF)),
                              ),
                            ],
                          ),
                        ),
                      if (_showDebugPanel)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Debug Info', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Raw Hex', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                        Text(_debugInfo.rawHex),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Decoded Hex', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                        Text(_debugInfo.decodedHex),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Status', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                        Text(_debugInfo.status),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Error', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                        Text(_debugInfo.error),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Connected', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                        Text(_debugInfo.isConnected ? 'Yes' : 'No'),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Mock Data', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                        Text(_debugInfo.isMockData ? 'Yes' : 'No'),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _debugSubscription?.cancel();
    // Stop broadcast monitoring when leaving the page
    B24BluetoothService.instance.stopBroadcastMonitoring();
    // Clear DATA TAG filter
    B24BluetoothService.instance.clearDataTagFilter();
    super.dispose();
  }
}