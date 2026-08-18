import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:noa/device/brilliant/brilliant_wearable_session.dart';
import 'package:noa/device/wearable_models.dart';

void main() {
  test('provisions current firmware and reports installation progress',
      () async {
    final operations = _FakeBrilliantOperations(
      installProgress: const [25, 100],
    );
    final session = BrilliantWearableSession.withOperations(operations);

    final updates = await session.setup().toList();

    expect(
      updates.map((update) => update.stage),
      [
        WearableSetupStage.checkingDevice,
        WearableSetupStage.checkingDevice,
        WearableSetupStage.installingApplication,
        WearableSetupStage.installingApplication,
        WearableSetupStage.installingApplication,
        WearableSetupStage.ready,
      ],
    );
    expect(
      updates.map((update) => update.progress),
      [0, 0.5, 0, 0.25, 1, 1],
    );
    expect(operations.stopApplicationCalls, 1);
    expect(operations.installApplicationCalls, 1);
    expect(operations.resetDeviceCalls, 1);
  });

  test('requests firmware update when firmware is not current', () async {
    final operations = _FakeBrilliantOperations(firmwareCurrent: false);
    final session = BrilliantWearableSession.withOperations(operations);

    final updates = await session.setup().toList();

    expect(updates.last.stage, WearableSetupStage.updatingFirmware);
    expect(updates.last.progress, 0);
    expect(operations.enterFirmwareUpdateModeCalls, 1);
    expect(operations.installApplicationCalls, 0);
  });

  test('DFU session reports normalized firmware progress', () async {
    final operations = _FakeBrilliantOperations(
      deviceMode: BrilliantSessionDeviceMode.firmwareUpdate,
      firmwareProgress: const [20, 75, 100],
    );
    final session = BrilliantWearableSession.withOperations(operations);

    final updates = await session.setup().toList();

    expect(
      updates.map((update) => update.progress),
      [0, 0.2, 0.75, 1],
    );
    expect(operations.updateFirmwareCalls, 1);
  });

  test('validation checks firmware and application before ready', () async {
    final operations = _FakeBrilliantOperations();
    final session = BrilliantWearableSession.withOperations(operations);

    final updates =
        await session.setup(mode: WearableSetupMode.validate).toList();

    expect(
      updates.map((update) => update.stage),
      [
        WearableSetupStage.checkingDevice,
        WearableSetupStage.checkingDevice,
        WearableSetupStage.ready,
      ],
    );
    expect(operations.hasCurrentApplicationCalls, 1);
    expect(operations.resumeApplicationCalls, 1);
    expect(operations.installApplicationCalls, 0);
  });

  test('stop failure reports repair required and disconnects', () async {
    final operations = _FakeBrilliantOperations(stopError: StateError('stop'));
    final session = BrilliantWearableSession.withOperations(operations);

    final updates = await session.setup().toList();

    expect(updates.last.stage, WearableSetupStage.repairRequired);
    expect(
      updates.last.failure?.kind,
      WearableFailureKind.repairRequired,
    );
    expect(operations.disconnectCalls, 1);
  });

  test('application installation failure reports disconnected', () async {
    final operations = _FakeBrilliantOperations(
      installError: StateError('install'),
    );
    final session = BrilliantWearableSession.withOperations(operations);

    final updates = await session.setup().toList();

    expect(
      updates.last.failure?.kind,
      WearableFailureKind.disconnected,
    );
    expect(operations.disconnectCalls, 1);
  });

  test('validation failure is recoverable', () async {
    final operations = _FakeBrilliantOperations(
      firmwareCheckError: StateError('check'),
    );
    final session = BrilliantWearableSession.withOperations(operations);

    final updates =
        await session.setup(mode: WearableSetupMode.validate).toList();

    expect(updates.last.failure?.kind, WearableFailureKind.recoverable);
    expect(operations.disconnectCalls, 0);
  });

  test('outdated application validation is recoverable', () async {
    final operations = _FakeBrilliantOperations(applicationCurrent: false);
    final session = BrilliantWearableSession.withOperations(operations);

    final updates =
        await session.setup(mode: WearableSetupMode.validate).toList();

    expect(updates.last.failure?.kind, WearableFailureKind.recoverable);
    expect(operations.resumeApplicationCalls, 0);
    expect(operations.disconnectCalls, 0);
  });

  test('DFU failure reports disconnected', () async {
    final operations = _FakeBrilliantOperations(
      deviceMode: BrilliantSessionDeviceMode.firmwareUpdate,
      firmwareUpdateError: StateError('dfu'),
    );
    final session = BrilliantWearableSession.withOperations(operations);

    final updates = await session.setup().toList();

    expect(
      updates.last.failure?.kind,
      WearableFailureKind.disconnected,
    );
    expect(operations.disconnectCalls, 1);
  });

  test('unmigrated capture and display operations are unsupported', () async {
    final session = BrilliantWearableSession.withOperations(
      _FakeBrilliantOperations(),
    );

    await expectLater(session.startCapture(), throwsUnsupportedError);
    await expectLater(session.stopCapture(), throwsUnsupportedError);
    await expectLater(
      session.updateDisplay(
        const WearableDisplayState(mode: WearableDisplayMode.ready),
      ),
      throwsUnsupportedError,
    );
  });
}

