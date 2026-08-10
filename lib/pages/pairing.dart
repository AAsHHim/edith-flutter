import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:noa/models/app_logic_model.dart' as app;
import 'package:noa/pages/noa.dart';
import 'package:noa/style.dart';
import 'package:noa/util/switch_page.dart';

class PairingPage extends ConsumerWidget {
  const PairingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.watch(app.model).state.current == app.State.connected ||
          ref.watch(app.model).state.current == app.State.disconnected) {
        switchPage(context, const NoaPage());
      }
    });

    String pairingBoxText = "";
    String pairingBoxButtonText = "";
    Image pairingBoxImage = Image.asset('assets/images/charge.gif');
    bool pairingBoxButtonEnabled = false;
    int updateProgress = ref.watch(app.model).bluetoothUploadProgress.toInt();
    int scriptProgress = ref.watch(app.model).scriptProgress.toInt();
    String deviceName = ref.watch(app.model).deviceName;

    switch (ref.watch(app.model).state.current) {
      case app.State.scanning:
        pairingBoxText = "Bring your device close";
        pairingBoxButtonText = "Searching";
        pairingBoxImage = Image.asset('assets/images/charge.gif');
        pairingBoxButtonEnabled = false;
        break;
      case app.State.found:
        pairingBoxText = "$deviceName found";
        pairingBoxButtonText = "Pair";
        pairingBoxImage = Image.asset('assets/images/charge.gif');
        pairingBoxButtonEnabled = true;
        break;
      case app.State.connect:
      case app.State.stopLuaApp:
      case app.State.checkFirmwareVersion:
      case app.State.triggerUpdate:
        pairingBoxText = "$deviceName found";
        pairingBoxButtonText = "Connecting";
        pairingBoxImage = Image.asset('assets/images/charge.gif');
        pairingBoxButtonEnabled = false;
        break;
      case app.State.updateFirmware:
        pairingBoxText = "Updating software $updateProgress%";
        pairingBoxButtonText = "Keep your device close";
        pairingBoxImage = Image.asset('assets/images/charge.gif');
        pairingBoxButtonEnabled = false;
        break;
      case app.State.uploadMainLua:
        pairingBoxText = "Setting up EDITH $scriptProgress%";
        pairingBoxButtonText = "Keep your device close";
        pairingBoxImage = Image.asset('assets/images/charge.gif');
        pairingBoxButtonEnabled = false;
        break;
      case app.State.uploadGraphicsLua:
        pairingBoxText = "Setting up EDITH 68%";
        pairingBoxButtonText = "Keep your device close";
        pairingBoxImage = Image.asset('assets/images/charge.gif');
        pairingBoxButtonEnabled = false;
        break;
      case app.State.uploadStateLua:
        pairingBoxText = "Setting up EDITH 83%";
        pairingBoxButtonText = "Keep your device close";
        pairingBoxImage = Image.asset('assets/images/charge.gif');
        pairingBoxButtonEnabled = false;
        break;
      case app.State.requiresRepair:
        pairingBoxText = "Un-pair Frame first";
        pairingBoxButtonText = "Try again";
        pairingBoxImage = Image.asset('assets/images/repair.gif');
        pairingBoxButtonEnabled = true;
        break;
    }

    return Scaffold(
      backgroundColor: EdithColors.background,
      appBar: AppBar(
        backgroundColor: EdithColors.background,
        foregroundColor: EdithColors.primaryText,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('EDITH', style: EdithTextStyles.title),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const Expanded(
            child: Center(
              child: Text(
                "SET UP YOUR DEVICE",
                style: EdithTextStyles.heading,
              ),
            ),
          ),
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              margin: const EdgeInsets.only(bottom: 22, left: 20, right: 20),
              decoration: const BoxDecoration(
                color: EdithColors.surface,
                border: Border.fromBorderSide(
                  BorderSide(color: EdithColors.elevatedSurface),
                ),
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20, right: 20),
                      child: GestureDetector(
                        onTap: () {
                          ref
                              .read(app.model)
                              .triggerEvent(app.Event.cancelPressed);
                        },
                        child: const Icon(
                          Icons.cancel,
                          color: EdithColors.primaryAccent,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    pairingBoxText,
                    style: const TextStyle(
                      fontFamily: EdithTextStyles.fontFamily,
                      color: EdithColors.primaryText,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(12),
                        ),
                        child: ColoredBox(
                          color: EdithColors.primaryText,
                          child: pairingBoxImage,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ref.read(app.model).triggerEvent(app.Event.buttonPressed);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: pairingBoxButtonEnabled
                            ? EdithColors.primaryAccent
                            : EdithColors.elevatedSurface,
                        border: Border.all(
                          color: pairingBoxButtonEnabled
                              ? EdithColors.primaryAccent
                              : EdithColors.disabled,
                        ),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(20)),
                      ),
                      height: 50,
                      margin: const EdgeInsets.only(
                          left: 31, right: 31, bottom: 28),
                      child: Center(
                        child: Text(
                          pairingBoxButtonText,
                          style: pairingBoxButtonEnabled
                              ? EdithTextStyles.selectedNavigationLabel
                              : EdithTextStyles.navigationLabel,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
