import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/repository/measurement_repository.dart';

// ویجت ما حالا stateful است و یک ریپازیتوری به عنوان ورودی می‌گیرد
class HomePage extends StatefulWidget {
  final MeasurementRepository repository;

  const HomePage({Key? key, required this.repository}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // --- وضعیت سیستم ---
  String _connectionStatus = "Ready to Scan";
  bool _isScanning = false;
  StreamSubscription? _scanSubscription;

  // --- داده‌های زنده ---
  double _liveValue = 0.0;
  int _unitByte = -1;
  String _detectedUnitName = "Waiting...";

  // --- کلیدهای رمزگشایی (مشابه کد شما) ---
  final List<int> _seed = [0x5C, 0x6F, 0x2F, 0x41, 0x21, 0x7A, 0x26, 0x45, 0x5C, 0x6F];
  final List<int> _pinBytes = [0x30, 0x30, 0x30, 0x30]; // PIN 0000
  final int _tag1 = 0x4D;
  final int _tag2 = 0x80;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
  }

  void _toggleScan() {
    if (_isScanning) {
      FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
      setState(() {
        _isScanning = false;
        _connectionStatus = "Scan Stopped";
      });
    } else {
      setState(() {
        _isScanning = true;
        _connectionStatus = "Scanning for B24...";
        _liveValue = 0.0; // ریست کردن مقدار با هر اسکن جدید
        _unitByte = -1;
        _detectedUnitName = "Waiting...";
      });
      
      FlutterBluePlus.startScan(continuousUpdates: true);
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          r.advertisementData.manufacturerData.forEach((mId, bytes) {
            _decodePacket(bytes);
          });
        }
      });
    }
  }

  void _decodePacket(List<int> packet) {
    for (int i = 0; i < packet.length - 1; i++) {
      if (packet[i] == _tag1 && packet[i+1] == _tag2) {
        int dataStart = i + 2;
        if (dataStart + 6 <= packet.length) {
          List<int> decoded = [];
          for (int j = 0; j < 6; j++) {
            int enc = packet[dataStart + j];
            int key = _seed[j] ^ _pinBytes[j % 4];
            decoded.add(enc ^ key);
          }

          int uByte = decoded[1];
          Uint8List fBytes = Uint8List.fromList(decoded.sublist(2, 6));
          double val = ByteData.sublistView(fBytes).getFloat32(0, Endian.big);

          // به روز رسانی UI و ارسال داده به ریپازیتوری
          _updateUIAndForwardData(val, uByte);
          return;
        }
      }
    }
  }

  void _updateUIAndForwardData(double val, int uByte) {
    // === اتصال جادویی به لایه دیتا ===
    // هر داده جدیدی که می‌آید، به ریپازیتوری ارسال می‌شود.
    // ریپازیتوری خودش چک می‌کند که اگر در حالت ضبط بود، آن را ذخیره کند.
    widget.repository.onNewDataReceived(val);
    // ===================================

    String uName = "Unknown (0x${uByte.toRadixString(16).toUpperCase()})";
    if (uByte == 0x00) uName = "RATIO (mV/V)";
    else if (uByte == 0x01) uName = "mV/V (Legacy)";
    else if (uByte == 0x2D) uName = "Mass (kg)";
    else if (uByte == 0x41) uName = "Force (Newton)";
    else if (uByte == 0x96) uName = "Torque (Nm)";

    // فقط اگر در صفحه هستیم UI را آپدیت کن
    if (mounted) {
      setState(() {
        _liveValue = val;
        _unitByte = uByte;
        _detectedUnitName = uName;
        _connectionStatus = "Data Receiving";
      });
    }
  }
  
  // --- توابع جدید برای کنترل ضبط ---
  
  Future<void> _startRecording() async {
    final projectName = await _showProjectNameDialog();
    if (projectName != null && projectName.isNotEmpty) {
      await widget.repository.startNewProject(projectName);
      setState(() {}); // برای آپدیت UI و نمایش وضعیت ضبط
    }
  }

  Future<void> _stopRecording() async {
    await widget.repository.stopRecording();
    setState(() {}); // برای آپدیت UI و نمایش وضعیت ضبط
  }

  Future<String?> _showProjectNameDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Project"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Enter project name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text("Start"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // وضعیت ضبط را مستقیماً از ریپازیتوری می‌خوانیم
    final bool isRecording = widget.repository.isRecording;

    return Scaffold(
      appBar: AppBar(
        title: const Text("B24 Monitor"),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              // TODO: به صفحه لیست پروژه‌ها برویم
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- بخش نمایشگر اصلی ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: isRecording ? Colors.red : Colors.green, width: 2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  if (isRecording)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.circle, color: Colors.red, size: 12),
                          SizedBox(width: 8),
                          Text("RECORDING", style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  Text(
                    _liveValue.toStringAsFixed(5),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _detectedUnitName,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                                    const SizedBox(height: 5),
                  Text(
                    "HEX: 0x${_unitByte != -1 ? _unitByte.toRadixString(16).toUpperCase().padLeft(2, '0') : '--'}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- بخش کنترل ضبط ---
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    isRecording ? "Project ID: ${widget.repository.currentProjectId?.substring(0, 8)}..." : "Not Recording",
                    style: TextStyle(color: isRecording ? Colors.yellowAccent : Colors.grey, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isScanning ? (isRecording ? _stopRecording : _startRecording) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRecording ? Colors.redAccent : Colors.green,
                        disabledBackgroundColor: Colors.grey.shade700,
                      ),
                      child: Text(isRecording ? "STOP RECORDING" : "START RECORDING"),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),

            // --- دکمه اسکن ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _toggleScan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isScanning ? Colors.orange : Colors.blueAccent,
                ),
                child: Text(_isScanning ? "STOP SCAN" : "START SCAN"),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_connectionStatus, style: const TextStyle(color: Colors.grey)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
