import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:frame_ble/brilliant_connection_state.dart';
import 'package:frame_ble/brilliant_device.dart';
import 'package:frame_ble/brilliant_dfu_device.dart';
import 'package:frame_msg/frame_msg.dart';
import 'package:logging/logging.dart';
import 'package:noa/device/wearable_gateway.dart';
import 'package:noa/device/wearable_models.dart';
import 'package:noa/util/tx_rich_text.dart';

final _log = Logger('Brilliant wearable session');

const _firmwareVersion = 'v25.080.0838';
const _scriptVersion = 'v1.0.8';
const _checkFirmwareVersionFlag = 0x16;
const _checkScriptVersionFlag = 0x17;
const _singleDataFlag = 0x22;
const _loopAheadFlag = 0x14;
const _messageResponseFlag = 0x20;
const _holdResponseFlag = 0x23;
const _tapFlag = 0x10;
const _stopTapFlag = 0x13;
const _startListeningFlag = 0x11;
const _stopListeningFlag = 0x12;
const _captureResolution = 720;
const _captureQualityIndex = 4;
const _captureQualityLevel = 'HIGH';

enum BrilliantSessionDeviceMode {
  application,
  firmwareUpdate,
}

enum BrilliantSessionConnectionState {
  connected,
  disconnected,
}

abstract interface class BrilliantSessionOperations {
  WearableDescriptor get descriptor;

  BrilliantSessionDeviceMode get deviceMode;

  Stream<BrilliantSessionConnectionState> get connectionStates;

  Stream<int> monitorInputCounts();

  Future<void> beginCapture();

  Future<WearableCapture> finishCapture();

  Future<void> cancelCapture();

  Future<void> showDisplay(WearableDisplayState state);

  Future<void> holdDisplay();

  Future<void> stopApplication();

  Future<bool> hasCurrentFirmware(WearableSetupMode mode);

  Future<bool> hasCurrentApplication();

  Future<void> resumeApplication();

  Future<void> enterFirmwareUpdateMode();

  Stream<double> updateFirmware();

  Stream<double> installApplication();

  Future<void> resetDevice();

  Future<void> disconnect();

  Future<void> dispose();
}

class BrilliantWearableSession implements WearableSession {
  BrilliantWearableSession(BrilliantDevice device)
      : this.withOperations(_BrilliantDeviceOperations(device));

  BrilliantWearableSession.withOperations(this._operations);

  final BrilliantSessionOperations _operations;

  @override
  WearableDescriptor get descriptor => _operations.descriptor;

  @override
  Stream<WearableConnectionStatus> get connectionStatuses =>
      _operations.connectionStates.map((state) {
        switch (state) {
          case BrilliantSessionConnectionState.connected:
            return WearableConnectionStatus.connected;
          case BrilliantSessionConnectionState.disconnected:
            return WearableConnectionStatus.disconnected;
        }
      });

  @override
  Stream<WearableInputEvent> get inputEvents =>
      _operations.monitorInputCounts().asyncExpand((count) {
        if (count != 1 && count != 2) {
          return const Stream<WearableInputEvent>.empty();
        }
        return Stream.value(
          WearableInputEvent(
            type: count == 1
                ? WearableInputType.primary
                : WearableInputType.cancel,
            occurredAt: DateTime.now(),
            metadata: {'pressCount': count},
          ),
        );
      });

  @override
  Stream<WearableSetupUpdate> setup({
    WearableSetupMode mode = WearableSetupMode.provision,
  }) async* {
    if (_operations.deviceMode == BrilliantSessionDeviceMode.firmwareUpdate) {
      yield WearableSetupUpdate(
        stage: WearableSetupStage.updatingFirmware,
        progress: 0,
      );
      try {
        await for (final progress in _operations.updateFirmware()) {
          yield WearableSetupUpdate(
            stage: WearableSetupStage.updatingFirmware,
            progress: _normalizePercent(progress),
          );
        }
      } catch (error) {
        await _operations.disconnect();
        yield _failureUpdate(
          WearableSetupStage.updatingFirmware,
          WearableFailureKind.disconnected,
          error,
        );
      }
      return;
    }

    if (mode == WearableSetupMode.validate) {
      yield* _validateSetup();
      return;
    }

    yield* _provisionSetup();
  }

