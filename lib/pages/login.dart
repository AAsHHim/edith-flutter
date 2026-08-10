import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:noa/models/app_logic_model.dart' as app;
import 'package:noa/noa_api.dart';
import 'package:noa/pages/pairing.dart';
import 'package:noa/style.dart';
import 'package:noa/util/alert_dialog.dart';
import 'package:noa/util/location.dart';
import 'package:noa/util/sign_in.dart';
import 'package:noa/util/switch_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

TextSpan _clickableLink({required String text, required String url}) {
  return TextSpan(
    text: text,
    style: EdithTextStyles.body.copyWith(
      color: EdithColors.primaryAccent,
      decoration: TextDecoration.underline,
      decorationColor: EdithColors.primaryAccent,
    ),
    recognizer: TapGestureRecognizer()
      ..onTap = () async {
        try {
          await launchUrl(Uri.parse(url));
        } catch (_) {}
      },
  );
}

Widget _loginButton(
  BuildContext context,
  WidgetRef ref,
  String image,
  Function action,
) {
  return GestureDetector(
    onTap: () async {
      try {
        await InternetAddress.lookup('www.google.com');
        ref.read(app.model).setUserAuthToken(await action());
      } on SocketException catch (_) {
        if (context.mounted) {
          alertDialog(
            context,
            "Couldn't Sign In",
            "EDITH requires an internet connection",
          );
        }
      } on NoaApiServerException catch (error) {
        if (context.mounted) {
          alertDialog(
            context,
            "Couldn't Sign In",
            "Server responded with an error: $error",
          );
        }
      } catch (_) {}
    },
    child: Container(
      width: 320,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: EdithColors.surface,
        border: Border.all(color: EdithColors.elevatedSurface),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        child: Image.asset(image, fit: BoxFit.contain),
      ),
    ),
  );
}

class _EdithLoginBrand extends StatelessWidget {
  const _EdithLoginBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 2,
          color: EdithColors.primaryAccent,
        ),
        const SizedBox(height: 16),
        const Text(
          'EDITH',
          style: TextStyle(
            fontFamily: EdithTextStyles.fontFamily,
            color: EdithColors.primaryText,
            fontSize: 36,
            fontWeight: FontWeight.w600,
            letterSpacing: 8,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'PERSONAL AR ASSISTANT',
          style: EdithTextStyles.navigationLabel,
        ),
      ],
    );
  }
}

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late bool showWebview;

  @override
  void initState() {
    showWebview = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Location.requestPermission(context);
      if (ref.watch(app.model).state.current != app.State.waitForLogin) {
        // ref.read(app.model).triggerEvent(app.Event.loggedIn);
        switchPage(context, const PairingPage());
      }
    });

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
      body: Stack(
        children: [
          Column(
            children: [
              const Expanded(child: Center(child: _EdithLoginBrand())),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 42),
                child: Column(
                  children: [
                    if (Platform.isIOS)
                      _loginButton(
                        context,
                        ref,
                        'assets/images/sign_in_with_apple_button.png',
                        SignIn().withApple,
                      ),
                    if (Platform.isIOS)
                      _loginButton(
                        context,
                        ref,
                        'assets/images/sign_in_with_google_button.png',
                        SignIn().withGoogle,
                      ),
                    GestureDetector(
                      onTap: () async {
                        try {
                          await InternetAddress.lookup('www.google.com');
                          setState(() => showWebview = true);
                        } on SocketException catch (_) {
                          if (context.mounted) {
                            alertDialog(
                              context,
                              "Couldn't Sign In",
                              "EDITH requires an internet connection",
                            );
                          }
                        }
                      },
                      child: Container(
                        width: 320,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: EdithColors.surface,
                          border: Border.all(
                            color: EdithColors.elevatedSurface,
                          ),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(12),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(10),
                          ),
                          child: Image.asset(
                            'assets/images/sign_in_with_email_button.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
          if (showWebview)
            Container(
              padding: const EdgeInsets.all(32),
              color: EdithColors.background.withValues(alpha: 0.92),
              child: Container(
                decoration: BoxDecoration(
                  color: EdithColors.surface,
                  border: Border.all(
                    color: EdithColors.primaryAccent,
                    width: 1,
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                clipBehavior: Clip.antiAlias,
                child: WebViewWidget(
                  controller: WebViewController()
                    ..loadRequest(
                        Uri.parse("https://api.brilliant.xyz/noa/login?app=1"))
                    ..setJavaScriptMode(JavaScriptMode.unrestricted)
                    ..addJavaScriptChannel("userAuthToken",
                        onMessageReceived: (message) {
                      if (message.message == "cancelled") {
                        setState(() {
                          showWebview = false;
                        });
                      } else if (message.message != "") {
                        ref.read(app.model).setUserAuthToken(message.message);
                      }
                    }),
                ),
              ),
            )
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: <TextSpan>[
              const TextSpan(
                text: 'By continuing, you agree to the ',
                style: EdithTextStyles.secondaryBody,
              ),
              _clickableLink(
                text: 'Privacy Policy',
                url: 'https://brilliant.xyz/pages/privacy-policy',
              ),
              const TextSpan(
                text: ' and ',
                style: EdithTextStyles.secondaryBody,
              ),
              _clickableLink(
                text: 'Terms and Conditions',
                url: 'https://brilliant.xyz/pages/terms-conditions',
              ),
              const TextSpan(
                text: ' for EDITH.',
                style: EdithTextStyles.secondaryBody,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
