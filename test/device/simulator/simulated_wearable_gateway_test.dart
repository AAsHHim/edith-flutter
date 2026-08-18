import 'package:flutter_test/flutter_test.dart';
import 'package:noa/device/simulator/simulated_wearable_gateway.dart';
import 'package:noa/device/simulator/simulated_wearable_session.dart';
import 'package:noa/device/wearable_gateway.dart';
import 'package:noa/device/wearable_models.dart';

void main() {
  test('discovery is asynchronous and emits the deterministic descriptor',
      () async {
    final gateway = SimulatedWearableGateway(
      discoveryDelay: const Duration(milliseconds: 1),
    );
    var emittedSynchronously = false;

    final descriptorFuture = gateway.discover().first.then((descriptor) {
      emittedSynchronously = true;
      return descriptor;
    });
    expect(emittedSynchronously, isFalse);
    final descriptor = await descriptorFuture;

    expect(descriptor.stableId, 'edith-halo-simulator');
    expect(descriptor.displayName, 'EDITH Halo Simulator');
    expect(descriptor.transport, WearableTransport.simulator);
    expect(descriptor.capabilities, {
      WearableCapability.display,
      WearableCapability.camera,
      WearableCapability.microphone,
      WearableCapability.motion,
      WearableCapability.primaryInput,
      WearableCapability.multiClickInput,
    });

    await gateway.dispose();
  });

  test('stop discovery prevents a pending descriptor emission', () async {
    final gateway = SimulatedWearableGateway(
      discoveryDelay: const Duration(milliseconds: 20),
    );
    final descriptorsFuture = gateway.discover().toList();
    await Future<void>.delayed(Duration.zero);

    await gateway.stopDiscovery();

    expect(await descriptorsFuture, isEmpty);
    expect(
      gateway.controller.connectionStatus,
      WearableConnectionStatus.disconnected,
    );

    await gateway.dispose();
  });

  test('connect is asynchronous and creates one reusable session', () async {
    final gateway = SimulatedWearableGateway(
      connectionDelay: const Duration(milliseconds: 1),
      setupDelay: Duration.zero,
    );

    final firstFuture = gateway.connect(simulatedWearableDescriptor);
    final secondFuture = gateway.connect(simulatedWearableDescriptor);
    expect(
      gateway.controller.connectionStatus,
      WearableConnectionStatus.connecting,
    );
    final first = await firstFuture;
    final second = await secondFuture;

    expect(first, isA<SimulatedWearableSession>());
    expect(second, same(first));
    expect(
      gateway.controller.connectionStatus,
      WearableConnectionStatus.connected,
    );

    await gateway.dispose();
  });

  test('connect rejects an unknown descriptor', () async {
    final gateway = SimulatedWearableGateway();
    final unknown = WearableDescriptor(
      stableId: 'unknown',
      displayName: 'Unknown',
      transport: WearableTransport.simulator,
    );

    await expectLater(
      gateway.connect(unknown),
      throwsA(
        isA<WearableGatewayException>().having(
          (error) => error.kind,
          'kind',
          WearableGatewayFailureKind.connection,
        ),
      ),
    );

    await gateway.dispose();
  });

  test('reconnect accepts only the simulator stable id', () async {
    final gateway = SimulatedWearableGateway(
      connectionDelay: Duration.zero,
      setupDelay: Duration.zero,
    );

    final session = await gateway.reconnect('edith-halo-simulator');

    expect(session, isA<SimulatedWearableSession>());
    expect(session.descriptor, simulatedWearableDescriptor);
    await expectLater(
      gateway.reconnect('unknown'),
      throwsA(
        isA<WearableGatewayException>().having(
          (error) => error.kind,
          'kind',
          WearableGatewayFailureKind.reconnection,
        ),
      ),
    );

    await gateway.dispose();
  });

  test('reconnect creates a new session after disconnect', () async {
    final gateway = SimulatedWearableGateway(
      connectionDelay: Duration.zero,
      setupDelay: Duration.zero,
    );
    final first = await gateway.connect(simulatedWearableDescriptor);
    await first.disconnect();

    final second = await gateway.reconnect(simulatedWearableStableId);

    expect(second, isNot(same(first)));
    expect(
      gateway.controller.connectionStatus,
      WearableConnectionStatus.connected,
    );

    await gateway.dispose();
  });

  test('dispose cleans up the session and controller once', () async {
    final gateway = SimulatedWearableGateway(
      connectionDelay: Duration.zero,
    );
    final session = await gateway.connect(simulatedWearableDescriptor);

    await gateway.dispose();
    await gateway.dispose();

    await expectLater(session.startCapture(), throwsStateError);
    await expectLater(gateway.discover(), emitsError(isA<StateError>()));
    expect(
      () => gateway.controller.injectPrimary(),
      throwsStateError,
    );
  });
}
