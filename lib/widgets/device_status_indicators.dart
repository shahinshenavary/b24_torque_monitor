import 'package:flutter/material.dart';
import '../models/device_status.dart';

/// Widget to display device status indicators with visual alerts
class DeviceStatusIndicators extends StatelessWidget {
  final DeviceStatus status;
  final bool compact;

  const DeviceStatusIndicators({
    Key? key,
    required this.status,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactView(context);
    }
    return _buildFullView(context);
  }

  Widget _buildFullView(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'وضعیت دستگاه',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildIndicator(
                  icon: Icons.sensors,
                  label: 'سلامت سنسور',
                  isError: status.integrityError,
                  isOk: !status.integrityError,
                ),
                _buildIndicator(
                  icon: Icons.battery_alert,
                  label: 'باتری',
                  isWarning: status.batteryLow,
                  isOk: !status.batteryLow,
                ),
                _buildIndicator(
                  icon: Icons.analytics,
                  label: 'محدوده',
                  isError: status.overRange,
                  isOk: !status.overRange,
                ),
                _buildIndicator(
                  icon: Icons.scale,
                  label: status.isTared ? 'Net (Tare)' : 'Gross',
                  isInfo: true,
                ),
                _buildIndicator(
                  icon: Icons.speed,
                  label: status.fastMode ? 'Fast Mode' : 'Normal',
                  isInfo: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactView(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status.integrityError)
          _buildCompactIndicator(Icons.error, Colors.red, 'خطای سنسور'),
        if (status.overRange)
          _buildCompactIndicator(Icons.warning, Colors.red, 'خارج از محدوده'),
        if (status.batteryLow)
          _buildCompactIndicator(Icons.battery_alert, Colors.orange, 'باتری کم'),
        if (!status.hasCriticalError && !status.hasWarning)
          _buildCompactIndicator(Icons.check_circle, Colors.green, 'عادی'),
      ],
    );
  }

  Widget _buildIndicator({
    required IconData icon,
    required String label,
    bool isError = false,
    bool isWarning = false,
    bool isOk = false,
    bool isInfo = false,
  }) {
    Color color;
    Color bgColor;

    if (isError) {
      color = Colors.red;
      bgColor = Colors.red.shade50;
    } else if (isWarning) {
      color = Colors.orange;
      bgColor = Colors.orange.shade50;
    } else if (isOk) {
      color = Colors.green;
      bgColor = Colors.green.shade50;
    } else {
      color = Colors.blue;
      bgColor = Colors.blue.shade50;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactIndicator(IconData icon, Color color, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: EdgeInsets.only(right: 8),
        padding: EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

/// Live status indicator with blinking animation for critical errors
class LiveStatusIndicator extends StatefulWidget {
  final DeviceStatus status;

  const LiveStatusIndicator({Key? key, required this.status}) : super(key: key);

  @override
  State<LiveStatusIndicator> createState() => _LiveStatusIndicatorState();
}

class _LiveStatusIndicatorState extends State<LiveStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    if (widget.status.hasCriticalError) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(LiveStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status.hasCriticalError) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String text;

    if (widget.status.integrityError) {
      color = Colors.red;
      icon = Icons.error;
      text = '⚠️ خطای سنسور';
    } else if (widget.status.overRange) {
      color = Colors.red;
      icon = Icons.warning;
      text = '⚠️ خارج از محدوده';
    } else if (widget.status.batteryLow) {
      color = Colors.orange;
      icon = Icons.battery_alert;
      text = '🔋 باتری کم';
    } else {
      color = Colors.green;
      icon = Icons.check_circle;
      text = '✅ عادی';
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1 + (_controller.value * 0.2)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3 + (_controller.value * 0.4)),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              SizedBox(width: 12),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}