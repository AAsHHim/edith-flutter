import 'dart:collection';

import 'package:flutter/foundation.dart';

enum WearableTransport {
  bluetoothLowEnergy,
  simulator,
  other,
}

enum WearableCapability {
  display,
  camera,
  microphone,
  audioOutput,
  motion,
  primaryInput,
  multiClickInput,
}

@immutable
class WearableDescriptor {
  WearableDescriptor({
    required this.identifier,
    required this.displayName,
    required this.transport,
    Set<WearableCapability> capabilities = const {},
  }) : capabilities = UnmodifiableSetView(Set.of(capabilities));

  final String identifier;
  final String displayName;
  final WearableTransport transport;
  final Set<WearableCapability> capabilities;

  bool supports(WearableCapability capability) =>
      capabilities.contains(capability);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WearableDescriptor &&
          identifier == other.identifier &&
          displayName == other.displayName &&
          transport == other.transport &&
          setEquals(capabilities, other.capabilities);

  @override
  int get hashCode => Object.hash(
        identifier,
        displayName,
        transport,
        Object.hashAllUnordered(capabilities),
      );
}

enum WearableConnectionStatus {
  disconnected,
  discovering,
  discovered,
  connecting,
  connected,
  failed,
}

enum WearableSetupStage {
  checkingDevice,
  updatingFirmware,
  installingApplication,
  ready,
  repairRequired,
}

enum WearableInputType {
  primary,
  secondary,
  cancel,
}

@immutable
class WearableInputEvent {
  WearableInputEvent({
    required this.type,
    required this.occurredAt,
    Map<String, Object?> metadata = const {},
  }) : metadata = UnmodifiableMapView(Map.of(metadata));

  final WearableInputType type;
  final DateTime occurredAt;

  /// Adapter-supplied details such as click count, press duration, or source.
  final Map<String, Object?> metadata;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WearableInputEvent &&
          type == other.type &&
          occurredAt == other.occurredAt &&
          mapEquals(metadata, other.metadata);

  @override
  int get hashCode => Object.hash(
        type,
        occurredAt,
        Object.hashAllUnordered(
          metadata.entries.map((entry) => Object.hash(entry.key, entry.value)),
        ),
      );
}

enum WearableDisplayMode {
  ready,
  listening,
  thinking,
  reply,
  disconnected,
}

@immutable
class WearableDisplayState {
  const WearableDisplayState({
    required this.mode,
    this.primaryText,
    this.secondaryText,
    this.status,
  });

  final WearableDisplayMode mode;
  final String? primaryText;
  final String? secondaryText;
  final String? status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WearableDisplayState &&
          mode == other.mode &&
          primaryText == other.primaryText &&
          secondaryText == other.secondaryText &&
          status == other.status;

  @override
  int get hashCode => Object.hash(mode, primaryText, secondaryText, status);
}

@immutable
class WearableCapture {
  WearableCapture({
    Uint8List? imageBytes,
    this.imageContentType,
    Uint8List? audioBytes,
    this.audioContentType,
  })  : imageBytes = imageBytes == null ? null : Uint8List.fromList(imageBytes),
        audioBytes = audioBytes == null ? null : Uint8List.fromList(audioBytes);

  final Uint8List? imageBytes;
  final String? imageContentType;
  final Uint8List? audioBytes;
  final String? audioContentType;

  bool get hasImage => imageBytes != null;
  bool get hasAudio => audioBytes != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WearableCapture &&
          listEquals(imageBytes, other.imageBytes) &&
          imageContentType == other.imageContentType &&
          listEquals(audioBytes, other.audioBytes) &&
          audioContentType == other.audioContentType;

  @override
  int get hashCode => Object.hash(
        imageBytes == null ? null : Object.hashAll(imageBytes!),
        imageContentType,
        audioBytes == null ? null : Object.hashAll(audioBytes!),
        audioContentType,
      );
}
