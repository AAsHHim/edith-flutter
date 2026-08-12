import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:noa/device/wearable_models.dart';

void main() {
  group('WearableDescriptor', () {
    test('reports only declared capabilities', () {
      final descriptor = WearableDescriptor(
        identifier: 'wearable-1',
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
        identifier: 'wearable-1',
        displayName: 'Test wearable',
        transport: WearableTransport.simulator,
        capabilities: const {
          WearableCapability.display,
          WearableCapability.primaryInput,
        },
      );
      final second = WearableDescriptor(
        identifier: 'wearable-1',
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
