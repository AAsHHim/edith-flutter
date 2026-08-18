import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noa/device/brilliant/brilliant_wearable_gateway.dart';
import 'package:noa/device/device_mode.dart';
import 'package:noa/device/device_providers.dart';
import 'package:noa/device/simulator/simulated_wearable_gateway.dart';

void main() {
  test('hardware mode composes the Brilliant gateway', () {
    final container = ProviderContainer(
      overrides: [
        deviceModeProvider.overrideWithValue(DeviceMode.hardware),
      ],
    );

    expect(
      container.read(wearableGatewayProvider),
      isA<BrilliantWearableGateway>(),
    );
  });

  test('simulator mode composes the simulated wearable gateway', () async {
    final container = ProviderContainer(
      overrides: [
        deviceModeProvider.overrideWithValue(DeviceMode.simulator),
      ],
    );

    final gateway = container.read(wearableGatewayProvider);

    expect(gateway, isA<SimulatedWearableGateway>());
    await gateway.dispose();
  });

  test('default composition remains hardware', () {
    final container = ProviderContainer();

    expect(
      container.read(wearableGatewayProvider),
      isA<BrilliantWearableGateway>(),
    );
  });

  test('hardware mode selects the backward-compatible pairing key', () {
    final container = ProviderContainer(
      overrides: [
        deviceModeProvider.overrideWithValue(DeviceMode.hardware),
      ],
    );

    expect(
      container.read(pairedDevicePreferenceKeyProvider),
      'PairedDevice',
    );
  });

  test('simulator mode selects an isolated pairing key', () {
    final container = ProviderContainer(
      overrides: [
        deviceModeProvider.overrideWithValue(DeviceMode.simulator),
      ],
    );

    expect(
      container.read(pairedDevicePreferenceKeyProvider),
      'SimulatedPairedDevice',
    );
  });
}