  Stream<WearableSetupUpdate> _provisionSetup() async* {
    yield WearableSetupUpdate(
      stage: WearableSetupStage.checkingDevice,
      progress: 0,
    );

    try {
      await _operations.stopApplication();
    } catch (error) {
      await _operations.disconnect();
      yield _failureUpdate(
        WearableSetupStage.repairRequired,
        WearableFailureKind.repairRequired,
        error,
      );
      return;
    }

    yield WearableSetupUpdate(
      stage: WearableSetupStage.checkingDevice,
      progress: 0.5,
    );

    bool firmwareCurrent;
    try {
      firmwareCurrent =
          await _operations.hasCurrentFirmware(WearableSetupMode.provision);
    } catch (error) {
      yield _failureUpdate(
        WearableSetupStage.repairRequired,
        WearableFailureKind.repairRequired,
        error,
      );
      return;
    }

    if (!firmwareCurrent) {
      yield WearableSetupUpdate(
        stage: WearableSetupStage.updatingFirmware,
        progress: 0,
      );
      try {
        await _operations.enterFirmwareUpdateMode();
      } catch (error) {
        await _operations.disconnect();
        yield _failureUpdate(
          WearableSetupStage.updatingFirmware,
          WearableFailureKind.disconnected,
          error,
        );
      }
      return;
    }

    yield WearableSetupUpdate(
      stage: WearableSetupStage.installingApplication,
      progress: 0,
    );
    try {
      await for (final progress in _operations.installApplication()) {
        yield WearableSetupUpdate(
          stage: WearableSetupStage.installingApplication,
          progress: _normalizePercent(progress),
        );
      }
      await _operations.resetDevice();
      yield WearableSetupUpdate(
        stage: WearableSetupStage.ready,
        progress: 1,
      );
    } catch (error) {
      await _operations.disconnect();
      yield _failureUpdate(
        WearableSetupStage.installingApplication,
        WearableFailureKind.disconnected,
        error,
      );
    }
  }

  Stream<WearableSetupUpdate> _validateSetup() async* {
    yield WearableSetupUpdate(
      stage: WearableSetupStage.checkingDevice,
      progress: 0,
    );

    bool firmwareCurrent;
    try {
      firmwareCurrent =
          await _operations.hasCurrentFirmware(WearableSetupMode.validate);
    } catch (error) {
      yield _failureUpdate(
        WearableSetupStage.checkingDevice,
        WearableFailureKind.recoverable,
        error,
      );
      return;
    }
    if (!firmwareCurrent) {
      yield _failureUpdate(
        WearableSetupStage.checkingDevice,
        WearableFailureKind.recoverable,
        'Firmware requires provisioning',
      );
      return;
    }

    yield WearableSetupUpdate(
      stage: WearableSetupStage.checkingDevice,
      progress: 0.5,
    );

    bool applicationCurrent;
    try {
      applicationCurrent = await _operations.hasCurrentApplication();
    } catch (error) {
      yield _failureUpdate(
        WearableSetupStage.checkingDevice,
        WearableFailureKind.recoverable,
        error,
      );
      return;
    }
    if (!applicationCurrent) {
      yield _failureUpdate(
        WearableSetupStage.checkingDevice,
        WearableFailureKind.recoverable,
        'Application requires provisioning',
      );
      return;
    }

    try {
      await _operations.resumeApplication();
    } catch (error) {
      yield _failureUpdate(
        WearableSetupStage.checkingDevice,
        WearableFailureKind.recoverable,
        error,
      );
      return;
    }

    yield WearableSetupUpdate(
      stage: WearableSetupStage.ready,
      progress: 1,
    );
  }

  WearableSetupUpdate _failureUpdate(
    WearableSetupStage stage,
    WearableFailureKind kind,
    Object error,
  ) {
    _log.warning('Setup failed during $stage: $error');
    return WearableSetupUpdate(
      stage: stage,
      failure: WearableFailure(kind: kind, message: error.toString()),
    );
  }

  double _normalizePercent(double progress) =>
      (progress / 100).clamp(0.0, 1.0).toDouble();

  @override
  Future<void> startCapture() => _operations.beginCapture();

  @override
  Future<WearableCapture> stopCapture() => _operations.finishCapture();

  @override
  Future<void> cancelCapture() => _operations.cancelCapture();

  @override
  Future<void> updateDisplay(WearableDisplayState state) =>
      _operations.showDisplay(state);