class _FakeBrilliantOperations implements BrilliantSessionOperations {
  _FakeBrilliantOperations({
    this.deviceMode = BrilliantSessionDeviceMode.application,
    this.firmwareCurrent = true,
    this.applicationCurrent = true,
    this.installProgress = const [],
    this.firmwareProgress = const [],
    this.stopError,
    this.firmwareCheckError,
    this.installError,
    this.firmwareUpdateError,
  });

  @override
  final BrilliantSessionDeviceMode deviceMode;
  final bool firmwareCurrent;
  final bool applicationCurrent;
  final List<double> installProgress;
  final List<double> firmwareProgress;
  final Object? stopError;
  final Object? firmwareCheckError;
  final Object? installError;
  final Object? firmwareUpdateError;

  int stopApplicationCalls = 0;
  int hasCurrentApplicationCalls = 0;
  int enterFirmwareUpdateModeCalls = 0;
  int updateFirmwareCalls = 0;
  int installApplicationCalls = 0;
  int resetDeviceCalls = 0;
  int resumeApplicationCalls = 0;
  int disconnectCalls = 0;

  @override
  WearableDescriptor get descriptor => WearableDescriptor(
        stableId: 'frame-test',
        displayName: 'Frame Test',
        transport: WearableTransport.bluetoothLowEnergy,
      );

  @override
  Stream<WearableConnectionStatus> get connectionStatuses =>
      const Stream.empty();

  @override
  Future<void> stopApplication() async {
    stopApplicationCalls++;
    await Future<void>.delayed(Duration.zero);
    if (stopError != null) throw stopError!;
  }

  @override
  Future<bool> hasCurrentFirmware(WearableSetupMode mode) async {
    await Future<void>.delayed(Duration.zero);
    if (firmwareCheckError != null) throw firmwareCheckError!;
    return firmwareCurrent;
  }

  @override
  Future<bool> hasCurrentApplication() async {
    hasCurrentApplicationCalls++;
    await Future<void>.delayed(Duration.zero);
    return applicationCurrent;
  }

  @override
  Future<void> resumeApplication() async {
    resumeApplicationCalls++;
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Future<void> enterFirmwareUpdateMode() async {
    enterFirmwareUpdateModeCalls++;
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Stream<double> updateFirmware() async* {
    updateFirmwareCalls++;
    await Future<void>.delayed(Duration.zero);
    if (firmwareUpdateError != null) throw firmwareUpdateError!;
    yield* Stream.fromIterable(firmwareProgress);
  }

  @override
  Stream<double> installApplication() async* {
    installApplicationCalls++;
    await Future<void>.delayed(Duration.zero);
    if (installError != null) throw installError!;
    yield* Stream.fromIterable(installProgress);
  }

  @override
  Future<void> resetDevice() async {
    resetDeviceCalls++;
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    await Future<void>.delayed(Duration.zero);
  }
}
