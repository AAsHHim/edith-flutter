import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../device/device_providers.dart';
import '../device/simulator/halo_simulator_controller.dart';
import '../device/simulator/simulated_wearable_gateway.dart';
import '../device/wearable_models.dart';
import '../style.dart';

class HaloSimulatorPage extends ConsumerWidget {
  const HaloSimulatorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(haloSimulatorControllerProvider);
    return StreamBuilder<void>(
      stream: controller.changes,
      builder: (context, _) => Scaffold(
        backgroundColor: EdithColors.background,
        appBar: AppBar(
          backgroundColor: EdithColors.background,
          foregroundColor: EdithColors.primaryAccent,
          surfaceTintColor: Colors.transparent,
          title: const Text('HALO SIMULATOR', style: EdithTextStyles.title),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: HaloDisplayPreview(
                    state: _visibleDisplayState(controller),
                  ),
                ),
                const SizedBox(height: 24),
                _StatusSection(controller: controller),
                const SizedBox(height: 20),
                _Section(
                  title: 'INPUT',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ControlButton(
                        key: const Key('halo-primary'),
                        label: 'Primary',
                        onPressed: controller.injectPrimary,
                      ),
                      _ControlButton(
                        key: const Key('halo-cancel'),
                        label: 'Cancel',
                        onPressed: controller.injectCancel,
                      ),
                      _ControlButton(
                        key: const Key('halo-secondary'),
                        label: 'Secondary',
                        onPressed: controller.injectSecondary,
                      ),
                      _ControlButton(
                        key: const Key('halo-single-press'),
                        label: 'Single Press',
                        onPressed: () => controller.injectPrimary(
                          press: SimulatedPressKind.single,
                        ),
                      ),
                      _ControlButton(
                        key: const Key('halo-double-press'),
                        label: 'Double Press',
                        onPressed: () => controller.injectPrimary(
                          press: SimulatedPressKind.double,
                        ),
                      ),
                      _ControlButton(
                        key: const Key('halo-long-press'),
                        label: 'Long Press',
                        onPressed: () => controller.injectPrimary(
                          press: SimulatedPressKind.long,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _FixtureSection(controller: controller),
                const SizedBox(height: 16),
                _Section(
                  title: 'CONNECTION',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ControlButton(
                        key: const Key('halo-disconnect'),
                        label: 'Disconnect',
                        onPressed: controller.triggerDisconnect,
                        destructive: true,
                      ),
                      _ControlButton(
                        key: const Key('halo-reset'),
                        label: 'Reset Simulator',
                        onPressed: controller.reset,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _EventLog(events: controller.eventHistory),
              ],
            ),
          ),
        ),
      ),
    );
  }

  WearableDisplayState _visibleDisplayState(
    HaloSimulatorController controller,
  ) {
    if (controller.connectionStatus != WearableConnectionStatus.connected) {
      return const WearableDisplayState(
        mode: WearableDisplayMode.disconnected,
      );
    }
    return controller.latestDisplayState ??
        const WearableDisplayState(mode: WearableDisplayMode.ready);
  }
}

class HaloDisplayPreview extends StatelessWidget {
  const HaloDisplayPreview({
    required this.state,
    super.key,
  });

  final WearableDisplayState state;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      key: const Key('halo-preview'),
      dimension: 256,
      child: ClipOval(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: EdithColors.background,
            shape: BoxShape.circle,
            border: Border.all(
              color: EdithColors.primaryAccent,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3327E5FF),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(38),
            child: Center(child: _DisplayContent(state: state)),
          ),
        ),
      ),
    );
  }
}

class _DisplayContent extends StatelessWidget {
  const _DisplayContent({required this.state});

  final WearableDisplayState state;

  @override
  Widget build(BuildContext context) {
    switch (state.mode) {
      case WearableDisplayMode.ready:
        return const _Indicator(
          key: Key('halo-mode-ready'),
          icon: Icons.adjust,
          label: 'EDITH READY',
          color: EdithColors.success,
        );
      case WearableDisplayMode.listening:
        return const _Indicator(
          key: Key('halo-mode-listening'),
          icon: Icons.graphic_eq,
          label: 'LISTENING',
          color: EdithColors.primaryAccent,
        );
      case WearableDisplayMode.thinking:
        return const _Indicator(
          key: Key('halo-mode-thinking'),
          icon: Icons.more_horiz,
          label: 'PROCESSING',
          color: EdithColors.secondaryAccent,
        );
      case WearableDisplayMode.reply:
        return Text(
          state.primaryText ?? '',
          key: const Key('halo-mode-reply'),
          maxLines: 8,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          textAlign: TextAlign.center,
          style: EdithTextStyles.body.copyWith(height: 1.25),
        );
      case WearableDisplayMode.disconnected:
        return const _Indicator(
          key: Key('halo-mode-disconnected'),
          icon: Icons.link_off,
          label: 'DISCONNECTED',
          color: EdithColors.error,
        );
    }
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.icon,
    required this.label,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: color),
        const SizedBox(height: 12),
        Text(
          label,
          textAlign: TextAlign.center,
          style: EdithTextStyles.subheading.copyWith(color: color),
        ),
      ],
    );
  }
}

class _StatusSection extends StatelessWidget {
  const _StatusSection({required this.controller});

  final HaloSimulatorController controller;

  @override
  Widget build(BuildContext context) {
    final setup = controller.latestSetupUpdate;
    return _Section(
      title: 'STATUS',
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          _StatusValue('DEVICE', simulatedWearableDescriptor.displayName),
          _StatusValue('CONNECTION', controller.connectionStatus.name),
          _StatusValue(
            'DISPLAY',
            controller.latestDisplayState?.mode.name ?? 'none',
          ),
          _StatusValue(
            'CAPTURE',
            controller.captureActive ? 'active' : 'inactive',
          ),
          _StatusValue('HOLDS', '${controller.holdRequestCount}'),
          _StatusValue('SETUP', setup?.stage.name ?? 'not started'),
        ],
      ),
    );
  }
}

class _FixtureSection extends StatelessWidget {
  const _FixtureSection({required this.controller});

  final HaloSimulatorController controller;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'CAPTURE FIXTURES',
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          _StatusValue(
            'IMAGE',
            _fixtureStatus(controller.imageFixture.length),
          ),
          _StatusValue(
            'AUDIO',
            _fixtureStatus(controller.audioFixture.length),
          ),
        ],
      ),
    );
  }

  String _fixtureStatus(int byteCount) =>
      byteCount == 0 ? 'not configured' : '$byteCount bytes';
}

class _StatusValue extends StatelessWidget {
  const _StatusValue(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: EdithTextStyles.navigationLabel),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EdithTextStyles.body,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: EdithColors.surface,
        border: Border.all(color: EdithColors.elevatedSurface),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: EdithTextStyles.subheading),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.label,
    required this.onPressed,
    this.destructive = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? EdithColors.error : EdithColors.primaryAccent;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
      ),
      child: Text(label),
    );
  }
}

class _EventLog extends StatelessWidget {
  const _EventLog({required this.events});

  final List<String> events;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'EVENT HISTORY',
      child: SizedBox(
        key: const Key('halo-event-history'),
        height: 180,
        child: events.isEmpty
            ? const Center(
                child: Text(
                  'No simulator events yet.',
                  style: EdithTextStyles.secondaryBody,
                ),
              )
            : ListView.builder(
                itemCount: events.length,
                reverse: true,
                itemBuilder: (context, index) {
                  final event = events[events.length - index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      event,
                      style: EdithTextStyles.secondaryBody,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
