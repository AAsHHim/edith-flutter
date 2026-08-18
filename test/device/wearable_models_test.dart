import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:noa/device/wearable_models.dart';

void main() {
  group('WearableDescriptor', () {
    test('reports only declared capabilities', () {
      final descriptor = WearableDescriptor(
        stableId: 'wearable-1',
        displayName: 'Test wearable',
        transport: WearableTransport.simulator,
        capabilities: const {
          WearableCapability.display,
          WearableCapability.primaryInput,
        },
      );

      expect(descriptor.supports(WearableCapability.display), isTrue);
      expect(descriptor.supports(WearableCapability.camera), isFalse);
    });

    test('uses value equality independent of capability order', () {
      final first = WearableDescriptor(
        stableId: 'wearable-1',
        displayName: 'Test wearable',
        transport: WearableTransport.simulator,
        capabilities: const {
          WearableCapability.display,
          WearableCapability.primaryInput,
        },
      );
      final second = WearableDescriptor(
        stableId: 'wearable-1',
        displayName: 'Test wearable',
        transport: WearableTransport.simulator,
        capabilities: const {
          WearableCapability.primaryInput,
          WearableCapability.display,
        },
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('exposes a stable identifier for reconnect', () {
      final descriptor = WearableDescriptor(
        stableId: 'persistent-device-id',
        displayName: 'Test wearable',
        transport: WearableTransport.bluetoothLowEnergy,
      );

      expect(descriptor.stableId, 'persistent-device-id');
    });
  });

  group('WearableSetupUpdate', () {
    test('represents semantic stages and normalized progress', () {
      final update = WearableSetupUpdate(
        stage: WearableSetupStage.updatingFirmware,
        progress: 0.5,
      );

      expect(update.stage, WearableSetupStage.updatingFirmware);
      expect(update.progress, 0.5);
      expect(update.isReady, isFalse);
      expect(update.requiresRepair, isFalse);
    });

    test('accepts progress boundaries', () {
      expect(
        WearableSetupUpdate(
          stage: WearableSetupStage.installingApplication,
          progress: 0,
        ).progress,
        0,
      );
      expect(
        WearableSetupUpdate(
          stage: WearableSetupStage.ready,
          progress: 1,
        ).progress,
        1,
      );
    });

    test('rejects progress outside the normalized range', () {
      expect(
        () => WearableSetupUpdate(
          stage: WearableSetupStage.updatingFirmware,
          progress: -0.01,
        ),
        throwsRangeError,
      );
      expect(
        () => WearableSetupUpdate(
          stage: WearableSetupStage.updatingFirmware,
          progress: 1.01,
        ),
        throwsRangeError,
      );
      expect(
        () => WearableSetupUpdate(
          stage: WearableSetupStage.updatingFirmware,
          progress: double.nan,
        ),
        throwsRangeError,
      );
    });

    test('distinguishes ready, repair, recoverable, and disconnected states',
        () {
      final ready = WearableSetupUpdate(stage: WearableSetupStage.ready);
      final repair = WearableSetupUpdate(
        stage: WearableSetupStage.repairRequired,
        failure: const WearableFailure(
          kind: WearableFailureKind.repairRequired,
        ),
      );
      final recoverable = WearableSetupUpdate(
        stage: WearableSetupStage.checkingDevice,
        failure: const WearableFailure(kind: WearableFailureKind.recoverable),
      );
      final disconnected = WearableSetupUpdate(
        stage: WearableSetupStage.checkingDevice,
        failure: const WearableFailure(kind: WearableFailureKind.disconnected),
      );

      expect(ready.isReady, isTrue);
      expect(repair.requiresRepair, isTrue);
      expect(recoverable.failure?.kind, WearableFailureKind.recoverable);
      expect(disconnected.failure?.kind, WearableFailureKind.disconnected);
    });
  });

  test('input events preserve semantic type and adapter metadata', () {
    final occurredAt = DateTime.utc(2026, 8, 12);
    final event = WearableInputEvent(
      type: WearableInputType.primary,
      occurredAt: occurredAt,
      metadata: const {'pressKind': 'long', 'durationMs': 650},
    );

    expect(event.type, WearableInputType.primary);
    expect(event.metadata['pressKind'], 'long');
  });

  test('input metadata can describe single, double, and long presses', () {
    final occurredAt = DateTime.utc(2026, 8, 17);
    final events = [
      WearableInputEvent(
        type: WearableInputType.primary,
        occurredAt: occurredAt,
        metadata: const {'pressKind': 'single', 'clickCount': 1},
      ),
      WearableInputEvent(
        type: WearableInputType.primary,
        occurredAt: occurredAt,
        metadata: const {'pressKind': 'double', 'clickCount': 2},
      ),
      WearableInputEvent(
        type: WearableInputType.primary,
        occurredAt: occurredAt,
        metadata: const {'pressKind': 'long', 'durationMs': 650},
      ),
    ];

    expect(
      events.map((event) => event.metadata['pressKind']),
      ['single', 'double', 'long'],
    );
  });

  test('display states use value equality', () {
    const first = WearableDisplayState(
      mode: WearableDisplayMode.reply,
      primaryText: 'Done',
      status: 'success',
    );
    const second = WearableDisplayState(
      mode: WearableDisplayMode.reply,
      primaryText: 'Done',
      status: 'success',
    );

    expect(first, second);
    expect(first.primaryText, 'Done');
    expect(first.status, 'success');
  });

  test('capture records optional media and content types', () {
    final capture = WearableCapture(
      imageBytes: Uint8List.fromList([1, 2, 3]),
      imageContentType: 'image/jpeg',
      audioBytes: Uint8List.fromList([4, 5, 6]),
      audioContentType: 'audio/wav',
    );

    expect(capture.hasImage, isTrue);
    expect(capture.hasAudio, isTrue);
    expect(capture.imageContentType, 'image/jpeg');
    expect(capture.audioContentType, 'audio/wav');
  });
}
