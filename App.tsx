import React, { useState } from 'react';
import MonitoringPage from './components/MonitoringPage';
import './styles/globals.css';

function App() {
  const [selectedScenario, setSelectedScenario] = useState('normal');

  const scenarios = [
    { id: 'normal', label: '✅ حالت عادی - همه OK', statusByte: 0x00 },
    { id: 'battery_low', label: '🔋 باتری کم', statusByte: 0x20 },
    { id: 'sensor_error', label: '⚠️ خطای سنسور', statusByte: 0x02 },
    { id: 'over_range', label: '📊 خارج از محدوده', statusByte: 0x04 },
    { id: 'tare_active', label: '🔧 Tare فعال (Net Mode)', statusByte: 0x08 },
    { id: 'fast_mode', label: '⚡ Fast Mode', statusByte: 0x10 },
    { id: 'battery_sensor', label: '🔴 باتری کم + خطای سنسور', statusByte: 0x22 },
    { id: 'all_errors', label: '🔴 همه خطاها', statusByte: 0x3F },
    { id: 'range_battery', label: '⚠️ Over Range + Battery Low', statusByte: 0x24 },
    { id: 'tare_fast', label: '🎯 Tare + Fast Mode', statusByte: 0x18 },
  ];

  const currentScenario = scenarios.find(s => s.id === selectedScenario) || scenarios[0];

  return (
    <div className="min-h-screen bg-gray-950 text-white">
      {/* Header */}
      <div className="bg-gradient-to-r from-blue-900 to-blue-800 border-b border-blue-700 p-4 sticky top-0 z-50">
        <div className="max-w-7xl mx-auto">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h1 className="text-2xl mb-1">🧪 نمایش Status Indicators در صفحه Monitoring</h1>
              <p className="text-sm text-blue-200">نسخه Demo - مشاهده همه حالات نشانگرها</p>
            </div>
            <div className="text-right">
              <div className="text-xs text-blue-200">Status Byte</div>
              <div className="text-lg font-mono bg-blue-950 px-3 py-1 rounded">
                0x{currentScenario.statusByte.toString(16).toUpperCase().padStart(2, '0')}
              </div>
            </div>
          </div>
          
          {/* Scenario Selector */}
          <div className="flex gap-2 overflow-x-auto pb-2">
            {scenarios.map(scenario => (
              <button
                key={scenario.id}
                onClick={() => setSelectedScenario(scenario.id)}
                className={`px-4 py-2 rounded-lg whitespace-nowrap transition-all ${
                  selectedScenario === scenario.id
                    ? 'bg-blue-600 text-white shadow-lg scale-105'
                    : 'bg-blue-950 hover:bg-blue-900 text-blue-200'
                }`}
              >
                {scenario.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Monitoring Page Preview */}
      <MonitoringPage statusByte={currentScenario.statusByte} />
    </div>
  );
}

export default App;
