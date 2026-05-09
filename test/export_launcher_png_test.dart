import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Совпадает с `scaleX` / `scaleY` у `<group>` в
/// `android/app/src/main/res/drawable/ic_launcher_foreground.xml`.
const double kLauncherIconForegroundScale = 0.77;

/// Фон adaptive icon на Android — тот же оттенок в PNG для iOS/web.
const Color kLauncherIconBackground = Color(0xFFFDFAF6);

/// Одноразово: создаёт PNG из main_icon.svg для пакетов вроде flutter_launcher_icons / icons_launcher (iOS, web).
/// Запуск: flutter test test/export_launcher_png_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Записать assets/icons/main_icon_launcher.png из SVG', (tester) async {
    const size = 1024.0;
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: size,
              height: size,
              child: ColoredBox(
                color: kLauncherIconBackground,
                child: Center(
                  child: Transform.scale(
                    scale: kLauncherIconForegroundScale,
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      'assets/icons/main_icon.svg',
                      width: size,
                      height: size,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(byteData, isNotNull);

    final root = Directory.current.path;
    final out = File('$root/assets/icons/main_icon_launcher.png');
    await out.parent.create(recursive: true);
    await out.writeAsBytes(byteData!.buffer.asUint8List());
    expect(out.existsSync(), true);
  });
}
