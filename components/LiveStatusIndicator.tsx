import React, { useEffect, useState } from 'react';
import { DeviceStatus } from '../utils/deviceStatus';
import { AlertTriangle, Battery, CheckCircle, AlertCircle } from 'lucide-react';

interface LiveStatusIndicatorProps {
  status: DeviceStatus;
}

const LiveStatusIndicator: React.FC<LiveStatusIndicatorProps> = ({ status }) => {
  const [blink, setBlink] = useState(false);

  // Blinking animation for critical errors
  useEffect(() => {
    if (status.hasCriticalError) {
      const interval = setInterval(() => {
        setBlink(prev => !prev);
      }, 600);
      return () => clearInterval(interval);
    } else {
      setBlink(false);
    }
  }, [status.hasCriticalError]);

  let config: {
    color: string;
    bgColor: string;
    icon: React.ReactNode;
    text: string;
    borderColor: string;
  };

  if (status.integrityError) {
    config = {
      color: 'text-red-400',
      bgColor: blink ? 'bg-red-900/60' : 'bg-red-900/30',
      borderColor: blink ? 'border-red-500' : 'border-red-500/50',
      icon: <AlertTriangle className="w-6 h-6" />,
      text: '⚠️ خطای سنسور',
    };
  } else if (status.overRange) {
    config = {
      color: 'text-red-400',
      bgColor: blink ? 'bg-red-900/60' : 'bg-red-900/30',
      borderColor: blink ? 'border-red-500' : 'border-red-500/50',
      icon: <AlertCircle className="w-6 h-6" />,
      text: '⚠️ خارج از محدوده',
    };
  } else if (status.batteryLow) {
    config = {
      color: 'text-orange-400',
      bgColor: 'bg-orange-900/30',
      borderColor: 'border-orange-500/50',
      icon: <Battery className="w-6 h-6" />,
      text: '🔋 باتری کم',
    };
  } else {
    config = {
      color: 'text-green-400',
      bgColor: 'bg-green-900/30',
      borderColor: 'border-green-500/50',
      icon: <CheckCircle className="w-6 h-6" />,
      text: '✅ عادی',
    };
  }

  return (
    <div 
      className={`
        ${config.bgColor} 
        ${config.borderColor} 
        ${config.color}
        border-2 rounded-xl p-4 
        transition-all duration-300
        ${status.hasCriticalError ? 'shadow-lg shadow-red-500/20' : ''}
      `}
    >
      <div className="flex items-center gap-4">
        <div className={`${status.hasCriticalError && blink ? 'scale-110' : 'scale-100'} transition-transform`}>
          {config.icon}
        </div>
        <div className="flex-1">
          <div className="text-lg font-bold">{config.text}</div>
          <div className="text-xs opacity-70 mt-1">{status.summary}</div>
        </div>
        {status.hasCriticalError && (
          <div className={`w-3 h-3 rounded-full ${blink ? 'bg-red-500' : 'bg-red-500/30'} transition-all`} />
        )}
      </div>
    </div>
  );
};

export default LiveStatusIndicator;
