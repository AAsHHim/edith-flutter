import 'dart:async';

import 'package:frame_ble/brilliant_bluetooth.dart';
import 'package:frame_ble/brilliant_connection_state.dart';
import 'package:frame_ble/brilliant_scanned_device.dart';
import 'package:noa/device/brilliant/brilliant_wearable_session.dart';
import 'package:noa/device/wearable_gateway.dart';
import 'package:noa/device/wearable_models.dart';

class BrilliantDiscoveryResult {
  const BrilliantDiscoveryResult({
    required this.stableId,
    required this.displayName,
  });

  final String stableId;
  final String displayName;
}

abstract interface class BrilliantGatewayOperations {
  Future<void> requestPermissions();

  Stream<BrilliantDiscoveryResult> scan();

  Future<void> stopScan();

  Future<WearableSession> connect(String stableId);

  Future<WearableSession> reconnect(String stableId);

  Future<void> dispose();
}

class BrilliantWearableGateway implements WearableGateway {
  BrilliantWearableGateway()
      : this.withOperations(_BrilliantBluetoothOperations());

  BrilliantWearableGateway.withOperations(this._operations);

  final BrilliantGatewayOperations _operations;
  final Map<String, WearableDescriptor> _discovered = {};
  final Map<String, WearableSession> _sessions = {};
  final Map<String, Future<WearableSession>> _pendingConnections = {};
  bool _disposed = false;

  @override
  Future<void> requestPermissions() async {
    _ensureActive();
    try {
      await _operations.requestPermissions();
    } catch (error) {
      throw WearableGatewayException(
        WearableGatewayFailureKind.permission,
        error.toString(),
      );
    }
  }

  @override
  Stream<WearableDescriptor> discover() async* {
    _ensureActive();
    try {
      await for (final result in _operations.scan()) {
        final descriptor = WearableDescriptor(
          stableId: result.stableId,
          displayName: result.displayName,
          transport: WearableTransport.bluetoothLowEnergy,
          capabilities: const {
            WearableCapability.display,
            WearableCapability.camera,
            WearableCapability.microphone,
            WearableCapability.primaryInput,
            WearableCapability.multiClickInput,
          },
        );
        _discovered[result.stableId] = descriptor;
        yield descriptor;
      }
    } catch (error) {
      if (error is WearableGatewayException) rethrow;
      throw WearableGatewayException(
        WearableGatewayFailureKind.discovery,
        error.toString(),
      );
    }
  }

  @override
  Future<void> stopDiscovery() async {
    _ensureActive();
    try {
      await _operations.stopScan();
    } catch (error) {
      throw WearableGatewayException(
        WearableGatewayFailureKind.discovery,
        error.toString(),
      );
    }
  }

  @override
  Future<WearableSession> connect(WearableDescriptor descriptor) {
    _ensureActive();
    if (!_discovered.containsKey(descriptor.stableId)) {
      return Future.error(
        WearableGatewayException(
          WearableGatewayFailureKind.connection,
          'Wearable ${descriptor.stableId} was not discovered.',
        ),
      );
    }
    final existing = _sessions[descriptor.stableId];
    if (existing != null) return Future.value(existing);
    return _pendingConnections.putIfAbsent(
      descriptor.stableId,
      () => _connect(descriptor.stableId),
    );
  }

  Future<WearableSession> _connect(String stableId) async {
    try {
      final session = await _operations.connect(stableId);
      _sessions[stableId] = session;
      return session;
    } catch (error) {
      throw WearableGatewayException(
        WearableGatewayFailureKind.connection,
        error.toString(),
      );
    } finally {
      _pendingConnections.remove(stableId);
    }
  }

  @override
  Future<WearableSession> reconnect(String stableId) async {
    _ensureActive();
    try {
      final session = await _operations.reconnect(stableId);
      _sessions[stableId] = session;
      return session;
    } catch (error) {
      throw WearableGatewayException(
        WearableGatewayFailureKind.reconnection,
        error.toString(),
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _operations.dispose();
    _discovered.clear();
    _sessions.clear();
    _pendingConnections.clear();
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('BrilliantWearableGateway has been disposed.');
    }
  }
}

class _BrilliantBluetoothOperations implements BrilliantGatewayOperations {
  final Map<String, BrilliantScannedDevice> _scannedDevices = {};

  @override
  Future<void> requestPermissions() => BrilliantBluetooth.requestPermission();

  @override
  Stream<BrilliantDiscoveryResult> scan() async* {
    await for (final scannedDevice in BrilliantBluetooth.scan()) {
      final stableId = scannedDevice.device.remoteId.toString();
      _scannedDevices[stableId] = scannedDevice;
      yield BrilliantDiscoveryResult(
        stableId: stableId,
        displayName: scannedDevice.device.advName,
      );
    }
  }

  @override
  Future<void> stopScan() => BrilliantBluetooth.stopScan();

  @override
  Future<WearableSession> connect(String stableId) async {
    final scannedDevice = _scannedDevices[stableId];
    if (scannedDevice == null) {
      throw StateError('No Brilliant scan result for $stableId.');
    }
    final device = await BrilliantBluetooth.connect(scannedDevice);
    return BrilliantWearableSession(device);
  }

  @override
  Future<WearableSession> reconnect(String stableId) async {
    final device = await BrilliantBluetooth.reconnect(stableId);
    if (device.state != BrilliantConnectionState.connected) {
      await device.disconnect();
      throw StateError('Reconnected Brilliant device is not ready.');
    }
    return BrilliantWearableSession(device);
  }

  @override
  Future<void> dispose() async {
    await BrilliantBluetooth.stopScan();
    _scannedDevices.clear();
  }
}
