import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'brilliant/brilliant_wearable_gateway.dart';
import 'device_mode.dart';
import 'simulator/halo_simulator_controller.dart';
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

final haloSimulatorControllerProvider =
    Provider<HaloSimulatorController>((ref) {
  if (ref.watch(deviceModeProvider) != DeviceMode.simulator) {
    throw StateError('The Halo simulator controller requires simulator mode.');
  }
  final controller = HaloSimulatorController();
  ref.onDispose(controller.dispose);
  return controller;
});

final wearableGatewayProvider = Provider<WearableGateway>((ref) {
  switch (ref.watch(deviceModeProvider)) {
    case DeviceMode.hardware:
      final gateway = BrilliantWearableGateway();
      ref.onDispose(gateway.dispose);
      return gateway;
    case DeviceMode.simulator:
      final gateway = SimulatedWearableGateway(
        controller: ref.watch(haloSimulatorControllerProvider),
      );
      ref.onDispose(gateway.dispose);
      return gateway;
  }
});

final simulatorUiEnabledProvider = Provider<bool>(
  (ref) => ref.watch(deviceModeProvider) == DeviceMode.simulator,
);
