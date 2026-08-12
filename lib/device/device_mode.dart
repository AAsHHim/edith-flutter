enum DeviceMode {
  hardware,
  simulator;

  static DeviceMode parse(String? value) {
    if (value?.trim().toLowerCase() == simulator.name) {
      return simulator;
    }
    return hardware;
  }

  static DeviceMode get current => parse(
        const String.fromEnvironment(
          'EDITH_DEVICE_MODE',
          defaultValue: 'hardware',
        ),
      );
}
