import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_mode.dart';
import 'wearable_gateway.dart';

final deviceModeProvider = Provider<DeviceMode>((ref) => DeviceMode.current);

/// Composition point for the active hardware or simulated wearable adapter.
///
/// Phase 2A intentionally does not provide an implementation. A later phase
/// must override this provider at the application composition root.
final wearableGatewayProvider = Provider<WearableGateway>((ref) {
  throw UnsupportedError('No WearableGateway implementation is configured.');
});
