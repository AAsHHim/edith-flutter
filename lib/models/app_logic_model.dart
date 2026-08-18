import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:frame_ble/brilliant_bluetooth.dart';
import 'package:frame_ble/brilliant_connection_state.dart';
import 'package:frame_ble/brilliant_device.dart';
import 'package:frame_ble/brilliant_scanned_device.dart';
import 'package:frame_msg/frame_msg.dart';
import 'package:logging/logging.dart';
import 'package:noa/bluetooth.dart';
import 'package:noa/device/brilliant/brilliant_wearable_session.dart';
import 'package:noa/device/wearable_gateway.dart';
import 'package:noa/device/wearable_models.dart';
import 'package:noa/noa_api.dart';
import 'package:noa/util/tx_rich_text.dart';
import 'package:noa/util/state_machine.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = Logger("App logic");

const messageResponseFlag = 0x20;
const imageResponseFlag = 0x21;
const singleDataFlag = 0x22;
const holdResponseFlag = 0x23;
const tapFLag = 0x10;
const stopTapFlag = 0x13;
const startListeningFlag = 0x11;
const stopListeningFlag = 0x12;

enum State {
  getUserSettings,
  waitForLogin,
  scanning,
  found,
  connect,
  stopLuaApp,
  checkFirmwareVersion,
  uploadMainLua,
  uploadGraphicsLua,
  uploadStateLua,
  triggerUpdate,
  updateFirmware,
  requiresRepair,
  connected,
  disconnected,
  recheckFirmwareVersion,
  checkScriptVersion,
  sendResponseToDevice,
  logout,
  deleteAccount,
}

enum Event {
  init,
  done,
  error,
  loggedIn,
  deviceFound,
  deviceLost,
  deviceConnected,
  updatableDeviceConnected,
  deviceDisconnected,
  deviceInvalid,
  buttonPressed,
  cancelPressed,
  logoutPressed,
  deletePressed,
  deviceUpToDate,
  deviceNeedsUpdate,
  noaResponse,
  resetScriptsPressed,
}

enum FrameState {
  disconnected,
  tapMeIn,
  listening,
  onit,
  printReply,
}

enum TuneLength {
  shortest('shortest'),
  short('short'),
  standard('standard'),
  long('long'),
  longest('longest');

  const TuneLength(this.value);
  final String value;
}

class AppLogicModel extends ChangeNotifier {
  // Public state variables
  StateMachine state = StateMachine(State.getUserSettings);
  FrameState frameState = FrameState.disconnected;
  NoaUser noaUser = NoaUser();
  double bluetoothUploadProgress = 0;
  double scriptProgress = 0;
  String deviceName = "Device";
  List<NoaMessage> noaMessages = List.empty(growable: true);

  void setUserAuthToken(String token) {
    SharedPreferences.getInstance().then((value) async {
      await value.setString("userAuthToken", token);
      triggerEvent(Event.loggedIn);
    });
  }

  Future<String?> _getUserAuthToken() async {
    return await SharedPreferences.getInstance()
        .then((value) => value.getString('userAuthToken'));
  }

  void _setPairedDevice(String token) {
    SharedPreferences.getInstance().then((value) async {
      await value.setString("PairedDevice", token);
      triggerEvent(Event.loggedIn);
    });
  }

  Future<String?> _getPairedDevice() async {
    return await SharedPreferences.getInstance()
        .then((value) => value.getString('PairedDevice'));
  }

  // User's tune preferences
  String _tunePrompt = "";
  String get tunePrompt => _tunePrompt;
  set tunePrompt(String value) {
    _tunePrompt = value;
    () async {
      final savedData = await SharedPreferences.getInstance();
      savedData.setString("tunePrompt", _tunePrompt);
    }();
  }

  int _tuneTemperature = 50;
  int get tuneTemperature => _tuneTemperature;
  set tuneTemperature(int value) {
    _tuneTemperature = value;
    () async {
      final savedData = await SharedPreferences.getInstance();
      savedData.setInt("tuneTemperature", _tuneTemperature);
    }();
    notifyListeners();
  }

