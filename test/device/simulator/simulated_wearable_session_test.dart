import 'package:flutter_test/flutter_test.dart';
import 'package:noa/device/simulator/halo_simulator_controller.dart';
import 'package:noa/device/simulator/simulated_wearable_gateway.dart';
import 'package:noa/device/simulator/simulated_wearable_session.dart';
import 'package:noa/device/wearable_models.dart';

void main() {
  test('provision setup emits asynchronous normalized semantic stages',
      () async {
    final controller = HaloSimulatorController()..markConnected();
    final session = _session(controller);

    final updates = await session.setup().toList();

    expect(updates.map((update) => update.stage), [
      WearableSetupStage.checkingDevice,
      WearableSetupStage.checkingDevice,
      WearableSetupStage.installingApplication,
      WearableSetupStage.installingApplication,
      WearableSetupStage.ready,
    ]);
    expect(updates.map((update) => update.progress), [0, 0.5, 0, 1, 1]);
    expect(
      updates.every(
        (update) => update.progress! >= 0 && update.progress! <= 1,
      ),
      isTrue,
    );
    expect(controller.latestSetupUpdate?.stage, WearableSetupStage.ready);
    expect(controller.eventHistory, contains('setup: ready 100%'));

    await controller.dispose();
  });

  test('validation setup checks the device and becomes ready', () async {
    final controller = HaloSimulatorController()..markConnected();
    final session = _session(controller);

    final updates =
        await session.setup(mode: WearableSetupMode.validate).toList();

    expect(updates.map((update) => update.stage), [
      WearableSetupStage.checkingDevice,
      WearableSetupStage.checkingDevice,
      WearableSetupStage.ready,
    ]);

    await controller.dispose();
  });

  test('reports connected then disconnected status', () async {
    final controller = HaloSimulatorController()..markConnected();
    final session = _session(controller);
    final statusesFuture = session.connectionStatuses.take(2).toList();
    await Future<void>.delayed(Duration.zero);

    await session.disconnect();

    expect(await statusesFuture, [
      WearableConnectionStatus.connected,
      WearableConnectionStatus.disconnected,
    ]);

    await controller.dispose();
  });

  test('forwards injected primary, cancel, and press metadata', () async {
    final controller = HaloSimulatorController(now: () => DateTime(2026))
      ..markConnected();
    final session = _session(controller);
    final eventsFuture = session.inputEvents.take(2).toList();

    controller.injectPrimary(press: SimulatedPressKind.single);
    controller.injectCancel(press: SimulatedPressKind.long);
    final events = await eventsFuture;

    expect(events.map((event) => event.type), [
      WearableInputType.primary,
      WearableInputType.cancel,
    ]);
    expect(events[0].metadata['pressKind'], 'single');
    expect(events[1].metadata['pressKind'], 'long');
    expect(events[1].metadata['isLongPress'], isTrue);

    await controller.dispose();
  });

  test('returns configured image and audio capture fixtures', () async {
    final controller = HaloSimulatorController()
      ..markConnected()
      ..configureImageFixture([1, 2, 3])
      ..configureAudioFixture([4, 5, 6]);
    final session = _session(controller);

    await session.startCapture();
    final capture = await session.stopCapture();

    expect(capture.imageBytes, [1, 2, 3]);
    expect(capture.imageContentType, 'image/jpeg');
    expect(capture.audioBytes, [4, 5, 6]);
    expect(capture.audioContentType, 'audio/L8');
    expect(controller.captureActive, isFalse);

    await controller.dispose();
  });

  test('capture cancellation records state without returning content',
      () async {
    final controller = HaloSimulatorController()..markConnected();
    final session = _session(controller);

    await session.startCapture();
    await session.cancelCapture();

    expect(controller.captureActive, isFalse);
    expect(controller.captureCancellationCount, 1);
    await expectLater(session.stopCapture(), throwsStateError);

    await controller.dispose();
  });

  test('records every display mode, history stream, and hold request',
      () async {
    final controller = HaloSimulatorController()..markConnected();
    final session = _session(controller);
    const displays = [
      WearableDisplayState(mode: WearableDisplayMode.ready),
      WearableDisplayState(mode: WearableDisplayMode.listening),
      WearableDisplayState(mode: WearableDisplayMode.thinking),
      WearableDisplayState(mode: WearableDisplayMode.reply),
      WearableDisplayState(mode: WearableDisplayMode.disconnected),
    ];
    final streamedFuture =
        controller.displayStates.take(displays.length).toList();

    for (final display in displays) {
      await session.updateDisplay(display);
    }
    await session.holdDisplay();

    expect(await streamedFuture, displays);
    expect(controller.latestDisplayState, displays.last);
    expect(controller.displayHistory, displays);
    expect(controller.holdRequestCount, 1);

    await controller.dispose();
  });

  test('dispose disconnects, cancels capture, and rejects later operations',
      () async {
    final controller = HaloSimulatorController()..markConnected();
    final session = _session(controller);
    await session.startCapture();

    await session.dispose();

    expect(controller.connectionStatus, WearableConnectionStatus.disconnected);
    expect(controller.captureActive, isFalse);
    expect(controller.captureCancellationCount, 1);
    await expectLater(session.startCapture(), throwsStateError);

    await controller.dispose();
  });
}

SimulatedWearableSession _session(HaloSimulatorController controller) {
  return SimulatedWearableSession(
    descriptor: simulatedWearableDescriptor,
    controller: controller,
    setupDelay: Duration.zero,
  );
}
