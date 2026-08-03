import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zova/core/state/ui_translation_controller.dart';
import 'package:zova/core/widgets/tr_text.dart';

void main() {
  Future<String?> fakeTranslator(String text, String target) async =>
      '[$target] $text';

  Future<String?> slowTranslator(
    String text,
    String target,
    Completer<String> completer,
  ) async =>
      completer.future;

  group('UiTranslationController', () {
    test('English is a passthrough', () {
      final controller =
          UiTranslationController(code: 'en', translator: fakeTranslator);
      expect(controller.tr('Hello world'), 'Hello world');
      expect(controller.code, 'en');
    });

    test('tr fetches lazily, caches and notifies', () async {
      final controller =
          UiTranslationController(code: 'fa', translator: fakeTranslator);
      var notified = 0;
      controller.addListener(() => notified++);

      expect(controller.tr('Hello world'), 'Hello world');
      expect(controller.tr('Hello world'), 'Hello world',
          reason: 'no duplicate in-flight fetch');

      await controller.translate('Hello world');
      expect(controller.tr('Hello world'), '[fa] Hello world');
      expect(notified, greaterThanOrEqualTo(1));
    });

    test('setCode drops the hot cache and re-translates', () async {
      final controller =
          UiTranslationController(code: 'fa', translator: fakeTranslator);
      await controller.translate('Start');
      expect(controller.tr('Start'), '[fa] Start');

      controller.setCode('ar');
      expect(controller.code, 'ar');
      expect(controller.tr('Start'), 'Start',
          reason: 'cache cleared after language switch');

      await controller.translate('Start');
      expect(controller.tr('Start'), '[ar] Start');
    });

    test('null result keeps English', () async {
      final controller = UiTranslationController(
        code: 'fa',
        translator: (text, target) async => null,
      );
      await controller.translate('Offline');
      expect(controller.tr('Offline'), 'Offline');
    });
  });

  group('TrText', () {
    Widget wrap(Widget child, {UiTranslationController? ui}) {
      return ChangeNotifierProvider.value(
        value: ui,
        child: MaterialApp(home: Scaffold(body: child)),
      );
    }

    testWidgets('shows English source without a controller', (tester) async {
      await tester.pumpWidget(wrap(const TrText('Hello world')));
      expect(find.text('Hello world'), findsOneWidget);
    });

    testWidgets('swaps to the translation once it arrives', (tester) async {
      final completer = Completer<String>();
      final controller = UiTranslationController(
        code: 'fa',
        translator: (text, target) => slowTranslator(text, target, completer),
      );

      await tester.pumpWidget(wrap(const TrText('Hello world'), ui: controller));
      expect(find.text('Hello world'), findsOneWidget,
          reason: 'English is shown while the fetch is pending');

      completer.complete('[fa] Hello world');
      await tester.pump();

      expect(find.text('[fa] Hello world'), findsOneWidget);
    });

    testWidgets('rebuilds on language change', (tester) async {
      final calls = <String>[];
      final controller = UiTranslationController(
        code: 'fa',
        translator: (text, target) async {
          calls.add('$target:$text');
          return '[$target] $text';
        },
      );
      await controller.translate('Hello world');

      await tester.pumpWidget(wrap(const TrText('Hello world'), ui: controller));
      expect(find.text('[fa] Hello world'), findsOneWidget);

      controller.setCode('es');
      await tester.pump();
      expect(find.text('Hello world'), findsOneWidget,
          reason: 'English flash after switching language');

      await controller.translate('Hello world');
      await tester.pump();
      expect(find.text('[es] Hello world'), findsOneWidget);
    });

    testWidgets('context.trTempl substitutes placeholders', (tester) async {
      final controller = UiTranslationController(
        code: 'fa',
        translator: (text, target) async => text == '{0} topics'
            ? '[fa] {0} موضــوع'
            : '[$target] $text',
      );

      await tester.pumpWidget(
        wrap(
          const _WatchingTemplatedText('{0} topics', [3]),
          ui: controller,
        ),
      );

      expect(find.text('3 topics'), findsOneWidget,
          reason: 'English source with {0} substituted');
      await controller.translate('{0} topics');
      await tester.pump();
      expect(find.text('[fa] 3 موضــوع'), findsOneWidget);
    });
  });
}

class _WatchingTemplatedText extends StatelessWidget {
  const _WatchingTemplatedText(this.template, this.args);

  final String template;
  final List<Object> args;

  @override
  Widget build(BuildContext context) {
    context.watch<UiTranslationController?>();
    return Text(context.trTempl(template, args));
  }
}
