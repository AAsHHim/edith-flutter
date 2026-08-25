import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noa/device/device_providers.dart';
import 'package:noa/device/simulator/simulated_wearable_gateway.dart';
import 'package:noa/device/wearable_gateway.dart';
import 'package:noa/device/wearable_models.dart';
import 'package:noa/models/app_logic_model.dart' as app;
import 'package:noa/pages/noa.dart';
import 'package:noa/pages/pairing.dart';
import 'package:noa/util/state_machine.dart';

void main() {
  testWidgets(
      'successful simulated setup exits pairing instead of staying on Searching',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = SimulatedWearableGateway(
      discoveryDelay: Duration.zero,
      connectionDelay: Duration.zero,
      setupDelay: Duration.zero,
    );
    final container = ProviderContainer(
      overrides: [
        wearableGatewayProvider.overrideWithValue(gateway),
        pairedDevicePreferenceKeyProvider.overrideWithValue(
          simulatedPairedDevicePreferenceKey,
        ),
      ],
    );
    addTearDown(container.dispose);
    final model = container.read(app.model)
      ..state = StateMachine(app.State.scanning);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PairingPage()),
      ),
    );

    model.triggerEvent(app.Event.init);
    await tester.pumpAndSettle();
    expect(find.text('EDITH Halo Simulator found'), findsOneWidget);

    await tester.tap(find.text('Pair'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 800));

    expect(model.state.current, app.State.connected);
    expect(find.byType(PairingPage), findsNothing);
    expect(find.byType(NoaPage), findsOneWidget);
    expect(find.text('Searching'), findsNothing);
  });

  testWidgets('existing disconnected completion exits pairing', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        wearableGatewayProvider.overrideWithValue(_NoopWearableGateway()),
      ],
    );
    addTearDown(container.dispose);
    container.read(app.model).state = StateMachine(app.State.disconnected);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PairingPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PairingPage), findsNothing);
    expect(find.byType(NoaPage), findsOneWidget);
  });
}

class _NoopWearableGateway implements WearableGateway {
  @override
  Future<WearableSession> connect(WearableDescriptor descriptor) =>
      throw UnimplementedError();

  @override
  Stream<WearableDescriptor> discover() => const Stream.empty();

  @override
  Future<void> dispose() async {}

  @override
  Future<WearableSession> reconnect(String stableId) =>
      throw UnimplementedError();

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> stopDiscovery() async {}
}
