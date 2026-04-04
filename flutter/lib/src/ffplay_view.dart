/// FFmpegKit Flutter Extended Plugin - A wrapper library for FFmpeg
/// Copyright (C) 2026 Akash Patel
///
/// This library is free software; you can redistribute it and/or
/// modify it under the terms of the GNU Lesser General Public
/// License as published by the Free Software Foundation; either
/// version 2.1 of the License, or (at your option) any later version.
///
/// This library is distributed in the hope that it will be useful,
/// but WITHOUT ANY WARRANTY; without even the implied warranty of
/// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
/// Lesser General Public License for more details.
///
/// You should have received a copy of the GNU Lesser General Public
/// License along with this library; if not, write to the Free Software
/// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
library;

import 'dart:io' show Platform;
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ffplay_surface.dart';

/// Controls the fullscreen state of an [FFplayView].
///
/// Create one controller per view, pass it to [FFplayView.controller], then
/// call [enterFullscreen] / [exitFullscreen] from any gesture, keyboard
/// shortcut, external button, or other interaction — completely decoupled from
/// the video widget itself.
///
/// ```dart
/// final _controller = FFplayViewController(
///   onEnterFullscreen: () => windowManager.setFullScreen(true),
///   onExitFullscreen:  () => windowManager.setFullScreen(false),
/// );
///
/// // Anywhere in the widget tree:
/// ElevatedButton(
///   onPressed: () => _controller.enterFullscreen(context),
///   child: const Text('Go fullscreen'),
/// );
/// ```
///
/// Extends [ChangeNotifier] — listen to react when [isFullscreen] changes
/// (e.g. to swap fullscreen / exit-fullscreen icons):
///
/// ```dart
/// ListenableBuilder(
///   listenable: _controller,
///   builder: (_, __) => Icon(
///     _controller.isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
///   ),
/// )
/// ```
///
/// Always [dispose] the controller when the owning widget is disposed.
class FFplayViewController extends ChangeNotifier {
  FFplayViewController({
    this.onEnterFullscreen,
    this.onExitFullscreen,
  });

  /// Called just before the fullscreen route is pushed.
  /// On desktop, pass `() => windowManager.setFullScreen(true)`.
  final Future<void> Function()? onEnterFullscreen;

  /// Called after the fullscreen route is popped.
  /// On desktop, pass `() => windowManager.setFullScreen(false)`.
  final Future<void> Function()? onExitFullscreen;

  bool _isFullscreen = false;

  /// Whether the attached [FFplayView] is currently in fullscreen mode.
  bool get isFullscreen => _isFullscreen;

  // Internal wiring — set/cleared by _FFplayViewState.
  Future<void> Function(BuildContext)? _enterImpl;
  Future<void> Function()? _exitImpl;

  void _attach({
    required Future<void> Function(BuildContext) enter,
    required Future<void> Function() exit,
  }) {
    _enterImpl = enter;
    _exitImpl = exit;
  }

  void _detach() {
    _enterImpl = null;
    _exitImpl = null;
  }

  void _setIsFullscreen(bool value) {
    if (_isFullscreen == value) return;
    _isFullscreen = value;
    notifyListeners();
  }

  /// Enter fullscreen.  [context] must be a widget context within the app's
  /// [Navigator] subtree (i.e. inside a [MaterialApp] / [Navigator]).
  Future<void> enterFullscreen(BuildContext context) =>
      _enterImpl?.call(context) ?? Future.value();

  /// Exit fullscreen programmatically (e.g. from an external button or
  /// keyboard shortcut).  No-op when not currently in fullscreen.
  Future<void> exitFullscreen() => _exitImpl?.call() ?? Future.value();
}

/// A widget that renders an [FFplaySurface] at the correct aspect ratio.
///
/// Does **not** include any built-in overlay buttons — fullscreen is driven
/// entirely through [FFplayViewController], which the consumer calls from
/// whatever UI element (button, keyboard shortcut, gesture) they choose.
///
/// ### Sizing in normal mode
///
/// * Both [aspectRatio] and [videoWidth] provided → widget sizes itself to
///   `min(containerWidth, videoWidth) × (w / aspectRatio)`.  Never upscales
///   beyond native dimensions.
/// * Only [aspectRatio] → fills parent container at that ratio.
/// * Neither → expands to fill parent.
///
/// ### Fullscreen
///
/// ```dart
/// // Enter from a button anchored outside FFplayView:
/// _controller.enterFullscreen(context);
/// ```
///
/// For true OS-level fullscreen on Windows / Linux supply
/// [FFplayViewController.onEnterFullscreen] /
/// [FFplayViewController.onExitFullscreen].
class FFplayView extends StatefulWidget {
  const FFplayView({
    required this.surface,
    this.controller,
    this.aspectRatio,
    this.videoWidth,
    this.videoHeight,
    this.backgroundColor = Colors.black,
    super.key,
  });

