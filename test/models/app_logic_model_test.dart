import 'package:flutter_test/flutter_test.dart';
import 'package:noa/device/wearable_gateway.dart';
import 'package:noa/device/wearable_models.dart';
import 'package:noa/models/app_logic_model.dart';
import 'package:noa/util/state_machine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('starts in the existing application and device state',
      (tester) async {
    final model = AppLogicModel();

    expect(model.state.current, State.getUserSettings);
    expect(model.frameState, FrameState.disconnected);
    expect(model.deviceName, 'Device');
    expect(model.bluetoothUploadProgress, 0);
    expect(model.scriptProgress, 0);

    await tester.pumpAndSettle();

    expect(model.noaMessages, hasLength(6));
    expect(model.noaMessages.first.message,
        "Hey, I'm EDITH. Let's show you around.");
    expect(model.noaMessages.every((message) => message.exclude), isTrue);
  });

  testWidgets('initialization without login or pairing waits for login',
      (tester) async {
    final model = AppLogicModel();

    model.triggerEvent(Event.init);
    await tester.pumpAndSettle();

    expect(model.state.current, State.waitForLogin);
    expect(model.frameState, FrameState.disconnected);
    expect(model.tuneTemperature, 50);
    expect(model.tuneLength, TuneLength.standard);
    expect(model.textToSpeech, isTrue);
    expect(model.customServer, isFalse);
    expect(model.promptless, isFalse);
  });

  test('exposes the current setup and interaction state vocabulary', () {
    expect(
      State.values,
      containsAll(const [
        State.scanning,
        State.found,
        State.connect,
        State.checkFirmwareVersion,
        State.updateFirmware,
        State.uploadMainLua,
        State.connected,
        State.sendResponseToDevice,
        State.requiresRepair,
        State.disconnected,
      ]),
    );
    expect(
      FrameState.values,
      const [
        FrameState.disconnected,
        FrameState.tapMeIn,
        FrameState.listening,
        FrameState.onit,
        FrameState.printReply,
      ],
    );
  });

  test('represents a discovered device with found state and device name', () {
    final model = AppLogicModel();
    model.deviceName = 'Frame Test';
    model.state = StateMachine(State.found);

    expect(model.state.current, State.found);
    expect(model.deviceName, 'Frame Test');
  });

  testWidgets('failure while stopping the Lua app requires repair',
      (tester) async {
    final model = AppLogicModel(
      wearableSession: _FakeWearableSession([
        WearableSetupUpdate(
          stage: WearableSetupStage.checkingDevice,
          progress: 0,
        ),
        WearableSetupUpdate(
          stage: WearableSetupStage.repairRequired,
          failure: const WearableFailure(
            kind: WearableFailureKind.repairRequired,
          ),
        ),
      ]),
    );
    model.state = StateMachine(State.stopLuaApp);

    model.triggerEvent(Event.init);
    await tester.pumpAndSettle();

    expect(model.state.current, State.requiresRepair);
  });

  testWidgets('application installation failure returns to disconnected',
      (tester) async {
    final model = AppLogicModel(
      wearableSession: _FakeWearableSession([
        WearableSetupUpdate(
          stage: WearableSetupStage.checkingDevice,
          progress: 0,
        ),
        WearableSetupUpdate(
          stage: WearableSetupStage.checkingDevice,
          progress: 0.5,
        ),
        WearableSetupUpdate(
          stage: WearableSetupStage.installingApplication,
          progress: 0,
        ),
        WearableSetupUpdate(
          stage: WearableSetupStage.installingApplication,
          failure: const WearableFailure(
            kind: WearableFailureKind.disconnected,
          ),
        ),
      ]),
    );
    model.state = StateMachine(State.stopLuaApp);

    model.triggerEvent(Event.init);
    await tester.pumpAndSettle();

    expect(model.state.current, State.disconnected);
  });

  testWidgets(
      'successful setup maps progress and persists the stable device id',
      (tester) async {
    final model = AppLogicModel(
      wearableSession: _FakeWearableSession([
        WearableSetupUpdate(
          stage: WearableSetupStage.checkingDevice,
          progress: 0,
        ),
        WearableSetupUpdate(
          stage: WearableSetupStage.checkingDevice,
          progress: 0.5,
        ),
        WearableSetupUpdate(
          stage: WearableSetupStage.installingApplication,
          progress: 0,
        ),
        WearableSetupUpdate(
          stage: WearableSetupStage.installingApplication,
          progress: 0.25,
        ),
        WearableSetupUpdate(
          stage: WearableSetupStage.installingApplication,
          progress: 1,
        ),
        WearableSetupUpdate(
          stage: WearableSetupStage.ready,
          progress: 1,
        ),
      ]),
    );
    model.state = StateMachine(State.stopLuaApp);

    model.triggerEvent(Event.init);
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(model.state.current, State.uploadMainLua);
    expect(model.scriptProgress, 100);
    expect(preferences.getString('PairedDevice'), 'frame-test');
  });

  testWidgets(
      'disconnected state without a paired identifier stays disconnected',
      (tester) async {
    final model = AppLogicModel();
    model.frameState = FrameState.printReply;
    model.state = StateMachine(State.disconnected);

    model.triggerEvent(Event.init);
    await tester.pumpAndSettle();

    expect(model.state.current, State.disconnected);
    expect(model.frameState, FrameState.disconnected);
  });
}

class _FakeWearableSession implements WearableSession {
  _FakeWearableSession(this.updates);

  final List<WearableSetupUpdate> updates;

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
  Stream<WearableInputEvent> get inputEvents => const Stream.empty();

  @override
  Stream<WearableSetupUpdate> setup({
    WearableSetupMode mode = WearableSetupMode.provision,
  }) async* {
    for (final update in updates) {
      await Future<void>.delayed(Duration.zero);
      yield update;
    }
  }

  @override
  Future<void> startCapture() => throw UnimplementedError();

  @override
  Future<WearableCapture> stopCapture() => throw UnimplementedError();

  @override
  Future<void> updateDisplay(WearableDisplayState state) =>
      throw UnimplementedError();

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {}
}
