import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:noa/device/brilliant/brilliant_wearable_gateway.dart';
import 'package:noa/device/wearable_gateway.dart';
import 'package:noa/device/wearable_models.dart';

void main() {
  test('starts discovery and maps stable id, name, and capabilities', () async {
    final operations = _FakeBrilliantGatewayOperations();
    final gateway = BrilliantWearableGateway.withOperations(operations);

    final descriptorsFuture = gateway.discover().take(1).toList();
    await Future<void>.delayed(Duration.zero);
    operations.emitDiscovery(
      const BrilliantDiscoveryResult(
        stableId: 'frame-remote-id',
        displayName: 'Frame Test',
      ),
    );
    final descriptor = (await descriptorsFuture).single;

    expect(operations.scanCalls, 1);
    expect(descriptor.stableId, 'frame-remote-id');
    expect(descriptor.displayName, 'Frame Test');
    expect(descriptor.transport, WearableTransport.bluetoothLowEnergy);
    expect(descriptor.supports(WearableCapability.display), isTrue);
    expect(descriptor.supports(WearableCapability.camera), isTrue);
    expect(descriptor.supports(WearableCapability.microphone), isTrue);
    expect(descriptor.supports(WearableCapability.multiClickInput), isTrue);
  });

  test('stops discovery through the adapter operations', () async {
    final operations = _FakeBrilliantGatewayOperations();
    final gateway = BrilliantWearableGateway.withOperations(operations);

    await gateway.stopDiscovery();

    expect(operations.stopScanCalls, 1);
  });

  test('connect resolves a discovered stable id and reuses its session',
      () async {
    final session = _FakeWearableSession('frame-remote-id');
    final operations = _FakeBrilliantGatewayOperations(connectSession: session);
    final gateway = BrilliantWearableGateway.withOperations(operations);
    final descriptorFuture = gateway.discover().first;
    await Future<void>.delayed(Duration.zero);
    operations.emitDiscovery(
      const BrilliantDiscoveryResult(
        stableId: 'frame-remote-id',
        displayName: 'Frame Test',
      ),
    );
    final descriptor = await descriptorFuture;

    final first = await gateway.connect(descriptor);
    final second = await gateway.connect(descriptor);

    expect(first, same(session));
    expect(second, same(session));
    expect(operations.connectedStableIds, ['frame-remote-id']);
  });

  test('connect rejects descriptors without a private scan result', () async {
    final gateway = BrilliantWearableGateway.withOperations(
      _FakeBrilliantGatewayOperations(),
    );
    final descriptor = WearableDescriptor(
      stableId: 'unknown',
      displayName: 'Unknown',
      transport: WearableTransport.bluetoothLowEnergy,
    );

    await expectLater(
      gateway.connect(descriptor),
      throwsA(
        isA<WearableGatewayException>().having(
          (error) => error.kind,
          'kind',
          WearableGatewayFailureKind.connection,
        ),
      ),
    );
  });

  test('connect translates adapter failure', () async {
    final operations = _FakeBrilliantGatewayOperations(
      connectError: StateError('connect failed'),
    );
    final gateway = BrilliantWearableGateway.withOperations(operations);
    final descriptorFuture = gateway.discover().first;
    await Future<void>.delayed(Duration.zero);
    operations.emitDiscovery(
      const BrilliantDiscoveryResult(
        stableId: 'frame-remote-id',
        displayName: 'Frame Test',
      ),
    );
    final descriptor = await descriptorFuture;

    await expectLater(
      gateway.connect(descriptor),
      throwsA(
        isA<WearableGatewayException>().having(
          (error) => error.kind,
          'kind',
          WearableGatewayFailureKind.connection,
        ),
      ),
    );
  });

  test('reconnect uses persisted stable id and returns the adapter session',
      () async {
    final session = _FakeWearableSession('persisted-frame-id');
    final operations = _FakeBrilliantGatewayOperations(
      reconnectSession: session,
    );
    final gateway = BrilliantWearableGateway.withOperations(operations);

    final result = await gateway.reconnect('persisted-frame-id');

    expect(result, same(session));
    expect(operations.reconnectedStableIds, ['persisted-frame-id']);
  });

  test('reconnect translates adapter failure', () async {
    final gateway = BrilliantWearableGateway.withOperations(
      _FakeBrilliantGatewayOperations(
        reconnectError: StateError('reconnect failed'),
      ),
    );

    await expectLater(
      gateway.reconnect('persisted-frame-id'),
      throwsA(
        isA<WearableGatewayException>().having(
          (error) => error.kind,
          'kind',
          WearableGatewayFailureKind.reconnection,
        ),
      ),
    );
  });

  test('dispose stops adapter resources once and rejects further use',
      () async {
    final operations = _FakeBrilliantGatewayOperations();
    final gateway = BrilliantWearableGateway.withOperations(operations);

    await gateway.dispose();
    await gateway.dispose();

    expect(operations.disposeCalls, 1);
    await expectLater(gateway.discover(), emitsError(isA<StateError>()));
  });
}

class _FakeBrilliantGatewayOperations implements BrilliantGatewayOperations {
  _FakeBrilliantGatewayOperations({
    this.connectSession,
    this.reconnectSession,
    this.connectError,
    this.reconnectError,
  });

  final StreamController<BrilliantDiscoveryResult> _discoveries =
      StreamController.broadcast();
  final WearableSession? connectSession;
  final WearableSession? reconnectSession;
  final Object? connectError;
  final Object? reconnectError;
  int scanCalls = 0;
  int stopScanCalls = 0;
  int disposeCalls = 0;
  final List<String> connectedStableIds = [];
  final List<String> reconnectedStableIds = [];

  void emitDiscovery(BrilliantDiscoveryResult result) {
    _discoveries.add(result);
  }

  @override
  Future<void> requestPermissions() async {}

  @override
  Stream<BrilliantDiscoveryResult> scan() {
    scanCalls++;
    return _discoveries.stream;
  }

  @override
  Future<void> stopScan() async {
    stopScanCalls++;
  }

  @override
  Future<WearableSession> connect(String stableId) async {
    connectedStableIds.add(stableId);
    if (connectError != null) throw connectError!;
    return connectSession!;
  }

  @override
  Future<WearableSession> reconnect(String stableId) async {
    reconnectedStableIds.add(stableId);
    if (reconnectError != null) throw reconnectError!;
    return reconnectSession!;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await _discoveries.close();
  }
}

class _FakeWearableSession implements WearableSession {
  _FakeWearableSession(this.stableId);

  final String stableId;

  @override
  WearableDescriptor get descriptor => WearableDescriptor(
        stableId: stableId,
        displayName: 'Frame Test',
        transport: WearableTransport.bluetoothLowEnergy,
      );

  @override
  Stream<WearableConnectionStatus> get connectionStatuses =>
      const Stream.empty();

  @override
  Stream<WearableInputEvent> get inputEvents => const Stream.empty();

  @override
  Stream<WearableSetupUpdate> setup({
    WearableSetupMode mode = WearableSetupMode.provision,
  }) =>
      const Stream.empty();

  @override
  Future<void> startCapture() async {}

  @override
  Future<WearableCapture> stopCapture() async => WearableCapture();

  @override
  Future<void> cancelCapture() async {}

  @override
  Future<void> updateDisplay(WearableDisplayState state) async {}

  @override
  Future<void> holdDisplay() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {}
}
