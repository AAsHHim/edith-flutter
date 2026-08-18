import 'package:flutter_test/flutter_test.dart';
import 'package:noa/device/simulator/halo_simulator_controller.dart';
import 'package:noa/device/wearable_models.dart';

void main() {
  test('injects primary, cancel, and secondary press metadata', () async {
    final controller = HaloSimulatorController(now: () => DateTime(2026));
    final eventsFuture = controller.inputEvents.take(3).toList();

    controller.injectPrimary();
    controller.injectCancel();
    controller.injectSecondary();
    final events = await eventsFuture;

    expect(events.map((event) => event.type), [
      WearableInputType.primary,
      WearableInputType.cancel,
      WearableInputType.secondary,
    ]);
    expect(events.map((event) => event.metadata['pressKind']), [
      'single',
      'double',
      'long',
    ]);
    expect(events[1].metadata['pressCount'], 2);
    expect(events[2].metadata['isLongPress'], isTrue);
    expect(events.every((event) => event.occurredAt == DateTime(2026)), isTrue);

    await controller.dispose();
  });

  test('configures defensive image and audio fixtures', () async {
    final controller = HaloSimulatorController();
    final image = [1, 2, 3];
    final audio = [4, 5, 6];

    controller.configureImageFixture(image);
    controller.configureAudioFixture(audio);
    image[0] = 9;
    audio[0] = 9;

    expect(controller.imageFixture, [1, 2, 3]);
    expect(controller.audioFixture, [4, 5, 6]);

    await controller.dispose();
  });

  test('observes display, hold, connection, disconnect, and reset', () async {
    final controller = HaloSimulatorController();
    const display = WearableDisplayState(
      mode: WearableDisplayMode.reply,
      primaryText: 'Hello',
    );
    final displayFuture = controller.displayStates.first;
    final statusFuture = controller.connectionStatuses.take(2).toList();
    final holdFuture = controller.holdRequests.first;

    controller.markConnected();
    controller.recordDisplayState(display);
    controller.recordHoldRequest();
    controller.triggerDisconnect();

    expect(await displayFuture, display);
    expect(await statusFuture, [
      WearableConnectionStatus.connected,
      WearableConnectionStatus.disconnected,
    ]);
    expect(await holdFuture, 1);
    expect(controller.latestDisplayState, display);
    expect(controller.displayHistory, [display]);
    expect(controller.holdRequestCount, 1);

    controller.configureImageFixture([1]);
    controller.configureAudioFixture([2]);
    controller.beginCapture();
    controller.reset();

    expect(controller.connectionStatus, WearableConnectionStatus.disconnected);
    expect(controller.latestDisplayState, isNull);
    expect(controller.displayHistory, isEmpty);
    expect(controller.imageFixture, isEmpty);
    expect(controller.audioFixture, isEmpty);
    expect(controller.captureActive, isFalse);
    expect(controller.holdRequestCount, 0);

    await controller.dispose();
  });
}
