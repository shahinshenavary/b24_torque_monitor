import React from 'react';
import { DeviceStatus } from '../utils/deviceStatus';
import { Wifi, Battery, AlertTriangle, Activity, Scale, Zap, CheckCircle } from 'lucide-react';

interface DeviceStatusIndicatorsProps {
  status: DeviceStatus;
  compact?: boolean;
}

const DeviceStatusIndicators: React.FC<DeviceStatusIndicatorsProps> = ({ 
  status, 
  compact = false 
}) => {
  if (compact) {
    return <CompactView status={status} />;
  }
  return <FullView status={status} />;
};

const FullView: React.FC<{ status: DeviceStatus }> = ({ status }) => {
  return (
    <div className="bg-gray-800 rounded-lg p-4 border border-gray-700">
      <div className="flex items-center gap-2 mb-4">
        <Activity className="w-5 h-5 text-blue-400" />
        <h3 className="font-semibold">وضعیت دستگاه</h3>
      </div>
      
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-3">
        <Indicator
          icon={<Wifi className="w-5 h-5" />}
          label="سلامت سنسور"
          isError={status.integrityError}
          isOk={!status.integrityError}
        />
        <Indicator
          icon={<Battery className="w-5 h-5" />}
          label="باتری"
          isWarning={status.batteryLow}
          isOk={!status.batteryLow}
        />
        <Indicator
          icon={<AlertTriangle className="w-5 h-5" />}
          label="محدوده"
          isError={status.overRange}
          isOk={!status.overRange}
        />
        <Indicator
          icon={<Scale className="w-5 h-5" />}
          label={status.isTared ? 'Net (Tare)' : 'Gross'}
          isInfo={true}
        />
        <Indicator
          icon={<Zap className="w-5 h-5" />}
          label={status.fastMode ? 'Fast Mode' : 'Normal'}
          isInfo={true}
        />
      </div>
    </div>
  );
};

const CompactView: React.FC<{ status: DeviceStatus }> = ({ status }) => {
  return (
    <div className="flex items-center gap-2">
      {status.integrityError && (
        <CompactIndicator
          icon={<AlertTriangle className="w-4 h-4" />}
          color="red"
          tooltip="خطای سنسور"
        />
      )}
      {status.overRange && (
        <CompactIndicator
          icon={<AlertTriangle className="w-4 h-4" />}
          color="red"
          tooltip="خارج از محدوده"
        />
      )}
      {status.batteryLow && (
        <CompactIndicator
          icon={<Battery className="w-4 h-4" />}
          color="orange"
          tooltip="باتری کم"
        />
      )}
      {!status.hasCriticalError && !status.hasWarning && (
        <CompactIndicator
          icon={<CheckCircle className="w-4 h-4" />}
          color="green"
          tooltip="عادی"
        />
      )}
    </div>
  );
};

interface IndicatorProps {
  icon: React.ReactNode;
  label: string;
  isError?: boolean;
  isWarning?: boolean;
  isOk?: boolean;
  isInfo?: boolean;
}

const Indicator: React.FC<IndicatorProps> = ({
  icon,
  label,
  isError = false,
  isWarning = false,
  isOk = false,
  isInfo = false,
}) => {
  let colorClasses = '';
  
  if (isError) {
    colorClasses = 'bg-red-950/50 border-red-500/50 text-red-400';
  } else if (isWarning) {
    colorClasses = 'bg-orange-950/50 border-orange-500/50 text-orange-400';
  } else if (isOk) {
    colorClasses = 'bg-green-950/50 border-green-500/50 text-green-400';
  } else {
    colorClasses = 'bg-blue-950/50 border-blue-500/50 text-blue-400';
  }

  return (
    <div className={`flex items-center gap-2 px-3 py-2 rounded-lg border ${colorClasses}`}>
      {icon}
      <span className="text-sm font-medium whitespace-nowrap">{label}</span>
    </div>
  );
};

interface CompactIndicatorProps {
  icon: React.ReactNode;
  color: 'red' | 'orange' | 'green';
  tooltip: string;
}

const CompactIndicator: React.FC<CompactIndicatorProps> = ({ icon, color, tooltip }) => {
  const colorClasses = {
    red: 'bg-red-950/30 border-red-500 text-red-400',
    orange: 'bg-orange-950/30 border-orange-500 text-orange-400',
    green: 'bg-green-950/30 border-green-500 text-green-400',
  };

  return (
    <div 
      className={`p-2 rounded-full border-2 ${colorClasses[color]}`}
      title={tooltip}
    >
      {icon}
    </div>
  );
};

export default DeviceStatusIndicators;
