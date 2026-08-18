import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noa/device/brilliant/brilliant_wearable_gateway.dart';
import 'package:noa/device/device_mode.dart';
import 'package:noa/device/device_providers.dart';

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

  test('explicit simulator mode fails instead of falling back to hardware', () {
    final container = ProviderContainer(
      overrides: [
        deviceModeProvider.overrideWithValue(DeviceMode.simulator),
      ],
    );

    expect(
      () => container.read(wearableGatewayProvider),
      throwsA(
        isA<UnsupportedError>().having(
          (error) => error.message,
          'message',
          contains('Phase 2D'),
        ),
      ),
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