  bool _customServer = false;
  bool get customServer => _customServer;
  set customServer(bool value) {
    _customServer = value;
    SharedPreferences.getInstance()
        .then((sp) => sp.setBool("customServer", value));
    notifyListeners();
  }

  String _apiEndpoint = "";
  String get apiEndpoint => _apiEndpoint;
  set apiEndpoint(String value) {
    _apiEndpoint = value;
    SharedPreferences.getInstance()
        .then((sp) => sp.setString("apiEndpoint", value));
    notifyListeners();
  }

  String _apiToken = "";
  String get apiToken => _apiToken;
  set apiToken(String value) {
    _apiToken = value;
    SharedPreferences.getInstance()
        .then((sp) => sp.setString("apiToken", value));
    notifyListeners();
  }

  String _apiHeader = "";
  String get apiHeader => _apiHeader;
  set apiHeader(String value) {
    _apiHeader = value;
    SharedPreferences.getInstance()
        .then((sp) => sp.setString("apiHeader", value));
    notifyListeners();
  }

  TuneLength _tuneLength = TuneLength.standard;
  TuneLength get tuneLength => _tuneLength;
  set tuneLength(TuneLength value) {
    _tuneLength = value;
    () async {
      final savedData = await SharedPreferences.getInstance();
      savedData.setString("tuneLength", _tuneLength.name);
    }();
    notifyListeners();
  }

  late bool _textToSpeech;
  bool get textToSpeech => _textToSpeech;
  set textToSpeech(bool value) {
    _textToSpeech = value;
    SharedPreferences.getInstance()
        .then((sp) => sp.setBool("textToSpeech", value));
    notifyListeners();
  }

  late bool _promptless;
  bool get promptless => _promptless;
  set promptless(bool value) {
    _promptless = value;
    SharedPreferences.getInstance()
        .then((sp) => sp.setBool("promptless", value));
    notifyListeners();
  }

  // Private state variables
  StreamSubscription? _scanStream;
  StreamSubscription? _connectionStream;
  StreamSubscription? _luaResponseStream;
  StreamSubscription<WearableSetupUpdate>? _setupSubscription;
  BrilliantScannedDevice? _nearbyDevice;
  BrilliantDevice? _connectedDevice;
  WearableSession? _wearableSession;
  StreamSubscription<int>? _tapSubs;
  bool _setupActive = false;
  bool _restartProvisioningOnSetupDone = false;
  bool _cancelled = false;
  // List<int> _audioData = List.empty(growable: true);
  // List<int> _imageData = List.empty(growable: true);
// Photos: 720px VERY_HIGH quality JPEGs
  static const resolution = 720;
  static const qualityIndex = 4;
  static const qualityLevel = 'HIGH';
  final RxPhoto _rxPhoto =
      RxPhoto(quality: qualityLevel, resolution: resolution);
  Future<Uint8List>? _image;

  final RxAudio _rxAudio = RxAudio(streaming: false);
  Future<Uint8List>? _audio;
  String getTunePrompt() {
    String prompt = "";
    if (_tunePrompt != "") {
      prompt += "$_tunePrompt. ";
    }

    switch (_tuneLength) {
      case TuneLength.shortest:
        prompt += "Limit responses to 1 to 3 words. ";
        break;
      case TuneLength.short:
        prompt += "Limit responses to 1 sentence. ";
        break;
      case TuneLength.standard:
        prompt += "Limit responses to 1 to 2 sentences. ";
        break;
      case TuneLength.long:
        prompt += "Limit responses to 1 short paragraph. ";
        break;
      case TuneLength.longest:
        prompt += "Limit responses to 2 paragraphs. ";
        break;
    }
    return prompt;
  }

