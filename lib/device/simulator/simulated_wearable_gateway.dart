import 'dart:async';

import '../wearable_gateway.dart';
import '../wearable_models.dart';
import 'halo_simulator_controller.dart';
import 'simulated_wearable_session.dart';

const simulatedWearableStableId = 'edith-halo-simulator';

final simulatedWearableDescriptor = WearableDescriptor(
  stableId: simulatedWearableStableId,
  displayName: 'EDITH Halo Simulator',
  transport: WearableTransport.simulator,
  capabilities: const {
    WearableCapability.display,
    WearableCapability.camera,
    WearableCapability.microphone,
    WearableCapability.motion,
    WearableCapability.primaryInput,
    WearableCapability.multiClickInput,
  },
);

class SimulatedWearableGateway implements WearableGateway {
  SimulatedWearableGateway({
    HaloSimulatorController? controller,
    this.discoveryDelay = const Duration(milliseconds: 50),
    this.connectionDelay = const Duration(milliseconds: 25),
    this.setupDelay = const Duration(milliseconds: 10),
  })  : _ownsController = controller == null,
        controller = controller ?? HaloSimulatorController();

  final HaloSimulatorController controller;
  final bool _ownsController;
  final Duration discoveryDelay;
  final Duration connectionDelay;
  final Duration setupDelay;
  SimulatedWearableSession? _session;
  Future<WearableSession>? _pendingConnection;
  int _discoveryGeneration = 0;
  bool _disposed = false;

  @override
  Future<void> requestPermissions() async {
    _ensureActive();
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Stream<WearableDescriptor> discover() async* {
    _ensureActive();
    final generation = ++_discoveryGeneration;
    controller.markDiscovering();
    await Future<void>.delayed(discoveryDelay);
    if (_disposed || generation != _discoveryGeneration) return;
    yield simulatedWearableDescriptor;
  }

  @override
  Future<void> stopDiscovery() async {
    _ensureActive();
    _discoveryGeneration++;
    if (controller.connectionStatus == WearableConnectionStatus.discovering) {
      controller.triggerDisconnect();
    }
  }

  @override
  Future<WearableSession> connect(WearableDescriptor descriptor) async {
    _ensureActive();
    if (descriptor != simulatedWearableDescriptor) {
      throw const WearableGatewayException(
        WearableGatewayFailureKind.connection,
        'Unknown simulated wearable descriptor.',
      );
    }
    return _connect();
  }

  @override
  Future<WearableSession> reconnect(String stableId) async {
    _ensureActive();
    if (stableId != simulatedWearableStableId) {
      throw const WearableGatewayException(
        WearableGatewayFailureKind.reconnection,
        'Unknown simulated wearable identifier.',
      );
    }
    return _connect();
  }

  Future<WearableSession> _connect() {
    final session = _session;
    if (session != null &&
        controller.connectionStatus == WearableConnectionStatus.connected) {
      return Future.value(session);
    }
    final pending = _pendingConnection;
    if (pending != null) return pending;
    final connection = _createSession();
    _pendingConnection = connection;
    connection.then(
      (_) => _pendingConnection = null,
      onError: (_) => _pendingConnection = null,
    );
    return connection;
  }

  Future<WearableSession> _createSession() async {
    controller.markConnecting();
    await Future<void>.delayed(connectionDelay);
    _ensureActive();
    await _session?.dispose();
    controller.markConnected();
    final session = SimulatedWearableSession(
      descriptor: simulatedWearableDescriptor,
      controller: controller,
      setupDelay: setupDelay,
    );
    _session = session;
    return session;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _discoveryGeneration++;
    await _session?.dispose();
    _session = null;
    _disposed = true;
    if (_ownsController) await controller.dispose();
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('SimulatedWearableGateway has been disposed.');
    }
  }
}
