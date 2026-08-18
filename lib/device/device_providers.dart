import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'brilliant/brilliant_wearable_gateway.dart';
import 'device_mode.dart';
import 'wearable_gateway.dart';

final deviceModeProvider = Provider<DeviceMode>((ref) => DeviceMode.current);

final wearableGatewayProvider = Provider<WearableGateway>((ref) {
  switch (ref.watch(deviceModeProvider)) {
    case DeviceMode.hardware:
      final gateway = BrilliantWearableGateway();
      ref.onDispose(gateway.dispose);
      return gateway;
    case DeviceMode.simulator:
      throw UnsupportedError(
        'EDITH_DEVICE_MODE=simulator is not available until Phase 2D.',
      );
  }
});