  @override
  Future<void> holdDisplay() => _operations.holdDisplay();

  @override
  Future<void> disconnect() => _operations.disconnect();

  @override
  Future<void> dispose() => _operations.dispose();
}

class _BrilliantDeviceOperations implements BrilliantSessionOperations {
  _BrilliantDeviceOperations(this._device);

  final BrilliantDevice _device;
  StreamSubscription<int>? _inputSubscription;
  StreamSubscription<String>? _stringResponseSubscription;
  StreamSubscription<Uint8List>? _photoSubscription;
  StreamSubscription<Uint8List>? _audioSubscription;
  Completer<Uint8List>? _image;
  Completer<Uint8List>? _audio;

  @override
  WearableDescriptor get descriptor => WearableDescriptor(
        stableId: _device.device.remoteId.toString(),
        displayName: _device.device.advName,
        transport: WearableTransport.bluetoothLowEnergy,
        capabilities: const {
          WearableCapability.display,
          WearableCapability.camera,
          WearableCapability.microphone,
          WearableCapability.primaryInput,
          WearableCapability.multiClickInput,
        },
      );

  @override
  BrilliantSessionDeviceMode get deviceMode =>
      _device.state == BrilliantConnectionState.dfuConnected
          ? BrilliantSessionDeviceMode.firmwareUpdate
          : BrilliantSessionDeviceMode.application;

  @override
  Stream<BrilliantSessionConnectionState> get connectionStates =>
      _device.connectionState.map((device) {
        switch (device.state) {
          case BrilliantConnectionState.connected:
          case BrilliantConnectionState.dfuConnected:
            return BrilliantSessionConnectionState.connected;
          case BrilliantConnectionState.disconnected:
            return BrilliantSessionConnectionState.disconnected;
        }
      });

  @override
  Stream<int> monitorInputCounts() {
    late final StreamController<int> controller;
    controller = StreamController<int>(
      onListen: () {
        _inputSubscription?.cancel();
        _stringResponseSubscription?.cancel();
        _device.sendMessage(
          _singleDataFlag,
          TxCode(value: _stopTapFlag).pack(),
        );
        _stringResponseSubscription =
            _device.stringResponse.listen((event) async {});
        _inputSubscription = RxTap(
          tapFlag: _tapFlag,
          threshold: const Duration(milliseconds: 200),
        ).attach(_device.dataResponse).listen(
              controller.add,
              onError: controller.addError,
            );
        _device.sendMessage(
          _singleDataFlag,
          TxCode(value: _tapFlag).pack(),
        );
      },
      onCancel: () async {
        await _inputSubscription?.cancel();
        _inputSubscription = null;
        await _stringResponseSubscription?.cancel();
        _stringResponseSubscription = null;
      },
    );
    return controller.stream;
  }

  @override
  Future<void> beginCapture() async {
    final image = Completer<Uint8List>();
    final audio = Completer<Uint8List>();
    _image = image;
    _audio = audio;
    _photoSubscription = RxPhoto(
      quality: _captureQualityLevel,
      resolution: _captureResolution,
    ).attach(_device.dataResponse).listen(
          image.complete,
          onError: image.completeError,
        );
    _audioSubscription = RxAudio(streaming: false)
        .attach(_device.dataResponse)
        .listen(audio.complete, onError: audio.completeError);
    await _device.sendMessage(
      _startListeningFlag,
      TxCaptureSettings(
        resolution: _captureResolution,
        qualityIndex: _captureQualityIndex,
      ).pack(),
    );
  }

  @override
  Future<WearableCapture> finishCapture() async {
    _device.sendMessage(
      _singleDataFlag,
      TxCode(value: _stopListeningFlag).pack(),
    );
    final image = await _image?.future;
    final audio = await _audio?.future;
    await _photoSubscription?.cancel();
    await _audioSubscription?.cancel();
    _photoSubscription = null;
    _audioSubscription = null;
    _image = null;
    _audio = null;
    return WearableCapture(
      imageBytes: image,
      audioBytes: audio,
      imageContentType: 'image/jpeg',
      audioContentType: 'audio/L8',
    );
  }

  @override
  Future<void> cancelCapture() => _device.sendMessage(
        _singleDataFlag,
        TxCode(value: _stopListeningFlag).pack(),
      );

