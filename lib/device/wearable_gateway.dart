import 'wearable_models.dart';

enum WearableGatewayFailureKind {
  permission,
  discovery,
  connection,
  reconnection,
}

class WearableGatewayException implements Exception {
  const WearableGatewayException(this.kind, this.message);

  final WearableGatewayFailureKind kind;
  final String message;

  @override
  String toString() => 'WearableGatewayException($kind): $message';
}

abstract interface class WearableGateway {
  Future<void> requestPermissions();

  Stream<WearableDescriptor> discover();

  Future<void> stopDiscovery();

  Future<WearableSession> connect(WearableDescriptor descriptor);

  Future<WearableSession> reconnect(String stableId);

  Future<void> dispose();
}

abstract interface class WearableSession {
  WearableDescriptor get descriptor;

  Stream<WearableConnectionStatus> get connectionStatuses;

  Stream<WearableInputEvent> get inputEvents;

  /// Begins provisioning and emits semantic stage/progress updates.
  Stream<WearableSetupUpdate> setup({
    WearableSetupMode mode = WearableSetupMode.provision,
  });

  Future<void> startCapture();

  Future<WearableCapture> stopCapture();

  /// Stops an active capture without waiting for captured content.
  Future<void> cancelCapture();

  Future<void> updateDisplay(WearableDisplayState state);

  /// Keeps the current device display active while work continues.
  Future<void> holdDisplay();

  Future<void> disconnect();

  Future<void> dispose();
}
