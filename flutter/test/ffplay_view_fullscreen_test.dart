import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

class _FullscreenHost extends StatefulWidget {
  const _FullscreenHost({
    required this.controller,
    required this.surface,
    super.key,
  });

  final FFplayViewController controller;
  final FFplaySurface surface;

  @override
  State<_FullscreenHost> createState() => _FullscreenHostState();
}

class _FullscreenHostState extends State<_FullscreenHost> {
  bool showView = true;

  void removeView() => setState(() => showView = false);

  @override
  Widget build(BuildContext context) => showView
      ? FFplayView(surface: widget.surface, controller: widget.controller)
      : const SizedBox.shrink();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> systemUiCalls;
  var throwOnRestore = false;

  setUp(() {
    systemUiCalls = <MethodCall>[];
    SystemChannels.platform.setMockMethodCallHandler((call) async {
      if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
        systemUiCalls.add(call);
        if (throwOnRestore && systemUiCalls.length == 2) {
          throw StateError('system UI restore failed');
        }
      }
      return null;
    });
  });

  tearDown(() {
    throwOnRestore = false;
    SystemChannels.platform.setMockMethodCallHandler(null);
    debugDefaultTargetPlatformOverride = null;
  });

  Future<
    ({FFplayViewController controller, GlobalKey<_FullscreenHostState> key})
  >
  pumpHost(
    WidgetTester tester, {
    Future<void> Function()? onEnter,
    Future<void> Function()? onExit,
  }) async {
    final controller = FFplayViewController(
      onEnterFullscreen: onEnter,
      onExitFullscreen: onExit,
    );
    final key = GlobalKey<_FullscreenHostState>();
    await tester.pumpWidget(
      MaterialApp(
        home: _FullscreenHost(
          key: key,
          controller: controller,
          surface: FFplaySurface.test(),
        ),
      ),
    );
    return (controller: controller, key: key);
  }

  void testFullscreen(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(description, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testFullscreen('fullscreen enter and programmatic exit restore both sides', (
    tester,
  ) async {
    var entered = 0;
    var exited = 0;
    final host = await pumpHost(
      tester,
      onEnter: () async => entered++,
      onExit: () async => exited++,
    );

    final entering = host.controller.enterFullscreen(host.key.currentContext!);
    await tester.pumpAndSettle();
    expect(host.controller.isFullscreen, isTrue);
    expect(entered, 1);
    expect(find.byTooltip('Exit fullscreen'), findsOneWidget);

    await host.controller.exitFullscreen();
    await tester.pumpAndSettle();
    await entering;

    expect(exited, 1);
    expect(host.controller.isFullscreen, isFalse);
    expect(systemUiCalls, hasLength(2));
  });

  testFullscreen('throwing enter restores mobile system UI', (tester) async {
    final error = StateError('enter failed');
    var exited = 0;
    final host = await pumpHost(
      tester,
      onEnter: () => Future<void>.error(error),
      onExit: () async => exited++,
    );

    await expectLater(
      host.controller.enterFullscreen(host.key.currentContext!),
      throwsA(same(error)),
    );

    expect(exited, 0);
    expect(host.controller.isFullscreen, isFalse);
    expect(systemUiCalls, hasLength(2));
  });

  testFullscreen('disposing the origin while enter is pending still exits', (
    tester,
  ) async {
    final enterCompleter = Completer<void>();
    var exited = 0;
    final host = await pumpHost(
      tester,
      onEnter: () => enterCompleter.future,
      onExit: () async => exited++,
    );

    final entering = host.controller.enterFullscreen(host.key.currentContext!);
    await tester.pump();
    host.key.currentState!.removeView();
    await tester.pump();
    enterCompleter.complete();
    await entering;

    expect(exited, 1);
    expect(systemUiCalls, hasLength(2));
  });

  testFullscreen('disposing the origin with an active route still cleans up', (
    tester,
  ) async {
    var exited = 0;
    final host = await pumpHost(
      tester,
      onEnter: () async {},
      onExit: () async => exited++,
    );

    final entering = host.controller.enterFullscreen(host.key.currentContext!);
    await tester.pumpAndSettle();
    host.key.currentState!.removeView();
    await tester.pump();
    await tester.tap(find.byTooltip('Exit fullscreen'));
    await tester.pumpAndSettle();
    await entering;

    expect(exited, 1);
    expect(systemUiCalls, hasLength(2));
  });

  testFullscreen('exit cleanup is invoked for a programmatic route pop', (
    tester,
  ) async {
    var exited = 0;
    final host = await pumpHost(
      tester,
      onEnter: () async {},
      onExit: () async => exited++,
    );

    final entering = host.controller.enterFullscreen(host.key.currentContext!);
    await tester.pumpAndSettle();
    await host.controller.exitFullscreen();
    await tester.pumpAndSettle();
    await entering;

    expect(exited, 1);
    expect(host.controller.isFullscreen, isFalse);
  });

  testFullscreen('primary transition error wins over cleanup error', (
    tester,
  ) async {
    throwOnRestore = true;
    final primaryError = StateError('primary transition failed');
    final host = await pumpHost(
      tester,
      onEnter: () => Future<void>.error(primaryError),
    );

    await expectLater(
      host.controller.enterFullscreen(host.key.currentContext!),
      throwsA(same(primaryError)),
    );
    expect(systemUiCalls, hasLength(2));
  });
}
