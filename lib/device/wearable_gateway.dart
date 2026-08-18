import 'wearable_models.dart';

abstract interface class WearableGateway {
  Future<void> requestPermissions();

  Stream<WearableDescriptor> discover();

  Future<void> stopDiscovery();

  Future<WearableSession> connect(WearableDescriptor descriptor);

  Future<WearableSession> reconnect(String stableId);
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

  Future<void> updateDisplay(WearableDisplayState state);

  Future<void> disconnect();

  Future<void> dispose();
}
