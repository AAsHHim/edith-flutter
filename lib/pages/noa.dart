import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:noa/main.dart';
import 'package:noa/models/app_logic_model.dart' as app;
import 'package:noa/noa_api.dart';
import 'package:noa/pages/pairing.dart';
import 'package:noa/style.dart';
import 'package:noa/util/show_toast.dart';
import 'package:noa/util/switch_page.dart';
import 'package:noa/widgets/bottom_nav_bar.dart';
import 'package:noa/widgets/top_title_bar.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:uuid/uuid.dart';

class NoaPage extends ConsumerStatefulWidget {
  const NoaPage({super.key});

  @override
  ConsumerState<NoaPage> createState() => _NoaPageState();
}

class _NoaPageState extends ConsumerState<NoaPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (ref.watch(app.model).state.current) {
        case app.State.stopLuaApp:
        case app.State.checkFirmwareVersion:
        case app.State.uploadMainLua:
        case app.State.uploadGraphicsLua:
        case app.State.uploadStateLua:
        case app.State.triggerUpdate:
        case app.State.updateFirmware:
          switchPage(context, const PairingPage());
          break;
        default:
      }
      Timer(const Duration(milliseconds: 100), () {
        if (context.mounted) {
          ref.watch(app.model.select((value) {
            if (value.noaMessages.length > 6) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
              );
            }
          }));
        }
      });
    });

    return Scaffold(
      backgroundColor: EdithColors.background,
      appBar: topTitleBar(context, 'EDITH', true, false),
      body: PageStorage(
        bucket: globalPageStorageBucket,
        child: ListView.builder(
          key: const PageStorageKey<String>('noaPage'),
          controller: _scrollController,
          itemCount: ref.watch(app.model).noaMessages.length,
          itemBuilder: (context, index) {
            final message = ref.watch(app.model).noaMessages[index];
            final isAssistant = message.from == NoaRole.noa;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (index == 0 ||
                    message.time
                            .difference(ref
                                .watch(app.model)
                                .noaMessages[index - 1]
                                .time)
                            .inSeconds >
                        1700)
                  Container(
                    margin: const EdgeInsets.only(top: 28, left: 42, right: 42),
                    child: Row(
                      children: [
                        Text(
                          "${message.time.hour.toString().padLeft(2, '0')}:${message.time.minute.toString().padLeft(2, '0')}",
                          style: EdithTextStyles.navigationLabel,
                        ),
                        const Flexible(
                          child: Divider(
                            indent: 10,
                            color: EdithColors.elevatedSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 10, left: 42, right: 42),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isAssistant
                        ? EdithColors.surface
                        : EdithColors.elevatedSurface,
                    border: Border.all(
                      color: isAssistant
                          ? EdithColors.primaryAccent
                          : EdithColors.secondaryAccent,
                      width: 1,
                    ),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAssistant ? 'EDITH' : 'YOU',
                        style: EdithTextStyles.navigationLabel.copyWith(
                          color: isAssistant
                              ? EdithColors.primaryAccent
                              : EdithColors.secondaryAccent,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message.message,
                        style: EdithTextStyles.body.copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
                if (message.image != null)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: EdithColors.primaryAccent,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.only(
                      top: 10,
                      bottom: 10,
                      left: 42,
                      right: 42,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: SizedBox.fromSize(
                        child: GestureDetector(
                          onLongPress: () async {
                            await SaverGallery.saveImage(
                              message.image!,
                              name: const Uuid().v1(),
                              androidExistNotSave: false,
                            );
                            if (context.mounted) {
                              showToast("Saved to photos", context);
                            }
                          },
                          child: Image.memory(message.image!),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
          padding: const EdgeInsets.only(bottom: 20),
        ),
      ),
      bottomNavigationBar: bottomNavBar(context, 0, true),
    );
  }
}
