import 'package:flutter_test/flutter_test.dart';
import 'package:noa/device/device_mode.dart';

void main() {
  group('DeviceMode', () {
    test('defaults to hardware when no value is provided', () {
      expect(DeviceMode.parse(null), DeviceMode.hardware);
      expect(DeviceMode.parse(''), DeviceMode.hardware);
    });

    test('parses an explicit simulator value', () {
      expect(DeviceMode.parse('simulator'), DeviceMode.simulator);
      expect(DeviceMode.parse(' SIMULATOR '), DeviceMode.simulator);
    });

    test('fails safely to hardware for unsupported values', () {
      expect(DeviceMode.parse('frame'), DeviceMode.hardware);
    });

    test('compile-time default is hardware', () {
      expect(DeviceMode.current, DeviceMode.hardware);
    });
  });
}
