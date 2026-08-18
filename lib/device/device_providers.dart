import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'brilliant/brilliant_wearable_gateway.dart';
import 'device_mode.dart';
import 'simulator/simulated_wearable_gateway.dart';
import 'wearable_gateway.dart';

final deviceModeProvider = Provider<DeviceMode>((ref) => DeviceMode.current);

const hardwarePairedDevicePreferenceKey = 'PairedDevice';
const simulatedPairedDevicePreferenceKey = 'SimulatedPairedDevice';

final pairedDevicePreferenceKeyProvider = Provider<String>((ref) {
  switch (ref.watch(deviceModeProvider)) {
    case DeviceMode.hardware:
      return hardwarePairedDevicePreferenceKey;
    case DeviceMode.simulator:
      return simulatedPairedDevicePreferenceKey;
  }
});

final wearableGatewayProvider = Provider<WearableGateway>((ref) {
  switch (ref.watch(deviceModeProvider)) {
    case DeviceMode.hardware:
      final gateway = BrilliantWearableGateway();
      ref.onDispose(gateway.dispose);
      return gateway;
    case DeviceMode.simulator:
      final gateway = SimulatedWearableGateway();
      ref.onDispose(gateway.dispose);
      return gateway;
  }
});