  AppLogicModel({WearableSession? wearableSession})
      : _wearableSession = wearableSession {
    // Uncomment to create AppStore images
    // noaMessages.add(NoaMessage(
    //   message: "Recommend me some pizza places I near Union Square",
    //   from: NoaRole.user,
    //   time: DateTime.now().add(const Duration(seconds: 2)),
    // ));

    // noaMessages.add(NoaMessage(
    //   message:
    //       "You might want to check out Bravo Pizza, Union Square Pizza, or Joe's Pizza for some good pizza near Union Square.",
    //   from: NoaRole.noa,
    //   time: DateTime.now().add(const Duration(seconds: 3)),
    // ));

    // noaMessages.add(NoaMessage(
    //   message: "Does Joe's have any good vegetarian options?",
    //   from: NoaRole.user,
    //   time: DateTime.now().add(const Duration(seconds: 4)),
    // ));

    // noaMessages.add(NoaMessage(
    //   message:
    //       "Joe's Pizza does offer vegetarian options, including a cheese-less veggie pie that's quite popular.",
    //   from: NoaRole.noa,
    //   time: DateTime.now().add(const Duration(seconds: 5)),
    // ));

    () async {
      noaMessages.add(NoaMessage(
        message: "Hey, I'm EDITH. Let's show you around.",
        from: NoaRole.noa,
        time: DateTime.now(),
        exclude: true,
      ));

      noaMessages.add(NoaMessage(
          message:
              "Use the assistant control on your connected glasses to wake me.",
          from: NoaRole.noa,
          time: DateTime.now(),
          image: (await rootBundle.load('assets/images/tutorial/wake_up.png'))
              .buffer
              .asUint8List(),
          exclude: true));

      noaMessages.add(NoaMessage(
          message: "When EDITH starts listening, ask me anything.",
          from: NoaRole.noa,
          time: DateTime.now(),
          image: (await rootBundle.load('assets/images/tutorial/tap_start.png'))
              .buffer
              .asUint8List(),
          exclude: true));

      noaMessages.add(NoaMessage(
          message: "Use the assistant control again when you're finished.",
          from: NoaRole.noa,
          time: DateTime.now(),
          image:
              (await rootBundle.load('assets/images/tutorial/tap_finish.png'))
                  .buffer
                  .asUint8List(),
          exclude: true));

      noaMessages.add(NoaMessage(
          message:
              "Your response will appear in a few seconds. Start another interaction to ask a follow-up question.",
          from: NoaRole.noa,
          time: DateTime.now(),
          image: (await rootBundle
                  .load('assets/images/tutorial/tap_follow_up.png'))
              .buffer
              .asUint8List(),
          exclude: true));

      noaMessages.add(NoaMessage(
          message: "Follow-up responses may take a few more seconds.",
          from: NoaRole.noa,
          time: DateTime.now(),
          image: (await rootBundle.load('assets/images/tutorial/response.png'))
              .buffer
              .asUint8List(),
          exclude: true));
    }();
  }

  Future<void> _beginSetup(WearableSetupMode mode) async {
    await _setupSubscription?.cancel();
    _setupActive = true;
    _restartProvisioningOnSetupDone = false;
    _setupSubscription = _wearableSession!.setup(mode: mode).listen(
      _handleSetupUpdate,
      onError: (Object error) {
        _log.warning('Unexpected wearable setup stream error: $error');
        triggerEvent(Event.error);
      },
      onDone: _handleSetupDone,
      cancelOnError: true,
    );
  }

