import 'package:flutter/material.dart';
import '../models/device_status.dart';
import '../widgets/device_status_indicators.dart';

/// Test page to showcase all device status indicators
class DeviceStatusTestPage extends StatefulWidget {
  const DeviceStatusTestPage({Key? key}) : super(key: key);

  @override
  State<DeviceStatusTestPage> createState() => _DeviceStatusTestPageState();
}

class _DeviceStatusTestPageState extends State<DeviceStatusTestPage> {
  int _selectedStatusByte = 0x00; // Default: All OK

  // Predefined test scenarios
  final Map<String, int> _testScenarios = {
    '✅ حالت عادی (همه چیز OK)': 0x00,
    '🔋 باتری کم': 0x20,
    '⚠️ خطای سنسور': 0x02,
    '⚠️ خارج از محدوده': 0x04,
    '🔧 Tare فعال': 0x08,
    '⚡ Fast Mode فعال': 0x10,
    '🔴 باتری کم + خطای سنسور': 0x22,
    '🔴 همه خطاها': 0x3F,
    '📊 Over Range + Battery Low': 0x24,
    '🎯 Tare + Fast Mode': 0x18,
  };

  @override
  Widget build(BuildContext context) {
    final currentStatus = DeviceStatus.fromByte(_selectedStatusByte);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 آزمایش نشانگرهای وضعیت'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Info
            Card(
              color: const Color(0xFF1E3A8A),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 صفحه آزمایش Status Indicators',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status Byte: 0x${_selectedStatusByte.toRadixString(16).toUpperCase().padLeft(2, '0')} (${_selectedStatusByte})',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9CA3AF),
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Binary: ${_selectedStatusByte.toRadixString(2).padLeft(8, '0')}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9CA3AF),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Live Status Indicator (with animation)
            const Text(
              '1️⃣ Live Status Indicator (با انیمیشن)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Center(child: LiveStatusIndicator(status: currentStatus)),
            const SizedBox(height: 24),

            // Full View
            const Text(
              '2️⃣ Full View (نمایش کامل)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DeviceStatusIndicators(
              status: currentStatus,
              compact: false,
            ),
            const SizedBox(height: 24),

            // Compact View
            const Text(
              '3️⃣ Compact View (نمایش فشرده)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: DeviceStatusIndicators(
                    status: currentStatus,
                    compact: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Status Details
            const Text(
              '4️⃣ جزئیات Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusDetail('Integrity Error', currentStatus.integrityError),
                    _buildStatusDetail('Over Range', currentStatus.overRange),
                    _buildStatusDetail('Tare Active', currentStatus.isTared),
                    _buildStatusDetail('Fast Mode', currentStatus.fastMode),
                    _buildStatusDetail('Battery Low', currentStatus.batteryLow),
                    const Divider(),
                    _buildStatusDetail('Has Critical Error', currentStatus.hasCriticalError),
                    _buildStatusDetail('Has Warning', currentStatus.hasWarning),
                    const Divider(),
                    Text(
                      'Summary: ${currentStatus.summary}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Test Scenarios
            const Text(
              '5️⃣ سناریوهای آزمایشی',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._testScenarios.entries.map((entry) {
              final isSelected = _selectedStatusByte == entry.value;
              return Card(
                color: isSelected ? const Color(0xFF1E3A8A) : null,
                child: ListTile(
                  title: Text(entry.key),
                  subtitle: Text(
                    'Byte: 0x${entry.value.toRadixString(16).toUpperCase().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Color(0xFF10B981))
                      : const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    setState(() {
                      _selectedStatusByte = entry.value;
                    });
                  },
                ),
              );
            }).toList(),
            const SizedBox(height: 24),

            // Manual Input
            const Text(
              '6️⃣ ورودی دستی (0-255)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Status Byte (Decimal)',
                        hintText: 'e.g., 32 for Battery Low',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onSubmitted: (value) {
                        final byte = int.tryParse(value);
                        if (byte != null && byte >= 0 && byte <= 255) {
                          setState(() {
                            _selectedStatusByte = byte;
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('عدد باید بین 0 تا 255 باشد'),
                              backgroundColor: Color(0xFFF87171),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'نکته: می‌توانید عدد 0 تا 255 وارد کنید و Enter بزنید',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Bit Toggles
            const Text(
              '7️⃣ تنظیم Bit به Bit',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildBitToggle(
                      bit: 1,
                      label: 'Bit 1: Integrity Error',
                      description: 'خطای سنسور - داده قابل اعتماد نیست',
                    ),
                    _buildBitToggle(
                      bit: 2,
                      label: 'Bit 2: Over Range',
                      description: 'خارج از محدوده - مقدار بیش از حد',
                    ),
                    _buildBitToggle(
                      bit: 3,
                      label: 'Bit 3: Tare Active',
                      description: 'Net Mode - صفر تنظیم شده',
                    ),
                    _buildBitToggle(
                      bit: 4,
                      label: 'Bit 4: Fast Mode',
                      description: 'حالت سریع فعال',
                    ),
                    _buildBitToggle(
                      bit: 5,
                      label: 'Bit 5: Battery Low',
                      description: 'باتری کم - نیاز به شارژ',
                    ),
                    const Divider(),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedStatusByte = 0x00;
                        });
                      },
                      icon: const Icon(Icons.clear_all),
                      label: const Text('پاک کردن همه'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF87171),
                      ),
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

  Widget _buildStatusDetail(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Row(
            children: [
              Icon(
                value ? Icons.check_circle : Icons.cancel,
                color: value ? Colors.green : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                value ? 'YES' : 'NO',
                style: TextStyle(
                  color: value ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBitToggle({
    required int bit,
    required String label,
    required String description,
  }) {
    final bitMask = 1 << bit;
    final isSet = (_selectedStatusByte & bitMask) != 0;

    return Card(
      color: isSet ? const Color(0xFF1E3A8A) : null,
      child: SwitchListTile(
        title: Text(label),
        subtitle: Text(
          description,
          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
        value: isSet,
        onChanged: (value) {
          setState(() {
            if (value) {
              _selectedStatusByte |= bitMask;
            } else {
              _selectedStatusByte &= ~bitMask;
            }
          });
        },
      ),
    );
  }
}
