import 'dart:async';
import 'package:flutter/material.dart';
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
  static const double RECORDING_THRESHOLD = 100.0;
  static const int RECORDING_INTERVAL_MS = 1000;

  TorqueData _currentData = TorqueData(
    torque: 0,
    force: 0,
    mass: 0,
    timestamp: DateTime.now().millisecondsSinceEpoch,
  );

  PileSession? _session;
  bool _isRecording = false;
  String _recordingStatus = 'idle'; // 'idle', 'recording', 'paused'
  int _recordCount = 0;
  double _currentDepth = 0;
  bool _isCompleted = false;
  bool _wasAboveThreshold = false;
  int _lastRecordTime = 0;
  
  StreamSubscription<TorqueData>? _dataSubscription;
  bool _isConnecting = false;
  String? _connectionError;

  @override
  void initState() {
    super.initState();
    _loadSession();
    _connectBluetooth();
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
      _dataSubscription = B24BluetoothService.instance.dataStream.listen((data) {
        setState(() => _currentData = data);
        _handleAutoRecording(data);
      });

      setState(() => _isConnecting = false);
    } catch (e) {
      setState(() {
        _connectionError = 'خطا در اتصال به دستگاه: $e';
        _isConnecting = false;
      });
    }
  }

  void _handleAutoRecording(TorqueData data) {
    if (_isCompleted) return;

    final isAboveThreshold = data.torque >= RECORDING_THRESHOLD;
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

    try {
      final completedSession = _session!.copyWith(
        status: 'completed',
        endTime: DateTime.now().millisecondsSinceEpoch,
      );
      
      await DatabaseHelper.instance.updatePileSession(completedSession);
      
      setState(() {
        _session = completedSession;
        _isCompleted = true;
        _isRecording = false;
        _recordingStatus = 'idle';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('شمع با موفقیت تکمیل شد'),
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
    final isAboveThreshold = _currentData.torque >= RECORDING_THRESHOLD;
    final depthPercent = (_currentDepth / widget.pile.expectedDepth * 100).clamp(0, 100);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.pile.pileId),
            Text(
              '${widget.project.name} - شماره ${widget.pile.pileNumber}',
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
                  Text('تکمیل شده', style: TextStyle(fontSize: 12)),
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
                        child: const Text('تلاش مجدد'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
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
                                          ? 'در حال ضبط خودکار'
                                          : _recordingStatus == 'paused'
                                              ? 'در حالت توقف'
                                              : 'آماده شروع',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _recordingStatus == 'recording'
                                          ? 'گشتاور بالای $RECORDING_THRESHOLD Nm - داده‌ها ذخیره می‌شوند'
                                          : _recordingStatus == 'paused'
                                              ? 'گشتاور زیر $RECORDING_THRESHOLD Nm - منتظر شروع دریل'
                                              : 'با عبور از $RECORDING_THRESHOLD Nm، ضبط خودکار شروع می‌شود',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  const Text('رکوردها', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
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
                                  const Text('گشتاور (Torque)', style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _currentData.torque.toStringAsFixed(1),
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
                                    'حد ضبط: $RECORDING_THRESHOLD',
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
                      Row(
                        children: [
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.flash_on, color: Colors.yellow[600], size: 20),
                                        const SizedBox(width: 4),
                                        const Text('نیرو', style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _currentData.force.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                    ),
                                    const Text('N', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.fitness_center, color: Colors.purple[400], size: 20),
                                        const SizedBox(width: 4),
                                        const Text('جرم', style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _currentData.mass.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                    ),
                                    const Text('kg', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.straighten, color: Colors.green[400]),
                                      const SizedBox(width: 8),
                                      const Text('عمق (Depth)', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  Text(
                                    '${_currentDepth.toStringAsFixed(1)} / ${widget.pile.expectedDepth} m',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: depthPercent / 100,
                                  minHeight: 8,
                                  backgroundColor: const Color(0xFF374151),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                                ),
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
                              const Text('مقادیر مورد انتظار', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('نوع شمع', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                      Text(widget.pile.pileType),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('شماره', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                      Text(widget.pile.pileNumber),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('گشتاور', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                      Text('${widget.pile.expectedTorque} Nm'),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('عمق', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
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
                            label: const Text('تکمیل و پایان کار'),
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
                                'شمع با موفقیت تکمیل شد',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$_recordCount رکورد ثبت شده - عمق نهایی: ${_currentDepth.toStringAsFixed(1)} متر',
                                style: const TextStyle(color: Color(0xFF9CA3AF)),
                              ),
                            ],
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
    super.dispose();
  }
}
