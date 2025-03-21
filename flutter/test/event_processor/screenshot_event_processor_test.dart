@Tags(['canvasKit']) // Web renderer where this test can run

import 'dart:math';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/event_processor/screenshot_event_processor.dart';
import 'package:sentry_flutter/src/renderer/renderer.dart';
import '../mocks.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  Future<void> _addScreenshotAttachment(
    WidgetTester tester,
    FlutterRenderer? renderer, {
    required bool isWeb,
    required bool added,
    int? expectedMaxWidthOrHeight,
  }) async {
    // Run with real async https://stackoverflow.com/a/54021863
    await tester.runAsync(() async {
      final sut = fixture.getSut(renderer, isWeb);

      await tester.pumpWidget(SentryScreenshotWidget(
          child: Text('Catching Pokémon is a snap!',
              textDirection: TextDirection.ltr)));

      final throwable = Exception();
      final event = SentryEvent(throwable: throwable);
      final hint = Hint();
      await sut.apply(event, hint: hint);

      expect(hint.screenshot != null, added);
      if (expectedMaxWidthOrHeight != null) {
        final bytes = await hint.screenshot?.bytes;
        final codec = await instantiateImageCodec(bytes!);
        final frameInfo = await codec.getNextFrame();
        final image = frameInfo.image;
        expect(
          max(image.width, image.height).toDouble(),
          moreOrLessEquals(expectedMaxWidthOrHeight.toDouble(), epsilon: 1.0),
        );
      }
    });
  }

  testWidgets('adds screenshot attachment dart:io', (tester) async {
    await _addScreenshotAttachment(tester, null, added: true, isWeb: false);
  });

  testWidgets('adds screenshot attachment with canvasKit renderer',
      (tester) async {
    await _addScreenshotAttachment(tester, FlutterRenderer.canvasKit,
        added: true, isWeb: true);
  });

  testWidgets('does not add screenshot attachment with html renderer',
      (tester) async {
    await _addScreenshotAttachment(tester, FlutterRenderer.html,
        added: false, isWeb: true);
  });

  testWidgets('does add screenshot in correct resolution for low',
      (tester) async {
    final height = SentryScreenshotQuality.low.targetResolution()!;
    fixture.options.screenshotQuality = SentryScreenshotQuality.low;
    await _addScreenshotAttachment(tester, null,
        added: true, isWeb: false, expectedMaxWidthOrHeight: height);
  });

  testWidgets('does add screenshot in correct resolution for medium',
      (tester) async {
    final height = SentryScreenshotQuality.medium.targetResolution()!;
    fixture.options.screenshotQuality = SentryScreenshotQuality.medium;
    await _addScreenshotAttachment(tester, null,
        added: true, isWeb: false, expectedMaxWidthOrHeight: height);
  });

  testWidgets('does add screenshot in correct resolution for high',
      (tester) async {
    final widthOrHeight = SentryScreenshotQuality.high.targetResolution()!;
    fixture.options.screenshotQuality = SentryScreenshotQuality.high;
    await _addScreenshotAttachment(tester, null,
        added: true, isWeb: false, expectedMaxWidthOrHeight: widthOrHeight);
  });
}

class Fixture {
  SentryFlutterOptions options = SentryFlutterOptions(dsn: fakeDsn);

  ScreenshotEventProcessor getSut(
      FlutterRenderer? flutterRenderer, bool isWeb) {
    options.rendererWrapper = MockRendererWrapper(flutterRenderer);
    options.platformChecker = MockPlatformChecker(isWebValue: isWeb);
    return ScreenshotEventProcessor(options);
  }
}
