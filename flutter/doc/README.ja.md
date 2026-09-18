# Flutter 向け FFmpegKit Extended

<div align="center">

<img src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/assets/banner.png" alt="FFmpegKit Extended バナー" width="100%">

[![Stars](https://img.shields.io/github/stars/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/stargazers) [![Forks](https://img.shields.io/github/forks/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/fork) [![Issues](https://img.shields.io/github/issues/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/issues) [![Downloads](https://img.shields.io/pub/dm/ffmpeg_kit_extended_flutter?style=flat-square&logoColor=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub version](https://img.shields.io/pub/v/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub likes](https://img.shields.io/pub/likes/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub points](https://img.shields.io/pub/points/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![License](https://img.shields.io/github/license/akashskypatel/ffmpeg-kit-extended?color=144DB3)](LICENSE)

</div>

## 翻訳

[英語](../README.md) | [Español](README.es.md) | [简体中文](README.zh-CN.md) | [हिन्दी](README.hi.md) | [العربية](README.ar.md) | [Français](README.fr.md) | [Português (Brasil)](README.pt-BR.md) | **日本語**

`ffmpeg-kit-extended` は、`Android`、`iOS`、`macOS`、`Linux`、`Windows` 上で `FFmpeg`、`FFprobe`、`FFplay` の `9.0.1 API` コマンドを実行するための包括的な Flutter プラグインです。Dart の `FFI` を使用してネイティブ FFmpeg ライブラリと直接連携し、高い性能、柔軟性、完全な動画再生機能を提供します。
Web ビルドでは Flutter WebAssembly を使用し、同じ公開 API を提供します。ネイティブプラットフォームでは Dart FFI を使用します。

このプロジェクトが役に立ち、アプリで使用している場合は、[ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders) と [ffmpeg-kit-extended](https://github.com/akashskypatel/ffmpeg-kit-extended) に ⭐ を、[pub.dev](https://pub.dev/packages/ffmpeg_kit_extended_flutter) に 👍 をお願いします。大きな励みになります 🙏! コーディングを楽しんでください 🚀!

## 1. 機能

- **マルチプラットフォーム対応**：`Android`、`iOS`、`macOS`、`Linux`、`Windows`、WebAssembly 対応の Web ビルドで動作します。
  - **Android**：ネイティブのサーフェス描画による完全な動画再生をサポートします。
    - **x86**：`x86` アーキテクチャは旧式のためサポートされていません。
  - **iOS と macOS**：`CVPixelBuffer` と Metal 連携による高性能な動画再生を提供します。
    - **iOS**：実機の `デバイス` と `シミュレーター` の両方をサポートします。`x86_64` アーキテクチャは旧式のためサポートされていません。
  - **Linux**：`OpenGL` 連携による完全な動画再生をサポートします。
    - **arm64**：`arm64` アーキテクチャは現在未対応です。近日対応予定です。
- **Web (Wasm)**：ビルドフック中に対応する wasm32 バンドルをダウンロードし、統合 Flutter surface API で FFplay の RGBA フレームを描画します。`flutter build web --wasm` を使用します。
- **`FFmpeg`、`FFprobe`、`FFplay`**：メディア処理、情報取得、音声/動画再生のための [最新 `9.0.1 API`](https://www.ffmpeg.org/download.html) をサポートします。
- **動画再生**：統一されたサーフェス API による完全なマルチプラットフォーム動画再生。
- **リアルタイムストリーミング**：ライブ再生の監視に使える再生位置ストリームと動画サイズストリーム。
- **Dart FFI**：最適な性能を得るための直接的なネイティブバインディング。
- **非同期実行**：UI スレッドをブロックせずに長時間かかる処理を実行できます。
- **並列実行**：複数の処理を並列で実行できます。
- **コールバック対応**：ログ、統計情報、セッション完了を扱うための詳細なフック。
- **セッション管理**：実行ライフサイクルを完全に制御できます: 開始、キャンセル、一覧表示。
- **拡張可能**：カスタムのネイティブライブラリ読み込みと設定に対応できるよう設計されています。
- **完全なパッケージ内省 API**：バージョン、ビルド日、利用可能な muxers、demuxers、encoders、decoders、filters など、パッケージの詳細情報を取得できます。
- **カスタムビルドの配布**：ffmpeg-kit-extended のカスタムビルドを配布できます。参照: <https://github.com/akashskypatel/ffmpeg-kit-builders>

### プラットフォーム対応

| プラットフォーム | 状態 | 動画再生 | アーキテクチャ | 最小要件 |
| --- | --- | --- | --- | --- |
| Android と Android TV | ✅ 対応 | ✅ ネイティブ | armv7, arm64, x86_64 | API 26+ |
| iOS とシミュレータ | ✅ 対応 | ✅ テクスチャ | arm64 | iOS 13+ |
| macOS | ✅ 対応 | ✅ テクスチャ | arm64, x86_64 | macOS 13+ |
| Linux | ✅ 対応 | ✅ テクスチャ | x86_64 | glibc 2.28+ |
| Windows | ✅ 対応 | ✅ テクスチャ | x86_64 | Windows 8+ |
| Web (Wasm) | ✅ 対応 | ✅ RGBA フレーム | wasm32 | Flutter Wasm ビルド |

上記の要件に合わせて、アプリ側の最小要件を自分で更新する必要があります。

## 🎬 デモ

<div align="center">
<a href="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif">画像が読み込まれない場合はここをクリックしてください</a>
<br>
<img width="378" height="672" src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif?raw=true" alt="デモ" style="border-radius: 10px;" />
<br>

[_FFmpegKit Extended Flutter プラグインの動画デモです。リアルタイム動画再生、FFmpeg コマンド実行、包括的な内省 API インターフェイスを示しています。_](https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif)

</div>

## 2. インストール

1. パッケージをインストールします:

```bash
flutter pub add ffmpeg_kit_extended_flutter
```

2. `pubspec.yaml` に `ffmpeg_kit_extended_config` セクションを追加します:

```yaml
ffmpeg_kit_extended_config:
  type: "base" # 事前バンドル済みビルド: debug, base, full, audio, video, video_hw
  gpl: true # GPL ライブラリを含める場合に有効化します
  small: true # 小さいビルドを使用する場合に有効化します
  # == または ==
  # -------------------------------------------------------------
  # 各プラットフォーム向けに libffmpegkit ライブラリのリモートパスまたはローカルパスを指定できます
  # これにより、libffmpegkit のカスタムビルドを配布できます。
  # 参照: https://github.com/akashskypatel/ffmpeg-kit-builders
  # -------------------------------------------------------------
  # windows: "path/to/ffmpeg-kit/libraries"
  # ios: "https://path/to/bundle.xcframework.zip"
```

**現在の動作：** ネイティブライブラリと WebAssembly バンドルは、Dart Hooks によって自動的にダウンロードおよびバンドルされます。Web ビルドでは `wasm` または `web` のオーバーライドが指定されている場合にそれを使用し、指定されていない場合は固定されたリリースに対応するバンドルをフックが選択します。ローカルのオーバーライドファイルは追跡されるため、内容を変更しても `flutter clean` は必要ありません。
**重要：** 選択したバンドル設定を変更した後は、ビルドを再実行してください。ローカルオーバーライドの内容の変更は依存関係として追跡されるため、`flutter clean` は必要ありません。

3. Dart コードでパッケージをインポートします:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
```

4. いずれかの API を呼び出す **前に**、アプリ起動時にプラグインを初期化します:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FFmpegKitExtended.initialize();
  runApp(MyApp());
}
```

> **重要**：`initialize()` が完了する前に FFmpeg、FFprobe、FFplay API を呼び出すと、`StateError` がスローされます。

**Dart Pub ワークスペース：** package-config のルート `pubspec` が優先されます。それ以外の場合、このパッケージへの通常の依存パスを持つ、ルート内のパッケージグラフのルートだけが設定を提供できます。候補があいまいな場合は推測せずに失敗します。適用可能な候補がない場合は、LGPL の小さい `base` バンドルが使用されます。相対ローカルオーバーライドは、それを定義する `pubspec` を基準に解決され、ビルドフックによって追跡されます。Web では、従来の手動ステージングを使用する場合、利用側のアプリパッケージを設定してください。

たとえば、ワークスペースのルートでは次のようになります。

~~~yaml
ffmpeg_kit_extended_config:
  type: "video"
  gpl: true
~~~

### Web のビルドとデプロイ

ローカルで Web Wasm を開発する場合は、Flutter のクロスオリジン分離を使用して、pthread 対応 Wasm が共有メモリをワーカーに転送できるようにします。

~~~bash
flutter run -d web-server --cross-origin-isolation
~~~

Wasm を使用して Flutter Web をビルドします。

~~~bash
flutter clean
flutter build web --wasm
~~~

WebAssembly バンドルはデフォルトで pthread をサポートします。pthread を使用しないビルドには、カスタム WebAssembly 依存関係と ffmpeg-kit-builders からのバンドルビルドが必要です。

ビルドフックは wasm32 バンドルをダウンロードして検証し、Wasm ランタイム、ローダー、コールバックブリッジ、サポートモジュールを Web アセットとして配置します。スレッド対応 Wasm バンドルには、次の HTTP 応答ヘッダーが必要です。

~~~http
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
~~~

WebAssembly バンドルを使用する前に、window.crossOriginIsolated が true であることを確認してください。取得した Wasm、JavaScript、ワーカーなどのアセットは、選択した COEP ポリシーを満たす必要があります。

#### Flutter のテスト対象に関する制限

Flutter はテスト実行時に、ホストの TargetPlatform.tester に対するネイティブアセットのビルドフックを評価します。そのため、`flutter test` では、このパッケージのフックにホスト以外の対象向けアセットを選択させることはできません。これはすべての対象プラットフォームに適用されます。対象を検証するには、プラットフォーム固有のビルドまたは実行コマンドを使用してください。

### 2.1 プラットフォーム固有の設定

1. **iOS と iOS シミュレータ**：未対応のアーキテクチャ向けにビルドしないようにするため、アプリの Podfile にインストール後のフック（`post-install`）を追加する必要があります。Podfile に次を追加してください。

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

### 2.2 事前バンドル済みビルド

- **base**：中核となる FFmpeg ライブラリを含む基本ビルドです。追加ライブラリは含まれません。
- **full**：プラットフォーム互換の FFmpeg ライブラリをすべて含む完全ビルドです。参照: <https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries>
- **audio**：音声専用の FFmpeg ライブラリを含むビルドです。
- **video**：動画専用の FFmpeg ライブラリを含むビルドです。
- **video_hw**：ハードウェアアクセラレーション対応の動画 FFmpeg ライブラリを含むビルドです。

### 2.2 機能マトリックス

#### GPL ライセンス

GPL ライブラリを有効にすると、生成される FFmpeg バイナリは GPL ライセンスになり、アプリケーションを GPL の下で配布する必要が生じる場合があります。ライセンス上の影響を理解していない場合は、LGPL バンドルを使用してください。

#### 人工知能

libopenvino や libtensorflow などの人工知能ライブラリは、公開済みバンドルではデスクトップ専用です。libtorch は Linux 専用で、libonnxruntime は x86_64 macOS では利用できません。また、GPU 向け人工知能ライブラリにはカスタムデプロイが必要です。現在のマトリックスでは、Full ビルドで人工知能をサポートしています。

| 機能 | Base | Audio | Video | Video+Hardware | Full |
| --- | --- | --- | --- | --- | --- |
| 動画 | | | x | x | x |
| 音声 | | x | x | x | x |
| ストリーミング | | x | x | x | x |
| ハードウェア | | | | x | x |
| 人工知能* | | | | | x* |
| HTTPS | * | x | x | x | x |
| プラットフォーム* | x | x | x | x | x |
| その他* | | | | | x |

1. 人工知能機能はすべてのプラットフォームでサポートされているわけではありません。特定の人工知能機能を有効にするには、ffmpeg-kit-extended の独自カスタムビルドを配布する必要があります。
   - 詳細については、[対応している外部ライブラリ](https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries)を参照してください。

2. プラットフォーム機能とは、Apple プラットフォームの AVFoundation、VideoToolbox など、または Windows の DirectX、MediaFoundation など、FFmpeg がサポートする組み込みプラットフォームライブラリのことです。

3. HTTPS 機能は、Windows や Apple プラットフォームなど、HTTPS の組み込みサポートがあるプラットフォームでは既定で有効です。Linux と Android では、OpenSSL が既定で有効です。

4. その他の機能とは、上記のカテゴリに含まれない追加機能のことです。詳細については、[対応している外部ライブラリ](https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries)を参照してください。

## 3. 使い方

### 3.1 基本的なコマンド実行

FFmpeg コマンドを非同期で実行します:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

FFmpegKit.executeAsync('-i input.mp4 -c:v libx264 output.mp4', onComplete: (session) async {
  final returnCode = session.getReturnCode();

  if (ReturnCode.isSuccess(returnCode)) {
    print("コマンドが成功しました");
  } else if (ReturnCode.isCancel(returnCode)) {
    print("コマンドはキャンセルされました");
  } else {
    print("コマンドは次の状態で失敗しました: ${session.getState()}");
    final failStackTrace = session.getFailStackTrace();
    print("スタックトレース: $failStackTrace");
  }
});
```

### 3.2 メディア情報の取得

メディアファイルの詳細なメタデータを取得するには、`FFprobeKit` を使用します:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

FFprobeKit.getMediaInformationAsync('path/to/video.mp4', onComplete: (session) {
  final info = session.getMediaInformation();
  if (info != null) {
      print("再生時間: ${info.duration}");
      print("形式: ${info.format}");
      for (var stream in info.streams) {
          print("ストリーム種別: ${stream.type}, コーデック: ${stream.codec}");
      }
  }
});
```

### 3.3 ログと統計情報の処理

監視を改善するため、ログと統計情報のコールバックを登録できます:

```dart
FFmpegKit.executeAsync(
  '-i input.mp4 output.mkv',
  onComplete: (session) { /* 完了時のコールバック */ },
  onLog: (log) {
    print("ログ: ${log.message}");
  },
  onStatistics: (statistics) {
    print("進行状況: ${statistics.time} ms, サイズ: ${statistics.size}");
  },
);
```

### 3.4 セッション管理

すべての実行は `Session` オブジェクトを返します。このオブジェクトを使って処理を制御できます:

```dart
// 特定のセッションをキャンセルします
FFmpegKit.cancel(session);

// すべてのアクティブなセッションをキャンセルします
FFmpegKitExtended.cancelAllSessions();

// すべてのセッションを一覧表示します
final sessions = FFmpegKitExtended.getSessions();
// または FFmpeg セッションだけを一覧表示します
final ffmpegSessions = FFmpegKit.getFFmpegSessions();
```

### 3.5 FFplay 動画再生

このプラグインは、統一されたマルチプラットフォームのサーフェス API による完全な動画再生をサポートしています。

#### 基本的な動画再生

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
    // 再生を開始する前にサーフェスを作成します
    _surface = await FFplaySurface.create();

    final session = await FFplayKit.executeAsync('-i "$filePath"');

    // 動画の寸法を監視します
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

    // 再生位置の更新を監視します
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
        // 動画表示: 動画フレームが利用可能な場合のみ
        if (_hasVideo && _surface != null)
          SizedBox(
            width: _videoWidth.toDouble(),
            height: _videoHeight.toDouble(),
            child: _surface!.toWidget(),
          ),

        // 再生操作
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

#### プラットフォーム固有の使い方

`FFplaySurface` クラスは、プラットフォームごとの差異を自動的に処理します:

- **Android**：ネイティブ描画のために、`SurfaceTexture` に裏付けられた `ANativeWindow` を使用します。
- **iOS/macOS**：Metal 最適化を利用した `CVPixelBuffer` テクスチャを使用します。
- **Linux/Windows**：フレームコールバック付きのピクセルバッファテクスチャを使用します。
- **Web**：Wasm メモリから世代管理された RGBA8888 フレームを取得し、Flutter 画像として描画します。
- **音声のみ**：クラッシュを防ぐため、サーフェスは作成されますが表示されません。

#### 高度な機能

```dart
// セッション固有のプロパティを取得します
final session = await FFplayKit.executeAsync('-i video.mp4');

// 動画の寸法: 最初のフレームがデコードされると利用可能になります
final width = session.getVideoWidth();
final height = session.getVideoHeight();

// リアルタイムストリーム
session.positionStream.listen((pos) => print('位置: ${pos}s'));
session.videoSizeStream.listen((size) => print('サイズ: ${size}'));

// 音量制御
session.setVolume(0.8); // 0.0 から 1.0 まで
print('音量: ${session.getVolume()}');

// セッション状態
print('再生中: ${session.isPlaying()}');
print('一時停止中: ${session.isPaused()}');
```

### バンドルサイズ

表は `libffmpegkit` バイナリの非圧縮サイズを10進MBで示します。各範囲は v0.11.2 リリースアセットにおける LGPL の測定最小値と GPL の測定最大値を示します。

| バンドル種別 | Android (MB) | iOS (MB) | macOS (MB) | Linux (MB) | Windows (MB) |
|-------------|--------------|----------|------------|------------|--------------|
| debug       | 81.2-82.0    | 37.8-38.2 | 41.6-42.0  | 133.5-139.6 | 480.4-490.8  |
| base        | 73.4-93.0    | 36.0-48.6 | 39.8-54.3  | 31.6-44.2   | 41.3-55.2    |
| audio       | 102.6-179.1  | 74.6-126.0| 79.8-134.2 | 49.3-86.7   | 82.9-124.1   |
| video       | 233.0-353.0  | 160.7-227.4| 183.5-255.5| 164.6-232.1 | 215.0-281.1  |
| video_hw    | 239.4-359.9  | 163.8-230.7| 186.8-259.0| 171.3-239.2 | 219.0-285.4  |
| full        | 267.1-387.5  | 182.0-248.8| 223.3-295.4| 209.0-276.2 | 248.4-314.8  |

## 4. サポートされている外部ライブラリ<a id="libraries"></a>

現在のプラットフォームとバンドルの完全なマトリックスは、[英語版の公式 README](../README.md#libraries) で管理されています。

## 5. ライセンス

このプロジェクトは、既定では LGPL v3.0 の下でライセンスされています。ただし、基盤となる FFmpeg のビルド設定や使用される外部ライブラリによっては、実効的なライセンスが GPL v3.0 になる場合があります。含まれているライブラリのライセンスを確認してください。

このプラグインをプロジェクトで使用する前に、LGPL と GPL のライセンスの違いを理解してください。

アプリケーションで GPL ライセンスのコンポーネントを使用する場合、アプリケーション自体も GPL の下でライセンスする必要が生じることがあります。