  @override
  Future<void> showDisplay(WearableDisplayState state) {
    switch (state.mode) {
      case WearableDisplayMode.ready:
        return _sendText(
          state.primaryText ?? 'tap me in',
          emoji: '\u{F0000}',
        );
      case WearableDisplayMode.listening:
        return _sendText(
          state.primaryText ?? 'tap to finish',
          emoji: '\u{F0010}',
        );
      case WearableDisplayMode.thinking:
        return _sendText(
          state.primaryText ??
              '..................... ..................... '
                  '.....................',
        );
      case WearableDisplayMode.reply:
        return _sendText(state.primaryText ?? '', emoji: '\u{F0003}');
      case WearableDisplayMode.disconnected:
        return Future.value();
    }
  }

  Future<void> _sendText(String text, {String? emoji}) => _device.sendMessage(
        _messageResponseFlag,
        TxRichText(text: text, emoji: emoji ?? '').pack(),
      );

  @override
  Future<void> holdDisplay() => _device.sendMessage(
        _singleDataFlag,
        TxCode(value: _holdResponseFlag).pack(),
      );

  @override
  Future<void> stopApplication() => _device.sendBreakSignal();

  @override
  Future<bool> hasCurrentFirmware(WearableSetupMode mode) {
    if (mode == WearableSetupMode.provision) {
      return _device
          .sendString('print(frame.FIRMWARE_VERSION)')
          .timeout(const Duration(seconds: 1))
          .then((version) => version == _firmwareVersion);
    }
    return _readDataVersion(
      flag: _checkFirmwareVersionFlag,
      expectedVersion: _firmwareVersion,
      responseTimeout: const Duration(seconds: 2),
    );
  }

  @override
  Future<bool> hasCurrentApplication() => _readDataVersion(
        flag: _checkScriptVersionFlag,
        expectedVersion: _scriptVersion,
      );

  @override
  Future<void> resumeApplication() async {
    await Future.delayed(const Duration(milliseconds: 800));
    await _device.sendMessage(
      _singleDataFlag,
      TxCode(value: _loopAheadFlag).pack(),
    );
  }

  Future<bool> _readDataVersion({
    required int flag,
    required String expectedVersion,
    Duration? responseTimeout,
  }) async {
    final completer = Completer<bool>();
    late final StreamSubscription<List<int>> subscription;
    Timer? timer;
    subscription = _device.dataResponse.listen((event) {
      if (event.isNotEmpty && event[0] == flag && !completer.isCompleted) {
        completer.complete(utf8.decode(event.sublist(1)) == expectedVersion);
      }
    });
    if (responseTimeout != null) {
      timer = Timer(responseTimeout, () {
        if (!completer.isCompleted) completer.complete(false);
      });
    }
    try {
      await _device
          .sendMessage(_singleDataFlag, TxCode(value: flag).pack())
          .timeout(const Duration(seconds: 1));
      return await completer.future;
    } finally {
      timer?.cancel();
      await subscription.cancel();
    }
  }

  @override
  Future<void> enterFirmwareUpdateMode() => _device.sendString(
        'frame.update()',
        awaitResponse: false,
      );

  @override
  Stream<double> updateFirmware() async* {
    final updater = BrilliantDfuDevice(
      device: _device.device,
      state: BrilliantConnectionState.dfuConnected,
    );
    await updater.connect();
    yield* updater.updateFirmware(
      'assets/frame-firmware-$_firmwareVersion.zip',
    );
  }

  @override
  Stream<double> installApplication() async* {
    final luaFiles = (await AssetManifest.loadFromAssetBundle(rootBundle))
        .listAssets()
        .where((name) => name.endsWith('.lua'))
        .toList();
    for (var index = 0; index < luaFiles.length; index++) {
      final path = luaFiles[index];
      final fileName = path.split('/').last;
      _log.info('Uploading $fileName');
      await _device.uploadScript(fileName, await rootBundle.loadString(path));
      yield (100 / luaFiles.length) * (index + 1);
    }
  }

  @override
  Future<void> resetDevice() => _device.sendResetSignal();

  @override
  Future<void> disconnect() => _device.disconnect();

  @override
  Future<void> dispose() async {
    await _inputSubscription?.cancel();
    _inputSubscription = null;
    await _stringResponseSubscription?.cancel();
    _stringResponseSubscription = null;
    await _photoSubscription?.cancel();
    _photoSubscription = null;
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    _image = null;
    _audio = null;
  }
}
