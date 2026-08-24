import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noa/device/device_mode.dart';
import 'package:noa/device/device_providers.dart';
import 'package:noa/device/simulator/halo_simulator_controller.dart';
import 'package:noa/device/simulator/simulated_wearable_gateway.dart';
import 'package:noa/device/simulator/simulated_wearable_session.dart';
import 'package:noa/device/wearable_models.dart';
import 'package:noa/pages/hack.dart';
import 'package:noa/pages/halo_simulator.dart';

void main() {
  testWidgets('simulator entry appears only in simulator mode', (tester) async {
    final controller = HaloSimulatorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _app(
        mode: DeviceMode.simulator,
        controller: controller,
        home: const HackPage(),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('halo-simulator-entry')), findsOneWidget);
    expect(find.text('HALO SIMULATOR'), findsOneWidget);

    await tester.tap(find.byKey(const Key('halo-simulator-entry')));
    await tester.pumpAndSettle();

    expect(find.byType(HaloSimulatorPage), findsOneWidget);
  });

  testWidgets('hardware mode leaves the debug page unchanged', (tester) async {
    await tester.pumpWidget(
      _app(mode: DeviceMode.hardware, home: const HackPage()),
    );
    await tester.pump();

    expect(find.byKey(const Key('halo-simulator-entry')), findsNothing);
    expect(find.text('Bluetooth log'), findsOneWidget);
    expect(find.text('App log'), findsOneWidget);
  });

  testWidgets('preview is 256 square, circular, and renders semantic modes',
      (tester) async {
    final controller = HaloSimulatorController()..markConnected();
    addTearDown(controller.dispose);
    await _pumpSimulatorPage(tester, controller);

    expect(
      tester.getSize(find.byKey(const Key('halo-preview'))),
      const Size.square(256),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('halo-preview')),
        matching: find.byType(ClipOval),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('halo-mode-ready')), findsOneWidget);

    controller.recordDisplayState(
      const WearableDisplayState(mode: WearableDisplayMode.listening),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('halo-mode-listening')), findsOneWidget);

    controller.recordDisplayState(
      const WearableDisplayState(mode: WearableDisplayMode.thinking),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('halo-mode-thinking')), findsOneWidget);

    controller.recordDisplayState(
      const WearableDisplayState(
        mode: WearableDisplayMode.reply,
        primaryText: 'Semantic reply from EDITH',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('halo-mode-reply')), findsOneWidget);
    expect(find.text('Semantic reply from EDITH'), findsOneWidget);

    controller.triggerDisconnect();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('halo-mode-disconnected')), findsOneWidget);
  });

  testWidgets('display stream changes update the preview', (tester) async {
    final controller = HaloSimulatorController()..markConnected();
    addTearDown(controller.dispose);
    await _pumpSimulatorPage(tester, controller);

    controller.recordDisplayState(
      const WearableDisplayState(
        mode: WearableDisplayMode.reply,
        primaryText: 'Updated display',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Updated display'), findsOneWidget);
    expect(find.text('reply'), findsOneWidget);
  });

  testWidgets('input controls emit through the simulated session stream',
      (tester) async {
    final controller = HaloSimulatorController()..markConnected();
    final session = SimulatedWearableSession(
      descriptor: simulatedWearableDescriptor,
      controller: controller,
      setupDelay: Duration.zero,
    );
    final events = <WearableInputEvent>[];
    final subscription = session.inputEvents.listen(events.add);
    addTearDown(() async {
      await subscription.cancel();
      await session.dispose();
      await controller.dispose();
    });
    await _pumpSimulatorPage(tester, controller);

    await _tapControl(tester, 'halo-primary');
    await _tapControl(tester, 'halo-cancel');
    await _tapControl(tester, 'halo-secondary');
    await _tapControl(tester, 'halo-single-press');
    await _tapControl(tester, 'halo-double-press');
    await _tapControl(tester, 'halo-long-press');

    expect(
      events.map((event) => event.type),
      [
        WearableInputType.primary,
        WearableInputType.cancel,
        WearableInputType.secondary,
        WearableInputType.primary,
        WearableInputType.primary,
        WearableInputType.primary,
      ],
    );
    expect(events[3].metadata['pressKind'], 'single');
    expect(events[4].metadata['pressKind'], 'double');
    expect(events[4].metadata['pressCount'], 2);
    expect(events[5].metadata['pressKind'], 'long');
    expect(events[5].metadata['isLongPress'], isTrue);
  });

  testWidgets('disconnect and reset update status, fixtures, and event history',
      (tester) async {
    final controller = HaloSimulatorController()
      ..markConnected()
      ..configureImageFixture([1, 2, 3])
      ..configureAudioFixture([4, 5]);
    addTearDown(controller.dispose);
    await _pumpSimulatorPage(tester, controller);

    expect(find.text('3 bytes'), findsOneWidget);
    expect(find.text('2 bytes'), findsOneWidget);

    await _tapControl(tester, 'halo-disconnect');
    expect(controller.connectionStatus, WearableConnectionStatus.disconnected);
    expect(find.byKey(const Key('halo-mode-disconnected')), findsOneWidget);

    await _tapControl(tester, 'halo-reset');
    expect(controller.imageFixture, isEmpty);
    expect(controller.audioFixture, isEmpty);
    expect(controller.latestDisplayState, isNull);
    expect(controller.eventHistory.last, 'reset');
    expect(find.text('not configured'), findsNWidgets(2));
    expect(find.text('reset'), findsOneWidget);
  });

  testWidgets('long reply remains inside the circular preview without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = HaloSimulatorController()
      ..markConnected()
      ..recordDisplayState(
        WearableDisplayState(
          mode: WearableDisplayMode.reply,
          primaryText: List.filled(
            30,
            'A deliberately long semantic EDITH reply',
          ).join(' '),
        ),
      );
    addTearDown(controller.dispose);

    await _pumpSimulatorPage(tester, controller);

    final reply = tester.widget<Text>(
      find.byKey(const Key('halo-mode-reply')),
    );
    expect(reply.maxLines, 8);
    expect(reply.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  required DeviceMode mode,
  required Widget home,
  HaloSimulatorController? controller,
}) {
  return ProviderScope(
    overrides: [
      deviceModeProvider.overrideWithValue(mode),
      if (controller != null)
        haloSimulatorControllerProvider.overrideWithValue(controller),
    ],
    child: MaterialApp(home: home),
  );
}

Future<void> _pumpSimulatorPage(
  WidgetTester tester,
  HaloSimulatorController controller,
) async {
  await tester.pumpWidget(
    _app(
      mode: DeviceMode.simulator,
      controller: controller,
      home: const HaloSimulatorPage(),
    ),
  );
  await tester.pump();
}

Future<void> _tapControl(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}
