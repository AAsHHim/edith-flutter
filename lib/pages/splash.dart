import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:noa/models/app_logic_model.dart' as app;
import 'package:noa/pages/login.dart';
import 'package:noa/pages/noa.dart';
import 'package:noa/style.dart';
import 'package:noa/util/switch_page.dart';

class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(app.model).triggerEvent(app.Event.init);
      Timer(const Duration(milliseconds: 1500), () {
        switch (ref.watch(app.model).state.current) {
          case app.State.connected:
          case app.State.disconnected:
            switchPage(context, const NoaPage());
            break;
          default:
            switchPage(context, const LoginPage());
        }
      });
    });

    return const Scaffold(
      backgroundColor: EdithColors.background,
      body: SafeArea(
        child: Center(
          child: _EdithSplashBrand(),
        ),
      ),
    );
  }
}

class _EdithSplashBrand extends StatelessWidget {
  const _EdithSplashBrand();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'EDITH',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: EdithColors.secondaryAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 42,
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: EdithColors.primaryAccent,
                ),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: EdithColors.secondaryAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'EDITH',
            style: TextStyle(
              fontFamily: EdithTextStyles.fontFamily,
              color: EdithColors.primaryText,
              fontSize: 38,
              fontWeight: FontWeight.w600,
              letterSpacing: 8,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 156,
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  EdithColors.primaryAccent,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
