import React, { useState, useEffect } from 'react';
import DeviceStatusIndicators from './DeviceStatusIndicators';
import LiveStatusIndicator from './LiveStatusIndicator';
import { parseDeviceStatus } from '../utils/deviceStatus';
import { Activity, Database, Save, AlertTriangle } from 'lucide-react';

interface MonitoringPageProps {
  statusByte: number;
}

const MonitoringPage: React.FC<MonitoringPageProps> = ({ statusByte }) => {
  const [torqueValue, setTorqueValue] = useState(45.7);
  const [isRecording, setIsRecording] = useState(false);
  const [recordCount, setRecordCount] = useState(0);
  const [mockData, setMockData] = useState<Array<{ time: string; torque: number; status: string }>>([]);

  const deviceStatus = parseDeviceStatus(statusByte);
  const threshold = 100;

  // Simulate torque changes
  useEffect(() => {
    const interval = setInterval(() => {
      // Simulate torque fluctuations
      const newTorque = 45 + Math.random() * 60;
      setTorqueValue(newTorque);

      // Auto-recording simulation
      if (Math.abs(newTorque) > threshold && !isRecording) {
        setIsRecording(true);
      } else if (Math.abs(newTorque) <= threshold && isRecording) {
        setIsRecording(false);
      }

      // Add mock records when recording
      if (Math.abs(newTorque) > threshold) {
        setRecordCount(prev => prev + 1);
        if (mockData.length < 10) {
          setMockData(prev => [{
            time: new Date().toLocaleTimeString('fa-IR'),
            torque: newTorque,
            status: deviceStatus.summary
          }, ...prev]);
        }
      }
    }, 1500);

    return () => clearInterval(interval);
  }, [isRecording, mockData.length, threshold, deviceStatus.summary]);

  return (
    <div className="max-w-7xl mx-auto p-4 space-y-4">
      {/* Main Monitoring Card */}
      <div className="bg-gray-900 rounded-lg border border-gray-800 p-6">
        <div className="flex items-center gap-3 mb-6">
          <Activity className="w-6 h-6 text-blue-400" />
          <h2 className="text-xl">مانیتورینگ زنده - شمع A-001</h2>
        </div>

        {/* Live Status Indicator - Prominent Position */}
        <div className="mb-6">
          <LiveStatusIndicator status={deviceStatus} />
        </div>

        {/* Torque Display */}
        <div className="grid md:grid-cols-2 gap-6 mb-6">
          {/* Large Torque Value */}
          <div className="bg-gradient-to-br from-blue-900 to-blue-950 rounded-lg p-6 border border-blue-800">
            <div className="text-sm text-blue-300 mb-2">گشتاور فعلی</div>
            <div className="text-5xl font-mono mb-2">
              {torqueValue.toFixed(1)}
              <span className="text-2xl text-blue-400 ml-2">Nm</span>
            </div>
            <div className="text-xs text-blue-300">
              Threshold: {threshold} Nm
            </div>
          </div>

          {/* Recording Status */}
          <div className={`rounded-lg p-6 border ${
            isRecording 
              ? 'bg-gradient-to-br from-red-900 to-red-950 border-red-800' 
              : 'bg-gray-800 border-gray-700'
          }`}>
            <div className="flex items-center gap-2 mb-3">
              {isRecording && (
                <div className="w-3 h-3 bg-red-500 rounded-full animate-pulse" />
              )}
              <div className="text-sm text-gray-300">
                {isRecording ? '🔴 در حال ضبط...' : '⏸️ آماده ضبط'}
              </div>
            </div>
            <div className="text-3xl font-mono mb-2">
              {recordCount}
            </div>
            <div className="text-xs text-gray-400">
              تعداد رکوردهای ثبت شده
            </div>
          </div>
        </div>

        {/* Full Status Indicators */}
        <div className="mb-6">
          <DeviceStatusIndicators status={deviceStatus} compact={false} />
        </div>

        {/* Action Buttons */}
        <div className="flex gap-3">
          <button className="flex-1 bg-green-600 hover:bg-green-700 text-white px-4 py-3 rounded-lg flex items-center justify-center gap-2 transition-colors">
            <Save className="w-5 h-5" />
            ذخیره دستی
          </button>
          <button className="flex-1 bg-gray-700 hover:bg-gray-600 text-white px-4 py-3 rounded-lg flex items-center justify-center gap-2 transition-colors">
            <Database className="w-5 h-5" />
            مشاهده داده‌ها
          </button>
        </div>
      </div>

      {/* Compact View Example */}
      <div className="bg-gray-900 rounded-lg border border-gray-800 p-4">
        <div className="flex items-center justify-between">
          <div className="text-sm text-gray-400">نمایش فشرده (Compact View):</div>
          <DeviceStatusIndicators status={deviceStatus} compact={true} />
        </div>
      </div>

      {/* Recent Data Table with Status */}
      <div className="bg-gray-900 rounded-lg border border-gray-800 p-6">
        <div className="flex items-center gap-3 mb-4">
          <Database className="w-5 h-5 text-blue-400" />
          <h3 className="text-lg">داده‌های اخیر (با وضعیت دستگاه)</h3>
        </div>
        
        {mockData.length === 0 ? (
          <div className="text-center text-gray-500 py-8">
            <AlertTriangle className="w-12 h-12 mx-auto mb-2 opacity-50" />
            <p>منتظر شروع ضبط داده...</p>
            <p className="text-xs mt-1">گشتاور باید بالای {threshold} Nm باشد</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-800 text-gray-400 text-sm">
                  <th className="text-right py-2 px-3">زمان</th>
                  <th className="text-right py-2 px-3">گشتاور (Nm)</th>
                  <th className="text-right py-2 px-3">وضعیت دستگاه</th>
                  <th className="text-right py-2 px-3">Status Byte</th>
                </tr>
              </thead>
              <tbody>
                {mockData.map((record, idx) => (
                  <tr key={idx} className="border-b border-gray-800 hover:bg-gray-850">
                    <td className="py-3 px-3 font-mono text-sm">{record.time}</td>
                    <td className="py-3 px-3 font-mono">{record.torque.toFixed(1)}</td>
                    <td className="py-3 px-3 text-sm">{record.status}</td>
                    <td className="py-3 px-3">
                      <span className="font-mono text-xs bg-gray-800 px-2 py-1 rounded">
                        0x{statusByte.toString(16).toUpperCase().padStart(2, '0')}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Status Byte Details */}
      <div className="bg-gray-900 rounded-lg border border-gray-800 p-6">
        <h3 className="text-lg mb-4">📋 جزئیات Status Byte</h3>
        <div className="grid md:grid-cols-2 gap-4">
          <div className="space-y-2">
            <StatusDetail label="Integrity Error" value={deviceStatus.integrityError} />
            <StatusDetail label="Over Range" value={deviceStatus.overRange} />
            <StatusDetail label="Tare Active" value={deviceStatus.isTared} />
          </div>
          <div className="space-y-2">
            <StatusDetail label="Fast Mode" value={deviceStatus.fastMode} />
            <StatusDetail label="Battery Low" value={deviceStatus.batteryLow} />
            <StatusDetail label="Has Critical Error" value={deviceStatus.hasCriticalError} />
          </div>
        </div>
        <div className="mt-4 pt-4 border-t border-gray-800">
          <div className="flex items-center justify-between">
            <span className="text-sm text-gray-400">Binary Representation:</span>
            <span className="font-mono text-blue-400">
              {statusByte.toString(2).padStart(8, '0')}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
};

interface StatusDetailProps {
  label: string;
  value: boolean;
}

const StatusDetail: React.FC<StatusDetailProps> = ({ label, value }) => (
  <div className="flex items-center justify-between bg-gray-800 px-3 py-2 rounded">
    <span className="text-sm text-gray-300">{label}</span>
    <div className="flex items-center gap-2">
      <div className={`w-2 h-2 rounded-full ${value ? 'bg-green-500' : 'bg-gray-600'}`} />
      <span className={`text-xs font-semibold ${value ? 'text-green-400' : 'text-gray-500'}`}>
        {value ? 'YES' : 'NO'}
      </span>
    </div>
  </div>
);

export default MonitoringPage;
