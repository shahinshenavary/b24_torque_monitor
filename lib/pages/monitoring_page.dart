import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/project.dart';
import '../models/pile.dart';
import '../models/measurement.dart';
import '../models/pile_session.dart';
import '../models/device_status.dart';
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
  static const int BELOW_THRESHOLD_DELAY_MS = 5000; // 5 seconds
  
  double _recordingThreshold = 100.0;

  TorqueData _currentData = TorqueData(
    torque: 0,
    force: 0,
    mass: 0,
    timestamp: DateTime.now().millisecondsSinceEpoch,
    status: DeviceStatus.ok,
  );

  DebugInfo _debugInfo = DebugInfo(
    rawHex: '',
    decodedHex: '',
    status: '',
    error: '',
    isConnected: false,
    isMockData: false,
  );

  PileSession? _session;
  bool _isRecording = false; // Are we actively saving measurements?
  int _recordCount = 0;
  double _currentDepth = 0;
  bool _hasStartedRecording = false; // Has recording started at least once?
  bool _showStopButton = true; // Should Stop button be visible?
  Timer? _belowThresholdTimer; // Timer for 5-second delay
  double _maxTorqueRecorded = 0; // Track maximum torque
  int _lastSaveTimestamp = 0; // ✅ For throttling saves to 1 per second
  
  StreamSubscription<TorqueData>? _dataSubscription;
  StreamSubscription<DebugInfo>? _debugSubscription;
  bool _isConnecting = false;
  bool _isReconnecting = false; // ✅ Flag for reconnection state
  String? _connectionError;
  
  // ✅ Watchdog timer to detect frozen data
  Timer? _watchdogTimer;
  int _lastDataReceivedTimestamp = 0;
  int _watchdogTimeoutMs = 6000; // Default 6 seconds, now configurable
  
  // ✅ NEW: Averaging settings and buffer
  bool _useAveraging = false;
  int _averageSampleCount = 5;
  final List<double> _torqueBuffer = []; // Buffer to store recent torque values

  @override
  void initState() {
    super.initState();
    _loadSession();
    _loadSettings(); // ✅ Load all settings including averaging and watchdog
    _connectBluetooth();
  }

  // ✅ Load all settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final threshold = prefs.getDouble('recording_threshold') ?? 100.0;
    final useAveraging = prefs.getBool('use_averaging') ?? false;
    final averageCount = prefs.getInt('average_sample_count') ?? 5;
    final watchdogTimeout = prefs.getInt('watchdog_timeout_seconds') ?? 6;
    
    setState(() {
      _recordingThreshold = threshold;
      _useAveraging = useAveraging;
      _averageSampleCount = averageCount;
      _watchdogTimeoutMs = watchdogTimeout * 1000; // Convert to milliseconds
    });
    
    // Restart watchdog with new timeout
    _watchdogTimer?.cancel();
    _startWatchdogTimer();
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
    // Load existing measurements
    final measurements = await DatabaseHelper.instance.getMeasurementsByPile(widget.pile.id);
    
    if (measurements.isNotEmpty) {
      // Find max torque from existing records
      final maxTorque = measurements.map((m) => m.torque.abs()).reduce((a, b) => a > b ? a : b);
      
      setState(() {
        _recordCount = measurements.length;
        _currentDepth = measurements.last.depth;
        _maxTorqueRecorded = maxTorque;
      });
    }
    
    // Check if there's an active session (shouldn't be for this new flow)
    final session = await DatabaseHelper.instance.getActivePileSession(widget.pile.id);
    if (session != null) {
      setState(() {
        _session = session;
      });
    }
  }

  Future<void> _connectBluetooth() async {
    setState(() {
      _isConnecting = true;
      _connectionError = null;
    });

    try {
      B24BluetoothService.instance.setViewPin(widget.project.viewPin);
      
      if (widget.project.deviceDataTags.isNotEmpty) {
        B24BluetoothService.instance.setAllowedDataTags(widget.project.deviceDataTags);
      } else {
        B24BluetoothService.instance.clearDataTagFilter();
      }
      
      _dataSubscription = B24BluetoothService.instance.dataStream.listen((data) {
        setState(() => _currentData = data);
        _lastDataReceivedTimestamp = DateTime.now().millisecondsSinceEpoch; // ✅ Update timestamp
        _handleTorqueData(data);
      });

      _debugSubscription = B24BluetoothService.instance.debugStream.listen((info) {
        setState(() => _debugInfo = info);
      });

      await B24BluetoothService.instance.startBroadcastMonitoring();
      
      setState(() => _isConnecting = false);
    } catch (e) {
      setState(() {
        _connectionError = 'Failed to start monitoring: $e';
        _isConnecting = false;
      });
    }
  }

  void _handleTorqueData(TorqueData data) {
    // ✅ Add torque to buffer for averaging
    _torqueBuffer.add(data.torque);
    if (_torqueBuffer.length > _averageSampleCount) {
      _torqueBuffer.removeAt(0); // Remove oldest value
    }
    
    final isAboveThreshold = data.torque.abs() >= _recordingThreshold;
    
    if (isAboveThreshold) {
      // ✅ Torque is above threshold
      
      // Cancel timer if it was running
      _belowThresholdTimer?.cancel();
      _belowThresholdTimer = null;
      
      // Start recording if not already
      if (!_isRecording) {
        _startRecording();
      }
      
      // Hide Stop button
      if (_showStopButton) {
        setState(() => _showStopButton = false);
      }
      
      // Save measurement
      _saveMeasurement(data);
      
    } else {
      // ✅ Torque is below threshold
      
      if (_isRecording) {
        // Stop recording
        _isRecording = false;
        
        // Start 5-second timer if not already started
        if (_belowThresholdTimer == null) {
          _belowThresholdTimer = Timer(const Duration(milliseconds: BELOW_THRESHOLD_DELAY_MS), () {
            // After 5 seconds, show Stop button
            if (mounted) {
              setState(() => _showStopButton = true);
            }
          });
        }
      }
    }
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _hasStartedRecording = true;
    });
    
    // Create session if doesn't exist
    if (_session == null) {
      _session = PileSession(
        id: 'session-${DateTime.now().millisecondsSinceEpoch}',
        projectId: widget.project.id,
        pileId: widget.pile.id,
        operatorCode: widget.operatorCode,
        startTime: DateTime.now().millisecondsSinceEpoch,
        status: 'active',
      );
      DatabaseHelper.instance.insertPileSession(_session!);
    }
  }

  Future<void> _saveMeasurement(TorqueData data) async {
    if (_session == null) return;

    // ✅ Throttle: Only save 1 measurement per second
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSaveTimestamp < RECORDING_INTERVAL_MS) {
      return; // Skip this measurement
    }
    _lastSaveTimestamp = now;

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
        status: data.status,
      );

      await DatabaseHelper.instance.insertMeasurement(measurement);
      
      // Update max torque
      if (data.torque.abs() > _maxTorqueRecorded) {
        _maxTorqueRecorded = data.torque.abs();
      }
      
      setState(() {
        _recordCount++;
        _currentDepth += 0.1;
      });
      
      // ✅ Change pile status to in_progress after first record
      if (_recordCount == 1 && widget.pile.status == 'pending') {
        final updatedPile = widget.pile.copyWith(status: 'in_progress');
        await DatabaseHelper.instance.updatePile(updatedPile);
      }
      
      // ✅ For edited piles, change to in_progress after first new record
      if (_recordCount > 0 && widget.pile.status == 'edited') {
        final updatedPile = widget.pile.copyWith(status: 'in_progress');
        await DatabaseHelper.instance.updatePile(updatedPile);
      }
      
    } catch (e) {
      debugPrint('Error saving measurement: $e');
    }
  }

  Future<void> _handleStop() async {
    // If no records, just go back
    if (_recordCount == 0) {
      Navigator.of(context).pop();
      return;
    }
    
    // Check if max torque >= expected torque
    final reachedExpectedTorque = _maxTorqueRecorded >= widget.pile.expectedTorque;
    
    if (reachedExpectedTorque) {
      // ✅ Expected torque reached → Ask for final depth → Done
      await _askFinalDepthAndComplete();
    } else {
      // ❌ Expected torque NOT reached → Show Hold/Done dialog
      await _showHoldOrDoneDialog();
    }
  }

  Future<void> _askFinalDepthAndComplete() async {
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
      // Update session to completed
      if (_session != null) {
        final completedSession = _session!.copyWith(
          status: 'completed',
          endTime: DateTime.now().millisecondsSinceEpoch,
        );
        await DatabaseHelper.instance.updatePileSession(completedSession);
      }
      
      // Update pile to done
      final updatedPile = widget.pile.copyWith(
        status: 'done',
        finalDepth: finalDepth,
      );
      await DatabaseHelper.instance.updatePile(updatedPile);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pile completed successfully'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
        
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint('Error completing pile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFF87171),
          ),
        );
      }
    }
  }

  Future<void> _showHoldOrDoneDialog() async {
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Color(0xFFFBBF24), size: 28),
            SizedBox(width: 8),
            Text('Expected Torque Not Reached'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expected: ${widget.pile.expectedTorque.toStringAsFixed(1)} Nm',
              style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
            ),
            Text(
              'Recorded Max: ${_maxTorqueRecorded.toStringAsFixed(1)} Nm',
              style: const TextStyle(fontSize: 14, color: Color(0xFFF87171)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Do you want to hold the pile or mark it as done?',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop('hold'),
            child: const Text('Hold'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('done'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );

    if (choice == 'done') {
      await _askFinalDepthAndComplete();
    } else if (choice == 'hold') {
      // Set status to in_progress and go back
      try {
        final updatedPile = widget.pile.copyWith(status: 'in_progress');
        await DatabaseHelper.instance.updatePile(updatedPile);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pile held for further work'),
              backgroundColor: Color(0xFFFBBF24),
              duration: Duration(seconds: 2),
            ),
          );
          
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      } catch (e) {
        debugPrint('Error holding pile: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final torquePercent = (_currentData.torque.abs() / 250 * 100).clamp(0, 100);
    final isAboveThreshold = _currentData.torque.abs() >= _recordingThreshold;

    return WillPopScope(
      onWillPop: () async {
        // ✅ Disable back button - user must use Stop
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please use the Stop button to exit'),
            backgroundColor: Color(0xFFFBBF24),
            duration: Duration(seconds: 2),
          ),
        );
        return false;
      },
      child: Scaffold(
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
          automaticallyImplyLeading: false, // ✅ Hide back button
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
                        // ✅ Reconnecting Banner
                        if (_isReconnecting)
                          Card(
                            color: const Color(0xFFF59E0B),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Reconnecting to device...',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_isReconnecting) const SizedBox(height: 8),
                        
                        // Device Filter Status Banner
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
                                          'Only ${widget.project.deviceDataTags.length} authorized device(s)',
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        
                        // Recording Status Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  _isRecording
                                      ? Icons.fiber_manual_record
                                      : _hasStartedRecording
                                          ? Icons.pause_circle
                                          : Icons.radio_button_unchecked,
                                  color: _isRecording
                                      ? const Color(0xFFEF4444) // Red for recording
                                      : _hasStartedRecording
                                          ? const Color(0xFFFBBF24) // Yellow for paused
                                          : const Color(0xFF9CA3AF), // Gray for idle
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isRecording
                                            ? 'Recording'
                                            : _hasStartedRecording
                                                ? 'Paused'
                                                : 'Waiting for Threshold',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _isRecording
                                            ? 'Data is being recorded automatically'
                                            : _hasStartedRecording
                                                ? 'Torque below threshold - waiting...'
                                                : 'Torque must reach ${_recordingThreshold.toStringAsFixed(1)} Nm to start',
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
                        
                        // Device Status Indicators
                        _buildStatusIndicators(_currentData.status),
                        const SizedBox(height: 16),
                        
                        // Torque Display Card
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
                                
                                // Expected Torque Reached Alert
                                if (_currentData.torque.abs() >= widget.pile.expectedTorque)
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
                                  _displayedTorque.toStringAsFixed(5),
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
                                      'Threshold: ${_recordingThreshold.toStringAsFixed(1)}',
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
                        
                        // Expected Values Card
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
                        
                        // Stop Button (only show when allowed)
                        if (_showStopButton)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _handleStop,
                              icon: const Icon(Icons.stop_circle, size: 28),
                              label: const Text('Stop', style: TextStyle(fontSize: 18)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                padding: const EdgeInsets.symmetric(vertical: 20),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }

  @override
  void dispose() {
    _belowThresholdTimer?.cancel();
    _watchdogTimer?.cancel(); // ✅ Cancel watchdog timer
    _dataSubscription?.cancel();
    _debugSubscription?.cancel();
    B24BluetoothService.instance.stopBroadcastMonitoring();
    B24BluetoothService.instance.clearDataTagFilter();
    super.dispose();
  }

  /// ✅ Watchdog timer: Detects frozen data and reconnects
  void _startWatchdogTimer() {
    _lastDataReceivedTimestamp = DateTime.now().millisecondsSinceEpoch;
    
    _watchdogTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final timeSinceLastData = now - _lastDataReceivedTimestamp;
      
      if (timeSinceLastData > _watchdogTimeoutMs) {
        debugPrint('⚠️ WATCHDOG: No data for ${timeSinceLastData}ms - reconnecting...');
        _reconnectBluetooth();
      }
    });
  }

  /// ✅ Reconnect Bluetooth when data stream is frozen
  Future<void> _reconnectBluetooth() async {
    if (_isReconnecting) return; // Prevent multiple reconnections
    
    setState(() => _isReconnecting = true);
    debugPrint('🔄 Reconnecting Bluetooth...');
    
    // Reset timestamp to prevent immediate reconnection loop
    _lastDataReceivedTimestamp = DateTime.now().millisecondsSinceEpoch;
    
    try {
      // Cancel existing subscriptions
      await _dataSubscription?.cancel();
      await _debugSubscription?.cancel();
      
      // Stop monitoring
      await B24BluetoothService.instance.stopBroadcastMonitoring();
      
      // Wait a bit
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Reconnect
      await _connectBluetooth();
      
      debugPrint('✅ Reconnection complete');
    } finally {
      setState(() => _isReconnecting = false);
    }
  }

  Widget _buildStatusIndicators(DeviceStatus status) {
    final bool integrityError = status.integrityError;
    final bool notGross = !status.isTared;
    final bool overRange = status.overRange;
    final bool fastMode = status.fastMode;
    final bool batteryLow = status.batteryLow;
    final bool digitalInput = status.digitalInput;

    final hasCriticalErrors = integrityError || overRange || batteryLow;

    return Card(
      color: const Color(0xFF1F2937),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'STATUS',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!hasCriticalErrors) _buildStaticIndicator('Status OK', const Color(0xFF10B981)),
                if (integrityError) _buildBlinkingIndicator('Sensor integrity error', const Color(0xFFEF4444)),
                if (overRange) _buildBlinkingIndicator('OverRange', const Color(0xFFEF4444)),
                if (batteryLow) _buildBlinkingIndicator('Battery Low', const Color(0xFFEF4444)),
                if (notGross) _buildStaticIndicator('Not Gross', const Color(0xFFEAB308)),
                if (fastMode) _buildStaticIndicator('Fast Mode', const Color(0xFFEAB308)),
                if (digitalInput) _buildStaticIndicator('Digital Input', const Color(0xFFEAB308)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlinkingIndicator(String label, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              border: Border.all(color: color.withOpacity(value), width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

  Widget _buildStaticIndicator(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ✅ Calculate displayed torque (either instant or averaged)
  double get _displayedTorque {
    if (!_useAveraging || _torqueBuffer.isEmpty) {
      return _currentData.torque;
    }
    
    // Calculate average of buffer
    final sum = _torqueBuffer.reduce((a, b) => a + b);
    return sum / _torqueBuffer.length;
  }
}