  void _handleSetupUpdate(WearableSetupUpdate update) {
    final failure = update.failure;
    if (failure != null) {
      if (failure.kind == WearableFailureKind.recoverable) {
        _restartProvisioningOnSetupDone = true;
        triggerEvent(Event.deviceNeedsUpdate);
      } else if (state.current == State.connect) {
        triggerEvent(Event.deviceInvalid);
      } else {
        triggerEvent(Event.error);
      }
      return;
    }

    switch (state.current) {
      case State.connect:
        if (update.stage == WearableSetupStage.checkingDevice) {
          triggerEvent(Event.deviceConnected);
        } else if (update.stage == WearableSetupStage.updatingFirmware) {
          triggerEvent(Event.updatableDeviceConnected);
        }
        break;
      case State.stopLuaApp:
        if (update.stage == WearableSetupStage.checkingDevice &&
            (update.progress ?? 0) >= 0.5) {
          triggerEvent(Event.done);
        }
        break;
      case State.checkFirmwareVersion:
        if (update.stage == WearableSetupStage.installingApplication) {
          triggerEvent(Event.deviceUpToDate);
        } else if (update.stage == WearableSetupStage.updatingFirmware) {
          triggerEvent(Event.deviceNeedsUpdate);
        }
        break;
      case State.uploadMainLua:
        if (update.stage == WearableSetupStage.installingApplication) {
          scriptProgress = (update.progress ?? 0) * 100;
        } else if (update.isReady) {
          _setPairedDevice(_wearableSession!.descriptor.stableId);
        }
        break;
      case State.updateFirmware:
        if (update.stage == WearableSetupStage.updatingFirmware) {
          bluetoothUploadProgress = (update.progress ?? 0) * 100;
        }
        break;
      case State.recheckFirmwareVersion:
        if (update.stage == WearableSetupStage.checkingDevice &&
            (update.progress ?? 0) >= 0.5) {
          triggerEvent(Event.deviceUpToDate);
        }
        break;
      case State.checkScriptVersion:
        if (update.isReady) {
          triggerEvent(Event.deviceUpToDate);
        }
        break;
      default:
        break;
    }
    notifyListeners();
  }

  void _handleSetupDone() {
    _setupActive = false;
    _setupSubscription = null;
    if (state.current == State.triggerUpdate ||
        state.current == State.updateFirmware) {
      _startSetupScan();
    } else if (_restartProvisioningOnSetupDone &&
        state.current == State.stopLuaApp) {
      _beginSetup(WearableSetupMode.provision);
    }
  }

  Future<void> _startSetupScan() async {
    try {
      await _scanStream?.cancel();
      _scanStream = BrilliantBluetooth.scan().listen((device) {
        _nearbyDevice = device;
        triggerEvent(Event.deviceFound);
      });
    } catch (error) {
      triggerEvent(Event.error);
    }
  }

