import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _thresholdController = TextEditingController();
  double _currentThreshold = 100.0;
  bool _isLoading = true;

  // ✅ New settings for averaging
  bool _useAveraging = false;
  int _averageSampleCount = 5;
  
  // ✅ New setting for watchdog timeout
  int _watchdogTimeout = 6;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final threshold = prefs.getDouble('recording_threshold') ?? 100.0;
      final useAveraging = prefs.getBool('use_averaging') ?? false;
      final averageCount = prefs.getInt('average_sample_count') ?? 5;
      final watchdogTimeout = prefs.getInt('watchdog_timeout_seconds') ?? 6;
      
      setState(() {
        _currentThreshold = threshold;
        _thresholdController.text = threshold.toStringAsFixed(1);
        _useAveraging = useAveraging;
        _averageSampleCount = averageCount;
        _watchdogTimeout = watchdogTimeout;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    }
  }

  Future<void> _saveThreshold() async {
    final value = double.tryParse(_thresholdController.text);
    
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid threshold value (greater than 0)'),
          backgroundColor: Color(0xFFF87171),
        ),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('recording_threshold', value);
      
      setState(() => _currentThreshold = value);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording threshold saved successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Color(0xFFF87171),
          ),
        );
      }
    }
  }

  Future<void> _resetToDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Default'),
        content: const Text('Are you sure you want to reset recording threshold to 100 Nm?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('recording_threshold', 100.0);
        
        setState(() {
          _currentThreshold = 100.0;
          _thresholdController.text = '100.0';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reset to default value (100 Nm)'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error resetting: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.settings_suggest, color: Colors.blue[400]),
                              const SizedBox(width: 8),
                              const Text(
                                'Recording Settings',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Recording Threshold',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Set the minimum torque value (Nm) required to automatically start recording data. Works for both clockwise (+) and counter-clockwise (-) rotation directions.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _thresholdController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Threshold Value',
                              hintText: 'e.g., 100.0',
                              suffixText: 'Nm',
                              border: const OutlineInputBorder(),
                              helperText: 'Default: 100.0 Nm',
                              prefixIcon: const Icon(Icons.speed),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _saveThreshold,
                                  icon: const Icon(Icons.save),
                                  label: const Text('Save'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: _resetToDefault,
                                icon: const Icon(Icons.restore),
                                label: const Text('Reset'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6B7280),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: const Color(0xFF1E3A8A),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info, size: 20, color: Color(0xFF60A5FA)),
                              const SizedBox(width: 8),
                              const Text(
                                'Current Setting',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Recording Threshold:',
                                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                              ),
                              Text(
                                '${_currentThreshold.toStringAsFixed(1)} Nm',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(color: Color(0xFF374151)),
                          const SizedBox(height: 8),
                          const Text(
                            'When torque exceeds this value, the system will automatically start recording data. Recording will pause when torque drops below this threshold.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // ✅ NEW: Display Averaging Settings
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_graph, color: Colors.purple[400]),
                              const SizedBox(width: 8),
                              const Text(
                                'Display Settings',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Use Averaging',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Display average of recent measurements instead of instant values',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _useAveraging,
                                onChanged: (value) async {
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setBool('use_averaging', value);
                                  setState(() => _useAveraging = value);
                                  
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(_useAveraging 
                                          ? 'Averaging enabled' 
                                          : 'Averaging disabled'),
                                        backgroundColor: const Color(0xFF10B981),
                                      ),
                                    );
                                  }
                                },
                                activeColor: const Color(0xFF10B981),
                              ),
                            ],
                          ),
                          if (_useAveraging) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                            const Text(
                              'Number of Samples for Average',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: _averageSampleCount.toDouble(),
                                    min: 2,
                                    max: 20,
                                    divisions: 18,
                                    label: '$_averageSampleCount samples',
                                    onChanged: (value) {
                                      setState(() => _averageSampleCount = value.toInt());
                                    },
                                    onChangeEnd: (value) async {
                                      final prefs = await SharedPreferences.getInstance();
                                      await prefs.setInt('average_sample_count', value.toInt());
                                      
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Average sample count set to ${value.toInt()}'),
                                            backgroundColor: const Color(0xFF10B981),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$_averageSampleCount',
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Averaging will use the last $_averageSampleCount measurements',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  // ✅ NEW: Watchdog Timeout Settings
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.sync, color: Colors.orange[400]),
                              const SizedBox(width: 8),
                              const Text(
                                'Connection Settings',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Auto-Reconnect Timeout',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Time to wait before auto-reconnecting when no data is received (prevents frozen display)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Slider(
                                  value: _watchdogTimeout.toDouble(),
                                  min: 3,
                                  max: 15,
                                  divisions: 12,
                                  label: '$_watchdogTimeout seconds',
                                  onChanged: (value) {
                                    setState(() => _watchdogTimeout = value.toInt());
                                  },
                                  onChangeEnd: (value) async {
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setInt('watchdog_timeout_seconds', value.toInt());
                                    
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Auto-reconnect timeout set to ${value.toInt()} seconds'),
                                          backgroundColor: const Color(0xFF10B981),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_watchdogTimeout}s',
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Recommended: 6 seconds (Current: $_watchdogTimeout seconds)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
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

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }
}