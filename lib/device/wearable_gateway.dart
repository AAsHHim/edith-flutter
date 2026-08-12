import 'wearable_models.dart';

abstract interface class WearableGateway {
  Future<void> requestPermissions();

  Stream<WearableDescriptor> discover();

  Future<void> stopDiscovery();

  Future<WearableSession> connect(WearableDescriptor descriptor);

  Future<WearableSession> reconnect(String identifier);
}

abstract interface class WearableSession {
  WearableDescriptor get descriptor;

  Stream<WearableConnectionStatus> get connectionStatuses;

  Stream<WearableInputEvent> get inputEvents;

  Stream<WearableSetupStage> setup();

  Future<void> startCapture();

  Future<WearableCapture> stopCapture();

  Future<void> updateDisplay(WearableDisplayState state);

  Future<void> disconnect();

  Future<void> dispose();
}