  void triggerEvent(Event event) {
    state.event(event);

    do {
      switch (state.current) {
        case State.getUserSettings:
          state.onEntry(() async {
            try {
              // Load the user's Tune settings or defaults if none are set
              final savedData = await SharedPreferences.getInstance();
              _tunePrompt = savedData.getString('tunePrompt') ??
                  "You are EDITH, a smart, concise, and helpful personal AI assistant inside the user's AR smart glasses. Your name is EDITH. You assist the user with questions, visual context, tasks, and information. Keep responses clear and useful for a wearable display.";
              _tuneTemperature = savedData.getInt('tuneTemperature') ?? 50;
              var len = savedData.getString('tuneLength') ?? 'standard';
              _tuneLength = TuneLength.values
                  .firstWhere((e) => e.toString() == 'TuneLength.$len');
              _textToSpeech = savedData.getBool('textToSpeech') ?? true;
              _apiEndpoint = savedData.getString('apiEndpoint') ?? "";
              _apiToken = savedData.getString('apiToken') ?? "";
              _apiHeader = savedData.getString('apiHeader') ?? "";
              _customServer = savedData.getBool('customServer') ?? false;
              _promptless = savedData.getBool('promptless') ?? false;

              // Check if the auto token is loaded and if Frame is paired
              if (await _getUserAuthToken() != null &&
                  await _getPairedDevice() != null) {
                noaUser = await NoaApi.getUser((await _getUserAuthToken())!);
                triggerEvent(Event.done);
                return;
              }
              throw ("Not logged in or paired");
            } catch (error) {
              _log.info(error);
              triggerEvent(Event.error);
            }
          });
          state.changeOn(Event.done, State.disconnected);
          state.changeOn(Event.error, State.waitForLogin);
          break;

        case State.waitForLogin:
          state.changeOn(Event.loggedIn, State.scanning,
              transitionTask: () async =>
                  noaUser = await NoaApi.getUser((await _getUserAuthToken())!));
          break;

        case State.scanning:
          state.onEntry(() async {
            await _scanStream?.cancel();
            _scanStream = BrilliantBluetooth.scan().listen((device) {
              _nearbyDevice = device;
              deviceName = device.device.advName;
              triggerEvent(Event.deviceFound);
            });
          });
          state.changeOn(Event.deviceFound, State.found);
          state.changeOn(Event.cancelPressed, State.disconnected,
              transitionTask: () async => await BrilliantBluetooth.stopScan());
          break;

        case State.found:
          state.changeOn(Event.deviceLost, State.scanning);
          state.changeOn(Event.buttonPressed, State.connect);
          state.changeOn(Event.cancelPressed, State.disconnected,
              transitionTask: () async => await BrilliantBluetooth.stopScan());
          break;

        case State.connect:
          state.onEntry(() async {
            try {
              _connectedDevice =
                  await BrilliantBluetooth.connect(_nearbyDevice!);
              _wearableSession = BrilliantWearableSession(_connectedDevice!);
              await _beginSetup(WearableSetupMode.provision);
            } catch (error) {
              var list_of_devices = FlutterBluePlus.connectedDevices;
              _log.warning(
                  "Error connecting to device. $error. List of devices: $list_of_devices");
              triggerEvent(Event.deviceInvalid);
            }
          });
          state.changeOn(Event.deviceConnected, State.stopLuaApp);
          state.changeOn(Event.updatableDeviceConnected, State.updateFirmware);
          state.changeOn(Event.deviceInvalid, State.requiresRepair);
          break;

        case State.stopLuaApp:
          state.onEntry(() async {
            if (!_setupActive) {
              await _beginSetup(WearableSetupMode.provision);
            }
          });
          state.changeOn(Event.done, State.checkFirmwareVersion);
          state.changeOn(Event.error, State.requiresRepair);
          break;

        case State.checkFirmwareVersion:
          state.changeOn(Event.deviceUpToDate, State.uploadMainLua);
          state.changeOn(Event.deviceNeedsUpdate, State.triggerUpdate);
          state.changeOn(Event.error, State.requiresRepair);
          break;

        case State.uploadMainLua:
          state.changeOn(Event.error, State.disconnected);
          break;

        case State.triggerUpdate:
          state.changeOn(Event.deviceFound, State.connect,
              transitionTask: () async => await BrilliantBluetooth.stopScan());
          state.changeOn(Event.error, State.disconnected);
          break;

        case State.updateFirmware:
          state.changeOn(Event.deviceFound, State.connect);
          state.changeOn(Event.error, State.disconnected);
          break;

        case State.requiresRepair:
          state.changeOn(Event.buttonPressed, State.scanning);
          state.changeOn(Event.cancelPressed, State.disconnected);
          break;

        case State.connected:
          state.onEntry(() async {
            _connectionStream?.cancel();
            _connectionStream =
                _connectedDevice!.connectionState.listen((event) {
              _connectedDevice = event;
              if (event.state == BrilliantConnectionState.disconnected) {
                triggerEvent(Event.deviceDisconnected);
              }
            });
            _connectionStream?.onError((_) {});
            _luaResponseStream?.cancel();
            _luaResponseStream =
                _connectedDevice!.stringResponse.listen((event) async {});
            // wait for the device to be ready
            await Future.delayed(const Duration(milliseconds: 800));
            _connectedDevice!
                .sendMessage(singleDataFlag, TxCode(value: stopTapFlag).pack());
            _tapSubs?.cancel();
            _tapSubs = RxTap(
                    tapFlag: tapFLag,
                    threshold: const Duration(milliseconds: 200))
                .attach(_connectedDevice!.dataResponse)
                .listen((taps) async {
              if (taps == 1) {
                if (frameState == FrameState.tapMeIn) {
                  // STEP 2: LISTENING
                  frameState = FrameState.listening;
                  _log.info("Listening");
                  await _connectedDevice!.sendMessage(
                      messageResponseFlag,
                      TxRichText(text: "tap to finish", emoji: "\u{F0010}")
                          .pack());
                  _cancelled = false;
                  if (_cancelled) return;
                  _image =
                      _rxPhoto.attach(_connectedDevice!.dataResponse).first;
                  _audio =
                      _rxAudio.attach(_connectedDevice!.dataResponse).first;
                  await _connectedDevice!.sendMessage(
                      startListeningFlag,
                      TxCaptureSettings(
                              resolution: resolution,
                              qualityIndex: qualityIndex)
                          .pack());
                } else if (frameState == FrameState.listening && !_cancelled) {
                  // STEP 3: ON IT
                  frameState = FrameState.onit;
                  _log.info("On it");
                  _connectedDevice!.sendMessage(
                      singleDataFlag, TxCode(value: stopListeningFlag).pack());
                  await _connectedDevice!.sendMessage(
                      messageResponseFlag,
                      TxRichText(
                              text:
                                  "..................... ..................... .....................")
                          .pack());
                  if (_cancelled) return;
                  var image = await _image;
                  var audio = await _audio;
                  _log.info(
                      "Image: ${image?.length} bytes,  Audio: ${audio?.length} bytes");

                  if (_cancelled) return;
                  // to avoid fram being sleep while waiting for the response
                  Future.delayed(const Duration(seconds: 5), () async {
                    await _connectedDevice!.sendMessage(
                        singleDataFlag, TxCode(value: holdResponseFlag).pack());
                  });
                  final newMessages = await NoaApi.getMessage(
                      (await _getUserAuthToken())!,
                      audio!,
                      image!,
                      getTunePrompt(),
                      _tuneTemperature / 50,
                      noaMessages,
                      textToSpeech,
                      apiEndpoint,
                      apiHeader,
                      apiToken,
                      customServer,
                      promptless);
                  final topicChanged =
                      newMessages.where((msg) => msg.topicChanged).isNotEmpty;
                  if (topicChanged) {
                    for (var msg in noaMessages) {
                      msg.exclude = true;
                    }
                  }
                  if (_cancelled) return;
                  noaMessages += newMessages;
                  noaUser = await NoaApi.getUser((await _getUserAuthToken())!);

                  if (_cancelled) return;
                  triggerEvent(Event.noaResponse);
                  image = null;
                  _image = null;
                  _audio = null;
                }
              } else if (taps == 2) {
                _log.info("Cancelled");
                await _connectedDevice!.sendMessage(messageResponseFlag,
                    TxRichText(text: "tap me in", emoji: "\u{F0000}").pack());
                _connectedDevice!.sendMessage(
                    singleDataFlag, TxCode(value: stopListeningFlag).pack());
                _cancelled = true;
                frameState = FrameState.tapMeIn;
              }
            });
            _connectedDevice!
                .sendMessage(singleDataFlag, TxCode(value: tapFLag).pack());
            // STEP 1: TAP ME IN
            // if its coming from disconnected state immediately show tap me in, if its coming from print reply wait for 5 seconds
            if (frameState == FrameState.printReply) {
              Future.delayed(const Duration(seconds: 10), () async {
                await _connectedDevice!.sendMessage(messageResponseFlag,
                    TxRichText(text: "tap me in", emoji: "\u{F0000}").pack());
                frameState = FrameState.tapMeIn;
              });
            } else {
              await _connectedDevice!.sendMessage(messageResponseFlag,
                  TxRichText(text: "tap me in", emoji: "\u{F0000}").pack());
              frameState = FrameState.tapMeIn;
            }
          });
          state.changeOn(Event.noaResponse, State.sendResponseToDevice);
          state.changeOn(Event.deviceDisconnected, State.disconnected);
          state.changeOn(Event.logoutPressed, State.logout);
          state.changeOn(Event.deletePressed, State.deleteAccount);
          state.changeOn(Event.resetScriptsPressed, State.stopLuaApp);
          break;

        case State.sendResponseToDevice:
          state.onEntry(() async {
            try {
              await _connectedDevice!.sendMessage(
                  messageResponseFlag,
                  TxRichText(text: noaMessages.last.message, emoji: "\u{F0003}")
                      .pack());
              frameState = FrameState.printReply;
              await Future.delayed(const Duration(milliseconds: 800));
            } catch (_) {}
            triggerEvent(Event.done);
          });

          state.changeOn(Event.done, State.connected);
          state.changeOn(Event.logoutPressed, State.logout);
          state.changeOn(Event.deletePressed, State.deleteAccount);
          state.changeOn(Event.resetScriptsPressed, State.stopLuaApp);
          break;

        case State.disconnected:
          frameState = FrameState.disconnected;
          state.onEntry(() async {
            _connectionStream?.cancel();
            _connectionStream =
                _connectedDevice?.connectionState.listen((event) async {
              _connectedDevice = event;
              if (event.state == BrilliantConnectionState.connected) {
                _wearableSession = BrilliantWearableSession(event);
                triggerEvent(Event.deviceConnected);
              }
            });

            _connectionStream?.onError((_) {});

            try {
              _connectedDevice ??= await BrilliantBluetooth.reconnect(
                  (await _getPairedDevice())!);
            } catch (error) {
              _log.warning("Error reconnecting to device. $error");
            }
            if (_connectedDevice?.state == BrilliantConnectionState.connected) {
              _wearableSession = BrilliantWearableSession(_connectedDevice!);
              triggerEvent(Event.deviceConnected);
            }
          });
          state.changeOn(Event.deviceConnected, State.recheckFirmwareVersion);
          state.changeOn(Event.logoutPressed, State.logout);
          state.changeOn(Event.deletePressed, State.deleteAccount);
          break;

        case State.recheckFirmwareVersion:
          state.onEntry(() async {
            await _beginSetup(WearableSetupMode.validate);
          });

          state.changeOn(Event.deviceUpToDate, State.checkScriptVersion);
          state.changeOn(Event.deviceNeedsUpdate, State.stopLuaApp);
          state.changeOn(Event.error, State.stopLuaApp);
          state.changeOn(Event.logoutPressed, State.logout);
          state.changeOn(Event.resetScriptsPressed, State.stopLuaApp);
          break;

        case State.checkScriptVersion:
          state.changeOn(Event.deviceUpToDate, State.connected);
          state.changeOn(Event.deviceNeedsUpdate, State.stopLuaApp);
          state.changeOn(Event.error, State.stopLuaApp);
          state.changeOn(Event.logoutPressed, State.logout);
          break;

        case State.logout:
          state.onEntry(() async {
            try {
              await SharedPreferences.getInstance().then((sp) => sp.clear());
              await _connectedDevice?.disconnect();
              await NoaApi.signOut((await _getUserAuthToken())!);
              noaMessages.clear();
              triggerEvent(Event.done);
            } catch (error) {
              _log.warning("Error logging out. $error");
              triggerEvent(Event.done);
            }
          });
          state.changeOn(Event.done, State.getUserSettings);
          break;

        case State.deleteAccount:
          state.onEntry(() async {
            try {
              await _connectedDevice?.disconnect();
              await NoaApi.deleteUser((await _getUserAuthToken())!);
              await SharedPreferences.getInstance().then((sp) => sp.clear());
              noaMessages.clear();
              triggerEvent(Event.done);
            } catch (error) {
              _log.warning("Error deleting account. $error");
              triggerEvent(Event.done);
            }
          });
          state.changeOn(Event.done, State.getUserSettings);
          break;
      }
    } while (state.changePending());

    notifyListeners();
  }

  @override
  void dispose() {
    BrilliantBluetooth.stopScan();
    _scanStream?.cancel();
    _connectionStream?.cancel();
    _luaResponseStream?.cancel();
    _setupSubscription?.cancel();
    _tapSubs?.cancel();
    _wearableSession?.dispose();

    super.dispose();
  }
}

final model = ChangeNotifierProvider<AppLogicModel>((ref) {
  return AppLogicModel();
});
