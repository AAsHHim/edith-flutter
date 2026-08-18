import 'dart:async';

import '../wearable_gateway.dart';
import '../wearable_models.dart';
import 'halo_simulator_controller.dart';

class SimulatedWearableSession implements WearableSession {
  SimulatedWearableSession({
    required this.descriptor,
    required HaloSimulatorController controller,
    this.setupDelay = const Duration(milliseconds: 10),
  }) : _controller = controller;

  @override
  final WearableDescriptor descriptor;
  final HaloSimulatorController _controller;
  final Duration setupDelay;
  bool _disposed = false;

  HaloSimulatorController get controller => _controller;

  @override
  Stream<WearableConnectionStatus> get connectionStatuses async* {
    _ensureActive();
    yield _controller.connectionStatus;
    yield* _controller.connectionStatuses;
  }

  @override
  Stream<WearableInputEvent> get inputEvents => _controller.inputEvents;

  @override
  Stream<WearableSetupUpdate> setup({
    WearableSetupMode mode = WearableSetupMode.provision,
  }) async* {
    _ensureActive();
    yield WearableSetupUpdate(
      stage: WearableSetupStage.checkingDevice,
      progress: 0,
    );
    await Future<void>.delayed(setupDelay);
    yield WearableSetupUpdate(
      stage: WearableSetupStage.checkingDevice,
      progress: 0.5,
    );
    await Future<void>.delayed(setupDelay);

    if (mode == WearableSetupMode.provision) {
      yield WearableSetupUpdate(
        stage: WearableSetupStage.installingApplication,
        progress: 0,
      );
      await Future<void>.delayed(setupDelay);
      yield WearableSetupUpdate(
        stage: WearableSetupStage.installingApplication,
        progress: 1,
      );
      await Future<void>.delayed(setupDelay);
    }

    yield WearableSetupUpdate(
      stage: WearableSetupStage.ready,
      progress: 1,
    );
  }

  @override
  Future<void> startCapture() async {
    _ensureConnected();
    _controller.beginCapture();
  }

  @override
  Future<WearableCapture> stopCapture() async {
    _ensureConnected();
    if (!_controller.captureActive) {
      throw StateError('No simulated capture is active.');
    }
    final capture = WearableCapture(
      imageBytes: _controller.imageFixture,
      imageContentType: 'image/jpeg',
      audioBytes: _controller.audioFixture,
      audioContentType: 'audio/L8',
    );
    _controller.finishCapture();
    return capture;
  }

  @override
  Future<void> cancelCapture() async {
    _ensureActive();
    _controller.cancelCapture();
  }

  @override
  Future<void> updateDisplay(WearableDisplayState state) async {
    _ensureConnected();
    _controller.recordDisplayState(state);
  }

  @override
  Future<void> holdDisplay() async {
    _ensureConnected();
    _controller.recordHoldRequest();
  }

  @override
  Future<void> disconnect() async {
    _ensureActive();
    if (_controller.captureActive) {
      _controller.cancelCapture();
    }
    _controller.triggerDisconnect();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    if (_controller.connectionStatus != WearableConnectionStatus.disconnected) {
      _controller.markDisconnected(notify: false);
    }
    if (_controller.captureActive) {
      _controller.cancelCapture();
    }
    _disposed = true;
  }

  void _ensureConnected() {
    _ensureActive();
    if (_controller.connectionStatus != WearableConnectionStatus.connected) {
      throw StateError('Simulated wearable is disconnected.');
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('SimulatedWearableSession has been disposed.');
    }
  }
}
