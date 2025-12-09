export interface DeviceStatus {
  statusByte: number;
  integrityError: boolean;
  overRange: boolean;
  isTared: boolean;
  fastMode: boolean;
  batteryLow: boolean;
  hasCriticalError: boolean;
  hasWarning: boolean;
  summary: string;
}

export function parseDeviceStatus(statusByte: number): DeviceStatus {
  const integrityError = (statusByte & 0x02) !== 0;
  const overRange = (statusByte & 0x04) !== 0;
  const isTared = (statusByte & 0x08) !== 0;
  const fastMode = (statusByte & 0x10) !== 0;
  const batteryLow = (statusByte & 0x20) !== 0;

  const hasCriticalError = integrityError || overRange;
  const hasWarning = batteryLow;

  let summary = '';
  if (integrityError) {
    summary = '⚠️ خطای سنسور - داده قابل اعتماد نیست';
  } else if (overRange) {
    summary = '⚠️ خارج از محدوده';
  } else if (batteryLow) {
    summary = '🔋 باتری کم';
  } else {
    const parts: string[] = [];
    if (isTared) parts.push('Net (Tare)');
    if (fastMode) parts.push('Fast Mode');
    summary = parts.length > 0 ? parts.join(' + ') : '✅ عادی';
  }

  return {
    statusByte,
    integrityError,
    overRange,
    isTared,
    fastMode,
    batteryLow,
    hasCriticalError,
    hasWarning,
    summary,
  };
}