  /// The video surface to display.
  final FFplaySurface surface;

  /// Controls fullscreen state.  When omitted no fullscreen capability is
  /// wired up (useful when the consumer handles navigation manually).
  final FFplayViewController? controller;

  /// Aspect ratio of the video (e.g. `16 / 9`).
  final double? aspectRatio;

  /// Native pixel width of the video stream.  Used to cap the widget to the
  /// video's natural dimensions in normal mode.
  final int? videoWidth;

  /// Native pixel height of the video stream (informational).
  final int? videoHeight;

  /// Background colour for letterbox / pillarbox areas.
  final Color backgroundColor;

  @override
  State<FFplayView> createState() => _FFplayViewState();
}

class _FFplayViewState extends State<FFplayView> {
  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  /// Stored while a fullscreen route is active; used by [_popFullscreen].
  NavigatorState? _fullscreenNav;

  @override
  void initState() {
    super.initState();
    _attachController(widget.controller);
  }

  @override
  void didUpdateWidget(FFplayView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?._detach();
      _attachController(widget.controller);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    super.dispose();
  }

  void _attachController(FFplayViewController? controller) {
    controller?._attach(enter: _enterFullscreen, exit: _popFullscreen);
  }

  Future<void> _enterFullscreen(BuildContext context) async {
    if (_fullscreenNav != null) return; // already in fullscreen
    if (_isMobile) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    await widget.controller?.onEnterFullscreen?.call();
    widget.controller?._setIsFullscreen(true);

    _fullscreenNav = Navigator.of(context);
    await _fullscreenNav!.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullscreenVideoPage(
          surface: widget.surface,
          backgroundColor: widget.backgroundColor,
          aspectRatio: widget.aspectRatio,
        ),
      ),
    );
    // Reached here after route is popped (any mechanism: button, back gesture,
    // or external controller.exitFullscreen()).
    _fullscreenNav = null;

    if (!mounted) return;
    if (_isMobile) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    await widget.controller?.onExitFullscreen?.call();
    widget.controller?._setIsFullscreen(false);
  }

  /// Called by [FFplayViewController.exitFullscreen] to programmatically pop
  /// the active fullscreen route.
  Future<void> _popFullscreen() async {
    _fullscreenNav?.pop();
  }

  Widget _buildVideo() {
    final ar = widget.aspectRatio;
    final nativeW = widget.videoWidth?.toDouble();

    final video = ColoredBox(
      color: widget.backgroundColor,
      child: widget.surface.toWidget(),
    );

    if (ar == null) return SizedBox.expand(child: video);

    if (nativeW != null) {
      return LayoutBuilder(builder: (_, constraints) {
        final maxW =
            constraints.maxWidth.isFinite ? constraints.maxWidth : nativeW;
        final w = min(maxW, nativeW);
        final h = w / ar;
        return SizedBox(width: w, height: h, child: video);
      });
    }

    return AspectRatio(aspectRatio: ar, child: video);
  }

  @override
  Widget build(BuildContext context) => _buildVideo();
}

/// Full-screen video page pushed by [FFplayView].
///
/// Tap anywhere to toggle the exit button overlay.  Press back or tap the
/// exit button to pop and return to normal mode.
class _FullscreenVideoPage extends StatefulWidget {
  const _FullscreenVideoPage({
    required this.surface,
    required this.backgroundColor,
    this.aspectRatio,
  });

  final FFplaySurface surface;
  final Color backgroundColor;
  final double? aspectRatio;

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  bool _controlsVisible = true;

  void _toggleControls() =>
      setState(() => _controlsVisible = !_controlsVisible);

  Widget _buildVideo() {
    final video = widget.surface.toWidget();
    final ar = widget.aspectRatio;
    if (ar != null) {
      return Center(child: AspectRatio(aspectRatio: ar, child: video));
    }
    return Center(child: video);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: widget.backgroundColor,
        body: GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            children: [
              _buildVideo(),
              Positioned(
                top: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: SafeArea(
                      child: IconButton(
                        icon: const Icon(Icons.fullscreen_exit),
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Exit fullscreen',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
