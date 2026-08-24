import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import '../wearable_models.dart';

enum SimulatedPressKind {
  single,
  double,
  long,
}

class HaloSimulatorController {
  HaloSimulatorController({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final StreamController<WearableConnectionStatus> _connectionController =
      StreamController.broadcast();
  final StreamController<WearableInputEvent> _inputController =
      StreamController.broadcast();
  final StreamController<WearableDisplayState> _displayController =
      StreamController.broadcast();
  final StreamController<int> _holdController = StreamController.broadcast();
  final StreamController<void> _changeController = StreamController.broadcast();
  final List<WearableDisplayState> _displayHistory = [];
  final List<String> _eventHistory = [];

  static const int maxEventHistoryLength = 80;

  WearableConnectionStatus _connectionStatus =
      WearableConnectionStatus.disconnected;
  WearableDisplayState? _latestDisplayState;
  WearableSetupUpdate? _latestSetupUpdate;
  Uint8List _imageFixture = Uint8List(0);
  Uint8List _audioFixture = Uint8List(0);
  bool _captureActive = false;
  int _captureCancellationCount = 0;
  int _holdRequestCount = 0;
  bool _disposed = false;

  WearableConnectionStatus get connectionStatus => _connectionStatus;
  Stream<WearableConnectionStatus> get connectionStatuses =>
      _connectionController.stream;

  WearableDisplayState? get latestDisplayState => _latestDisplayState;
  UnmodifiableListView<WearableDisplayState> get displayHistory =>
      UnmodifiableListView(_displayHistory);
  Stream<WearableDisplayState> get displayStates => _displayController.stream;

  WearableSetupUpdate? get latestSetupUpdate => _latestSetupUpdate;
  UnmodifiableListView<String> get eventHistory =>
      UnmodifiableListView(_eventHistory);
  Stream<void> get changes => _changeController.stream;

  Uint8List get imageFixture => Uint8List.fromList(_imageFixture);
  Uint8List get audioFixture => Uint8List.fromList(_audioFixture);
  bool get captureActive => _captureActive;
  int get captureCancellationCount => _captureCancellationCount;
  int get holdRequestCount => _holdRequestCount;
  Stream<int> get holdRequests => _holdController.stream;
  Stream<WearableInputEvent> get inputEvents => _inputController.stream;

  void configureImageFixture(List<int> bytes) {
    _ensureActive();
    _imageFixture = Uint8List.fromList(bytes);
    _recordEvent('image fixture: ${bytes.length} bytes');
  }

  void configureAudioFixture(List<int> bytes) {
    _ensureActive();
    _audioFixture = Uint8List.fromList(bytes);
    _recordEvent('audio fixture: ${bytes.length} bytes');
  }

  void injectPrimary({SimulatedPressKind press = SimulatedPressKind.single}) {
    _inject(WearableInputType.primary, press);
  }

  void injectCancel({SimulatedPressKind press = SimulatedPressKind.double}) {
    _inject(WearableInputType.cancel, press);
  }

  void injectSecondary({SimulatedPressKind press = SimulatedPressKind.long}) {
    _inject(WearableInputType.secondary, press);
  }

  void _inject(WearableInputType type, SimulatedPressKind press) {
    _ensureActive();
    _inputController.add(
      WearableInputEvent(
        type: type,
        occurredAt: _now(),
        metadata: {
          'pressKind': press.name,
          'pressCount': press == SimulatedPressKind.double ? 2 : 1,
          'isLongPress': press == SimulatedPressKind.long,
        },
      ),
    );
    _recordEvent('input: ${type.name} (${press.name})');
  }

  void markConnected() {
    _setConnectionStatus(WearableConnectionStatus.connected);
  }

  void markDiscovering() {
    _setConnectionStatus(WearableConnectionStatus.discovering);
  }

  void markConnecting() {
    _setConnectionStatus(WearableConnectionStatus.connecting);
  }

  void triggerDisconnect() {
    markDisconnected();
  }

  void markDisconnected({bool notify = true}) {
    _setConnectionStatus(
      WearableConnectionStatus.disconnected,
      notify: notify,
    );
  }

  void _setConnectionStatus(
    WearableConnectionStatus status, {
    bool notify = true,
  }) {
    _ensureActive();
    _connectionStatus = status;
    if (notify) _connectionController.add(status);
    _recordEvent('connection: ${status.name}');
  }

  void recordSetupUpdate(WearableSetupUpdate update) {
    _ensureActive();
    _latestSetupUpdate = update;
    final progress =
        update.progress == null ? '' : ' ${(update.progress! * 100).round()}%';
    _recordEvent('setup: ${update.stage.name}$progress');
  }

  void recordDisplayState(WearableDisplayState state) {
    _ensureActive();
    _latestDisplayState = state;
    _displayHistory.add(state);
    _displayController.add(state);
    _recordEvent('display: ${state.mode.name}');
  }

  void recordHoldRequest() {
    _ensureActive();
    _holdRequestCount++;
    _holdController.add(_holdRequestCount);
    _recordEvent('display hold: $_holdRequestCount');
  }

  void beginCapture() {
    _ensureActive();
    _captureActive = true;
    _recordEvent('capture: started');
  }

  void finishCapture() {
    _ensureActive();
    _captureActive = false;
    _recordEvent('capture: stopped');
  }

  void cancelCapture() {
    _ensureActive();
    _captureActive = false;
    _captureCancellationCount++;
    _recordEvent('capture: cancelled');
  }

  void reset() {
    _ensureActive();
    _latestDisplayState = null;
    _latestSetupUpdate = null;
    _displayHistory.clear();
    _eventHistory.clear();
    _imageFixture = Uint8List(0);
    _audioFixture = Uint8List(0);
    _captureActive = false;
    _captureCancellationCount = 0;
    _holdRequestCount = 0;
    _setConnectionStatus(WearableConnectionStatus.disconnected);
    _recordEvent('reset');
  }

  void _recordEvent(String event) {
    _eventHistory.add(event);
    if (_eventHistory.length > maxEventHistoryLength) {
      _eventHistory.removeAt(0);
    }
    _changeController.add(null);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _connectionController.close();
    await _inputController.close();
    await _displayController.close();
    await _holdController.close();
    await _changeController.close();
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('HaloSimulatorController has been disposed.');
    }
  }
}
