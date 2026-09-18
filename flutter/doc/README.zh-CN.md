# Flutter 版 FFmpegKit Extended

<div align="center">

<img src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/assets/banner.png" alt="FFmpegKit Extended 横幅" width="100%">

[![Stars](https://img.shields.io/github/stars/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/stargazers) [![Forks](https://img.shields.io/github/forks/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/fork) [![Issues](https://img.shields.io/github/issues/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/issues) [![Downloads](https://img.shields.io/pub/dm/ffmpeg_kit_extended_flutter?style=flat-square&logoColor=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub version](https://img.shields.io/pub/v/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub likes](https://img.shields.io/pub/likes/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub points](https://img.shields.io/pub/points/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![License](https://img.shields.io/github/license/akashskypatel/ffmpeg-kit-extended?color=144DB3)](LICENSE)

</div>

## 翻译

[英文](../README.md) | [Español](README.es.md) | **简体中文** | [हिन्दी](README.hi.md) | [العربية](README.ar.md) | [Français](README.fr.md) | [Português (Brasil)](README.pt-BR.md) | [日本語](README.ja.md)


`ffmpeg-kit-extended` 是一个完整的 Flutter 插件，可在 `Android`、`iOS`、`macOS`、`Linux` 和 `Windows` 上执行 `FFmpeg`、`FFprobe` 与 `FFplay` 的 `9.0.1 API` 命令。它使用 Dart `FFI` 直接与原生 FFmpeg 库交互，提供高性能、灵活性以及完整的视频播放能力。
Web 构建使用 Flutter WebAssembly，并提供相同的公共 API；原生平台使用 Dart FFI。

如果你喜欢这个项目并在应用中使用它，请在 [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders) 和 [ffmpeg-kit-extended](https://github.com/akashskypatel/ffmpeg-kit-extended) 上点 ⭐，并在 [pub.dev](https://pub.dev/packages/ffmpeg_kit_extended_flutter) 上点 👍。

## 1. 功能

- **跨平台支持**：支持 `Android`、`iOS`、`macOS`、`Linux`、`Windows` 以及启用 WebAssembly 的 Web 构建。
  - **Android**：通过原生 surface 渲染提供完整视频播放支持。
    - **x86**：由于属于旧架构，不支持 `x86`。
  - **iOS 与 macOS**：通过 `CVPixelBuffer` 和 Metal 集成实现高性能视频播放。
    - **iOS**：支持物理`设备`和`模拟器`。由于属于旧架构，不支持 `x86_64`。
  - **Linux**：通过 `OpenGL` 集成提供完整视频播放支持。
    - **arm64**：目前暂不支持 `arm64`，即将推出。
- **Web (Wasm)**：构建钩子会下载匹配的 wasm32 软件包，并通过 Flutter 统一的 surface API 渲染 FFplay RGBA 帧。请使用 `flutter build web --wasm`。
- **`FFmpeg`、`FFprobe` 和 `FFplay`**：支持最新 [`9.0.1 API`](https://www.ffmpeg.org/download.html)，用于媒体处理、信息读取以及音视频播放。
- **视频播放**：使用统一 surface API 的完整跨平台视频播放。
- **实时流**：提供播放位置和视频尺寸流，便于实时监控。
- **Dart FFI**：直接原生绑定，以获得最佳性能。
- **异步执行**：运行耗时任务时不会阻塞 UI 线程。
- **并行执行**：可并行运行多个任务。
- **回调支持**：为日志、统计信息和会话完成提供详细钩子。
- **会话管理**：完整控制执行生命周期：启动、取消和列出。
- **可扩展**：支持自定义原生库加载与配置。
- **完整包内省 API**：获取包的详细信息，包括版本、构建日期、可用复用器、解复用器、编码器、解码器、滤镜等。
- **部署自定义构建**：你可以部署 ffmpeg-kit-extended 的自定义构建。参见：<https://github.com/akashskypatel/ffmpeg-kit-builders>

### 平台支持

| 平台 | 状态 | 视频播放 | 架构 | 最低要求 |
| --- | --- | --- | --- | --- |
| Android（含 Android TV） | ✅ 支持 | ✅ 原生 | armv7, arm64, x86_64 | API 26+ |
| iOS（含模拟器） | ✅ 支持 | ✅ Texture | arm64 | iOS 13+ |
| macOS | ✅ 支持 | ✅ Texture | arm64, x86_64 | macOS 13+ |
| Linux | ✅ 支持 | ✅ Texture | x86_64 | glibc 2.28+ |
| Windows | ✅ 支持 | ✅ Texture | x86_64 | Windows 8+ |
| Web (Wasm) | ✅ 支持 | ✅ RGBA 帧 | wasm32 | Flutter Wasm 构建 |

你需要自行更新应用的最低要求，使其与上表匹配。

## 🎬 演示

<div align="center">
<a href="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif">如果图片无法加载，请点击此处</a>
<br>
<img width="378" height="672" src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif?raw=true" alt="演示" style="border-radius: 10px;" />
<br>

[_FFmpegKit Extended Flutter 插件的视频演示，展示实时视频播放、FFmpeg 命令执行以及完整的内省 API 界面。_](https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif)

</div>

## 2. 安装

1. 安装软件包：

```bash
flutter pub add ffmpeg_kit_extended_flutter
```

2. 将 `ffmpeg_kit_extended_config` 配置添加到 `pubspec.yaml`：

```yaml
ffmpeg_kit_extended_config:
  type: "base" # 预打包构建：debug, base, full, audio, video, video_hw
  gpl: true # 启用以包含 GPL 库
  small: true # 启用以使用更小的构建
  # == 或 ==
  # -------------------------------------------------------------
  # 你可以为每个平台指定 libffmpegkit 库的远程或本地路径
  # 这允许你部署 libffmpegkit 的自定义构建。
  # 参见：https://github.com/akashskypatel/ffmpeg-kit-builders
  # -------------------------------------------------------------
  # windows: "path/to/ffmpeg-kit/libraries"
  # ios: "https://path/to/bundle.xcframework.zip"
```

**当前行为：**原生库和 WebAssembly 软件包会通过 Dart Hooks 自动下载并打包。提供 `wasm` 或 `web` 覆盖配置时，Web 构建会使用该配置；否则，钩子会选择与固定版本匹配的软件包。系统会跟踪本地覆盖文件，因此更改其内容时不需要执行 `flutter clean`。
**重要：**更改所选软件包配置后，请重新运行构建。本地覆盖内容的更改会作为依赖项进行跟踪，因此不需要执行 `flutter clean`。

3. 在 Dart 代码中导入软件包：

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
```

4. 在应用启动时、调用任何 API **之前** 初始化插件：

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FFmpegKitExtended.initialize();
  runApp(MyApp());
}
```

> **重要**：在 `initialize()` 完成前调用任何 FFmpeg、FFprobe 或 FFplay API 都会抛出 `StateError`。

**Dart Pub 工作区：**package-config 根目录中的 `pubspec` 优先。否则，只有位于根目录内、并通过正常依赖路径指向此软件包的包图根目录才能提供配置。候选项存在歧义时会直接失败，而不会猜测；如果没有适用候选项，则使用 LGPL 的小型 `base` 软件包。相对本地覆盖路径会从定义它的 `pubspec` 解析，并由构建钩子跟踪。对于 Web，使用旧式手动暂存时，请配置使用方应用软件包。

例如，在工作区根目录中：

~~~yaml
ffmpeg_kit_extended_config:
  type: "video"
  gpl: true
~~~

### Web 构建与部署

进行本地 Web Wasm 开发时，请使用 Flutter 跨源隔离，以便启用 pthread 的 Wasm 将共享内存传输给其工作线程：

~~~bash
flutter run -d web-server --cross-origin-isolation
~~~

使用 Wasm 构建 Flutter Web：

~~~bash
flutter clean
flutter build web --wasm
~~~

WebAssembly 软件包默认支持 pthread。不使用 pthread 的构建需要自定义 WebAssembly 依赖项，并从 ffmpeg-kit-builders 构建软件包。

构建钩子会下载并验证 wasm32 软件包，然后将 Wasm 运行时、加载器、回调桥接和支持模块作为 Web 资源暂存。多线程 Wasm 软件包需要以下 HTTP 响应标头：

~~~http
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
~~~

使用 WebAssembly 软件包前，请确认 window.crossOriginIsolated 为 true。获取的 Wasm、JavaScript、工作线程及其他资源必须符合所选的 COEP 策略。

#### Flutter 测试目标限制

运行测试时，Flutter 会针对主机 TargetPlatform.tester 评估原生资源构建钩子。因此，`flutter test` 无法让此软件包的钩子为非主机目标选择资源。这适用于所有目标平台。请使用特定于平台的构建或运行命令来验证目标。

### 2.1 平台特定配置

1. **iOS 和 iOS 模拟器**：你的应用 Podfile 需要添加安装后钩子（`post-install`），以排除不支持的架构。将以下内容添加到 Podfile：

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'i386 x86_64'
      config.build_settings['EXCLUDED_ARCHS[sdk=iphoneos*]'] = 'i386 x86_64'
    end
  end

  installer.generated_projects.each do |project|
    project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'i386 x86_64'
        config.build_settings['EXCLUDED_ARCHS[sdk=iphoneos*]'] = 'i386 x86_64'
        config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
      end
    end
    project.save
  end
end
```

### 2.2 预打包构建

- **base**：包含核心 FFmpeg 库的基础构建。不包含额外库。
- **full**：包含所有平台兼容 FFmpeg 库的完整构建。参见：<https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries>
- **audio**：仅包含音频相关 FFmpeg 库的构建。
- **video**：仅包含视频相关 FFmpeg 库的构建。
- **video_hw**：包含硬件加速视频 FFmpeg 库的构建。

### 2.2 功能矩阵

#### GPL 许可

启用 GPL 库会使生成的 FFmpeg 二进制文件采用 GPL 许可，并可能要求你的应用根据 GPL 进行分发。如果不了解许可影响，请使用 LGPL 软件包。

#### 人工智能

libopenvino 和 libtensorflow 等人工智能库在已发布的软件包中仅支持桌面平台。libtorch 仅支持 Linux，libonnxruntime 在 x86_64 macOS 上不可用，而 GPU 人工智能库需要自定义部署。当前矩阵在 Full 构建中标记了人工智能支持。

| 功能       | Base | Audio | Video | Video+Hardware | Full |
| ---------- | ---- | ----- | ----- | -------------- | ---- |
| 视频       |      |       | x     | x              | x    |
| 音频       |      | x     | x     | x              | x    |
| 流媒体     |      | x     | x     | x              | x    |
| 硬件加速   |      |       |       | x              | x    |
| 人工智能*  |      |       |       |                | x*   |
| HTTPS      | *    | x     | x     | x              | x    |
| 平台*      | x    | x     | x     | x              | x    |
| 其他*      |      |       |       |                | x    |

1. 人工智能功能并非在所有平台上都受支持。你必须部署自己的 ffmpeg-kit-extended 自定义构建，才能启用某些人工智能功能。
   - 有关更多信息，请参阅[支持的外部库](https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries)。

2. 平台功能是 FFmpeg 支持的内置平台库，例如 Apple 平台上的 AVFoundation、VideoToolbox 等，或 Windows 上的 DirectX、MediaFoundation。

3. 对于具有内置 HTTPS 支持的平台，例如 Windows 或 Apple 平台，HTTPS 功能默认启用。在 Linux 和 Android 上，OpenSSL 默认启用。

4. 其他功能是上述类别未涵盖的附加功能。有关更多信息，请参阅[支持的外部库](https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries)。


## 3. 使用

### 3.1 基本命令执行

异步执行 FFmpeg 命令：

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

FFmpegKit.executeAsync('-i input.mp4 -c:v libx264 output.mp4', onComplete: (session) async {
  final returnCode = session.getReturnCode();

  if (ReturnCode.isSuccess(returnCode)) {
    print("命令执行成功");
  } else if (ReturnCode.isCancel(returnCode)) {
    print("命令已取消");
  } else {
    print("命令失败，状态为 ${session.getState()}");
    final failStackTrace = session.getFailStackTrace();
    print("堆栈跟踪：$failStackTrace");
  }
});
```

### 3.2 获取媒体信息

使用 `FFprobeKit` 获取媒体文件的详细元数据：

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

FFprobeKit.getMediaInformationAsync('path/to/video.mp4', onComplete: (session) {
  final info = session.getMediaInformation();
  if (info != null) {
      print("时长：${info.duration}");
      print("格式：${info.format}");
      for (var stream in info.streams) {
          print("流类型：${stream.type}，编解码器：${stream.codec}");
      }
  }
});
```

### 3.3 处理日志和统计信息

你可以注册日志和统计信息回调，以改进监控：

```dart
FFmpegKit.executeAsync(
  '-i input.mp4 output.mkv',
  onComplete: (session) { /* 完成回调 */ },
  onLog: (log) {
    print("日志：${log.message}");
  },
  onStatistics: (statistics) {
    print("进度：${statistics.time} 毫秒，大小：${statistics.size}");
  },
);
```

### 3.4 会话管理

所有执行都会返回一个 `Session` 对象，可用于控制任务：

```dart
// 取消指定会话
FFmpegKit.cancel(session);

// 取消所有活动会话
FFmpegKitExtended.cancelAllSessions();

// 列出所有会话
final sessions = FFmpegKitExtended.getSessions();
// 或仅列出 FFmpeg 会话
final ffmpegSessions = FFmpegKit.getFFmpegSessions();
```

### 3.5 FFplay 视频播放

该插件通过统一的跨平台 surface API 支持完整视频播放。

#### 基础视频播放

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

class VideoPlayerWidget extends StatefulWidget {
  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  FFplaySurface? _surface;
  bool _hasVideo = false;
  int _videoWidth = 0;
  int _videoHeight = 0;
  double _playbackPosition = 0.0;

  @override
  void dispose() {
    _surface?.release();
    super.dispose();
  }

  Future<void> _startPlayback(String filePath) async {
    // 在开始播放前创建 surface
    _surface = await FFplaySurface.create();

    final session = await FFplayKit.executeAsync('-i "$filePath"');

    // 监听视频尺寸
    session.videoSizeStream.listen((size) {
      final (width, height) = size;
      if (mounted && width > 0 && height > 0) {
        setState(() {
          _videoWidth = width;
          _videoHeight = height;
          _hasVideo = true;
        });
      }
    });

    // 监听播放位置更新
    session.positionStream.listen((position) {
      if (mounted) {
        setState(() => _playbackPosition = position);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 视频显示（仅在视频帧可用时显示）
        if (_hasVideo && _surface != null)
          SizedBox(
            width: _videoWidth.toDouble(),
            height: _videoHeight.toDouble(),
            child: _surface!.toWidget(),
          ),

        // 播放控件
        Row(
          children: [
            IconButton(
              onPressed: () => FFplayKit.pause(),
              icon: Icon(Icons.pause),
            ),
            IconButton(
              onPressed: () => FFplayKit.resume(),
              icon: Icon(Icons.play_arrow),
            ),
            Expanded(
              child: Slider(
                value: _playbackPosition / (FFplayKit.duration > 0 ? FFplayKit.duration : 1.0),
                onChanged: (value) => FFplayKit.seek(value * FFplayKit.duration),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
```

#### 平台特定用法

`FFplaySurface` 类会自动处理平台差异：

- **Android**：使用基于 `ANativeWindow` 的 `SurfaceTexture` 进行原生渲染。
- **iOS/macOS**：使用带 Metal 优化的 `CVPixelBuffer` 纹理。
- **Linux/Windows**：使用带帧回调的像素缓冲纹理。
- **Web**：从 Wasm 内存复制按代跟踪的 RGBA8888 帧，并将其渲染为 Flutter 图像。
- **纯音频**：会创建 surface，但不显示，从而避免崩溃。

#### 高级功能

```dart
// 获取会话特定属性
final session = await FFplayKit.executeAsync('-i video.mp4');

// 视频尺寸（解码第一帧后可用）
final width = session.getVideoWidth();
final height = session.getVideoHeight();

// 实时数据流
session.positionStream.listen((pos) => print('位置：${pos}s'));
session.videoSizeStream.listen((size) => print('大小：${size}'));

// 音量控制
session.setVolume(0.8); // 从 0.0 到 1.0
print('音量：${session.getVolume()}');

// 会话状态
print('正在播放：${session.isPlaying()}');
print('已暂停：${session.isPaused()}');
```

### 软件包大小

表格显示 `libffmpegkit` 二进制文件未压缩时的十进制 MB 大小。每个范围表示 v0.11.2 发布资源中 LGPL 的测量最小值和 GPL 的测量最大值。

| 软件包类型 | Android (MB) | iOS (MB) | macOS (MB) | Linux (MB) | Windows (MB) |
|-------------|--------------|----------|------------|------------|--------------|
| debug       | 81.2-82.0    | 37.8-38.2 | 41.6-42.0  | 133.5-139.6 | 480.4-490.8  |
| base        | 73.4-93.0    | 36.0-48.6 | 39.8-54.3  | 31.6-44.2   | 41.3-55.2    |
| audio       | 102.6-179.1  | 74.6-126.0| 79.8-134.2 | 49.3-86.7   | 82.9-124.1   |
| video       | 233.0-353.0  | 160.7-227.4| 183.5-255.5| 164.6-232.1 | 215.0-281.1  |
| video_hw    | 239.4-359.9  | 163.8-230.7| 186.8-259.0| 171.3-239.2 | 219.0-285.4  |
| full        | 267.1-387.5  | 182.0-248.8| 223.3-295.4| 209.0-276.2 | 248.4-314.8  |

## 4. 支持的外部库<a id="libraries"></a>

完整且最新的平台与软件包矩阵维护在[规范英文 README](../README.md#libraries)中。

## 5. 许可证

本项目默认采用 LGPL v3.0 许可。但是，根据底层 FFmpeg 构建配置和所使用的外部库，实际许可可能是 GPL v3.0。请检查所包含库的许可证。

在你的项目中使用此插件之前，请理解 LGPL 与 GPL 许可证之间的区别。
