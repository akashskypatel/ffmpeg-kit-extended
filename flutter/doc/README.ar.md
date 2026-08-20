# FFmpegKit Extended لـ Flutter

<div align="center">

<img src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/assets/banner.png" alt="FFmpegKit Extended Banner" width="100%">

[![Stars](https://img.shields.io/github/stars/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/stargazers) [![Forks](https://img.shields.io/github/forks/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/fork) [![Issues](https://img.shields.io/github/issues/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/issues) [![Downloads](https://img.shields.io/pub/dm/ffmpeg_kit_extended_flutter?style=flat-square&logoColor=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub version](https://img.shields.io/pub/v/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub likes](https://img.shields.io/pub/likes/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub points](https://img.shields.io/pub/points/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![License](https://img.shields.io/github/license/akashskypatel/ffmpeg-kit-extended?color=144DB3)](LICENSE)

</div>

## Translations

[English](../README.md) | [Español](README.es.md) | [简体中文](README.zh-CN.md) | [हिन्दी](README.hi.md) | **العربية** | [Français](README.fr.md) | [Português (Brasil)](README.pt-BR.md) | [日本語](README.ja.md)


`ffmpeg-kit-extended` هو إضافة Flutter شاملة لتنفيذ أوامر `FFmpeg` و`FFprobe` و`FFplay` باستخدام `9.0.1 API` على `Android` و`iOS` و`macOS` و`Linux` و`Windows`. يستخدم Dart `FFI` للتعامل مباشرة مع مكتبات FFmpeg الأصلية، مما يوفر أداءً عاليًا ومرونة وقدرات كاملة لتشغيل الفيديو.

إذا أعجبك المشروع وتستخدمه في تطبيقك، ضع ⭐ على [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders) و[ffmpeg-kit-extended](https://github.com/akashskypatel/ffmpeg-kit-extended)، وضع 👍 على [pub.dev](https://pub.dev/packages/ffmpeg_kit_extended_flutter).

## 1. الميزات

- **دعم متعدد المنصات**: يعمل على `Android` و`iOS` و`macOS` و`Linux` و`Windows`.
  - **Android**: دعم كامل لتشغيل الفيديو مع rendering أصلي عبر surface.
    - **x86**: معمارية `x86` غير مدعومة لأنها قديمة.
  - **iOS وmacOS**: تشغيل فيديو عالي الأداء باستخدام `CVPixelBuffer` وتكامل Metal.
    - **iOS**: يدعم `الأجهزة` الفعلية و`المحاكيات`. معمارية `x86_64` غير مدعومة لأنها قديمة.
  - **Linux**: دعم كامل لتشغيل الفيديو مع تكامل `OpenGL`.
    - **arm64**: معمارية `arm64` غير مدعومة حاليًا، وستتوفر قريبًا.
- **`FFmpeg` و`FFprobe` و`FFplay`**: دعم [أحدث `9.0.1 API`](https://www.ffmpeg.org/download.html#release_8.1) لمعالجة الوسائط، واسترجاع المعلومات، وتشغيل الصوت/الفيديو.
- **تشغيل الفيديو**: تشغيل فيديو كامل متعدد المنصات باستخدام API موحد للسطح.
- **البث في الوقت الحقيقي**: streams لموضع التشغيل وأبعاد الفيديو لمراقبة التشغيل المباشر.
- **Dart FFI**: bindings أصلية مباشرة لأفضل أداء.
- **تنفيذ غير متزامن**: تشغيل المهام الطويلة دون حظر UI thread.
- **تنفيذ متوازٍ**: تشغيل عدة مهام بالتوازي.
- **دعم callbacks**: hooks مفصلة للسجلات والإحصاءات وانتهاء الجلسة.
- **إدارة الجلسات**: تحكم كامل في دورة حياة التنفيذ: البدء، الإلغاء، والقائمة.
- **قابل للتوسعة**: مصمم لدعم تحميل وتكوين مكتبات أصلية مخصصة.
- **API كاملة لفحص الحزمة**: الحصول على معلومات تفصيلية عن الحزمة، مثل version وbuild date وmuxers وdemuxers وencoders وdecoders وfilters وغيرها.
- **نشر builds مخصصة**: يمكنك نشر builds مخصصة من ffmpeg-kit-extended. راجع: <https://github.com/akashskypatel/ffmpeg-kit-builders>

### دعم المنصات

| المنصة | الحالة | تشغيل الفيديو | المعمارية | الحد الأدنى للمتطلبات |
| --- | --- | --- | --- | --- |
| Android وAndroid TV | ✅ مدعوم | ✅ Native | armv7, arm64, x86_64 | API 26+ |
| iOS والمحاكي | ✅ مدعوم | ✅ Texture | arm64 | iOS 13+ |
| macOS | ✅ مدعوم | ✅ Texture | arm64, x86_64 | macOS 13+ |
| Linux | ✅ مدعوم | ✅ Texture | x86_64 | glibc 2.28+ |
| Windows | ✅ مدعوم | ✅ Texture | x86_64 | Windows 8+ |

يجب عليك تحديث الحد الأدنى لمتطلبات تطبيقك بنفسك ليتطابق مع المتطلبات أعلاه.

## 🎬 عرض توضيحي

<div align="center">
<a href="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif">Click here if the image doesn't load</a>
<br>
<img width="378" height="672" src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif?raw=true" alt="Demo" style="border-radius: 10px;" />
<br>

[_Video demonstration of FFmpegKit Extended Flutter plugin showing real-time video playback, FFmpeg command execution, and the comprehensive introspection API interface._](https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif)

</div>

## 2. التثبيت

1. ثبّت الحزمة:

```bash
flutter pub add ffmpeg_kit_extended_flutter
```

2. أضف قسم `ffmpeg_kit_extended_config` إلى `pubspec.yaml`:

```yaml
ffmpeg_kit_extended_config:
  type: "base" # البُنى المرفقة مسبقًا: debug, base, full, audio, video, video_hw
  gpl: true # فعّل هذا الخيار لتضمين مكتبات GPL
  small: true # فعّل هذا الخيار لاستخدام بُنى أصغر حجمًا
  # == أو ==
  # -------------------------------------------------------------
  # يمكنك تحديد مسار بعيد أو محلي إلى مكتبات libffmpegkit لكل منصة
  # يتيح لك ذلك نشر بُنى مخصصة من libffmpegkit.
  # راجع: https://github.com/akashskypatel/ffmpeg-kit-builders
  # -------------------------------------------------------------
  # windows: "path/to/ffmpeg-kit/libraries"
  # ios: "https://path/to/bundle.xcframework.zip"
```

**ملاحظة**: يتم الآن تنزيل المكتبات الأصلية وتجميعها تلقائيًا أثناء عملية build باستخدام [Dart Hooks](https://dart.dev/tools/hooks). لا يلزم أي script إعداد يدوي.

**مهم**: إذا غيرت bundle بعد إنشاء build باستخدام bundle آخر، فيجب تشغيل `flutter clean` و`flutter build` لإعادة تشغيل build hook وتنزيل الثنائيات المحدثة.

3. استورد الحزمة في كود Dart:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
```

4. قم بتهيئة plugin عند بدء التطبيق **قبل** استدعاء أي API:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FFmpegKitExtended.initialize();
  runApp(MyApp());
}
```

> **مهم**: أي استدعاء لـ FFmpeg أو FFprobe أو FFplay API قبل اكتمال `initialize()` سيرمي `StateError`.

### 2.1 إعداد خاص بالمنصة

1. **iOS ومحاكي iOS**: يجب تحديث Podfile في تطبيقك لإضافة post-install hooks تستثني architectures غير المدعومة. أضف التالي إلى Podfile:

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

### 2.2 Builds مرفقة مسبقًا

- **base**: build أساسي يحتوي على مكتبات FFmpeg الأساسية فقط، ولا يحتوي على مكتبات إضافية.
- **full**: build كامل بكل مكتبات FFmpeg المتوافقة مع المنصة. راجع: <https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries>
- **audio**: build يحتوي على مكتبات FFmpeg الخاصة بالصوت فقط.
- **video**: build يحتوي على مكتبات FFmpeg الخاصة بالفيديو فقط.
- **video_hw**: build يحتوي على مكتبات FFmpeg الخاصة بالفيديو المسرّع عتاديًا.

### 2.2 مصفوفة الميزات

| الميزة     | Base | Audio | Video | Video+Hardware | Full |
| ---------- | ---- | ----- | ----- | -------------- | ---- |
| الفيديو    |      |       | x     | x              | x    |
| الصوت      |      | x     | x     | x              | x    |
| البث       |      | x     | x     | x              | x    |
| العتاد     |      |       |       | x              | x    |
| AI*        |      |       |       |                |      |
| HTTPS      | *    | x     | x     | x              | x    |
| المنصة*    | x    | x     | x     | x              | x    |
| أخرى*      |      |       |       |                | x    |

1. ميزات AI غير مدعومة على جميع المنصات. يجب عليك نشر بناء مخصص خاص بك من ffmpeg-kit-extended لتمكين بعض ميزات AI.
   - راجع [المكتبات الخارجية المدعومة](https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries) لمزيد من المعلومات.

2. ميزات المنصة هي مكتبات مدمجة في المنصة يدعمها FFmpeg، مثل AVFoundation و VideoToolbox وغيرها على منصات Apple، أو DirectX و MediaFoundation على Windows.

3. ميزات HTTPS مفعلة افتراضياً على المنصات التي تحتوي على دعم HTTPS مدمج، مثل Windows أو منصات Apple. في Linux و Android، يتم تمكين OpenSSL افتراضياً.

4. الميزات الأخرى هي ميزات إضافية لا تغطيها الفئات أعلاه. راجع [المكتبات الخارجية المدعومة](https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries) لمزيد من المعلومات.

## 3. الاستخدام

### 3.1 تنفيذ أمر أساسي

نفّذ أمر FFmpeg بشكل غير متزامن:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

FFmpegKit.executeAsync('-i input.mp4 -c:v libx264 output.mp4', onComplete: (session) async {
  final returnCode = session.getReturnCode();

  if (ReturnCode.isSuccess(returnCode)) {
    print("Command success");
  } else if (ReturnCode.isCancel(returnCode)) {
    print("Command cancelled");
  } else {
    print("Command failed with state ${session.getState()}");
    final failStackTrace = session.getFailStackTrace();
    print("Stack trace: $failStackTrace");
  }
});
```

### 3.2 جلب معلومات الوسائط

استخدم `FFprobeKit` للحصول على metadata تفصيلية عن ملف وسائط:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

FFprobeKit.getMediaInformationAsync('path/to/video.mp4', onComplete: (session) {
  final info = session.getMediaInformation();
  if (info != null) {
      print("Duration: ${info.duration}");
      print("Format: ${info.format}");
      for (var stream in info.streams) {
          print("Stream type: ${stream.type}, codec: ${stream.codec}");
      }
  }
});
```

### 3.3 التعامل مع السجلات والإحصاءات

يمكنك تسجيل callbacks للسجلات والإحصاءات لتحسين المراقبة:

```dart
FFmpegKit.executeAsync(
  '-i input.mp4 output.mkv',
  onComplete: (session) { /* استدعاء الإكمال */ },
  onLog: (log) {
    print("Log: ${log.message}");
  },
  onStatistics: (statistics) {
    print("Progress: ${statistics.time} ms, size: ${statistics.size}");
  },
);
```

### 3.4 إدارة الجلسات

كل عملية تنفيذ تعيد كائن `Session` يمكن استخدامه للتحكم في المهمة:

```dart
// إلغاء جلسة محددة
FFmpegKit.cancel(session);

// إلغاء جميع الجلسات النشطة
FFmpegKitExtended.cancelAllSessions();

// عرض جميع الجلسات
final sessions = FFmpegKitExtended.getSessions();
// أو عرض جلسات FFmpeg فقط
final ffmpegSessions = FFmpegKit.getFFmpegSessions();
```

### 3.5 تشغيل الفيديو باستخدام FFplay

يدعم plugin تشغيل فيديو كاملًا باستخدام API سطح موحد متعدد المنصات.

#### تشغيل فيديو أساسي

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
    // إنشاء السطح قبل بدء التشغيل
    _surface = await FFplaySurface.create();

    final session = await FFplayKit.executeAsync('-i "$filePath"');

    // الاستماع إلى أبعاد الفيديو
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

    // الاستماع إلى تحديثات موضع التشغيل
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
        // عرض الفيديو (فقط عند توفر إطارات الفيديو)
        if (_hasVideo && _surface != null)
          SizedBox(
            width: _videoWidth.toDouble(),
            height: _videoHeight.toDouble(),
            child: _surface!.toWidget(),
          ),

        // عناصر التحكم في التشغيل
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

#### استخدام خاص بالمنصة

تتعامل فئة `FFplaySurface` تلقائيًا مع اختلافات المنصات:

- **Android**: يستخدم `SurfaceTexture` مدعومًا بـ `ANativeWindow` للرندر الأصلي.
- **iOS/macOS**: يستخدم textures من `CVPixelBuffer` مع تحسين Metal.
- **Linux/Windows**: يستخدم pixel buffer textures مع frame callbacks.
- **Audio-only**: يتم إنشاء السطح لكن لا يتم عرضه، مما يمنع الأعطال.

#### ميزات متقدمة

```dart
// الحصول على خصائص خاصة بالجلسة
final session = await FFplayKit.executeAsync('-i video.mp4');

// أبعاد الفيديو (تتوفر عند فك ترميز الإطار الأول)
final width = session.getVideoWidth();
final height = session.getVideoHeight();

// التدفقات في الوقت الحقيقي
session.positionStream.listen((pos) => print('Position: ${pos}s'));
session.videoSizeStream.listen((size) => print('Size: ${size}'));

// التحكم في مستوى الصوت
session.setVolume(0.8); // من 0.0 إلى 1.0
print('Volume: ${session.getVolume()}');

// حالة الجلسة
print('Playing: ${session.isPlaying()}');
print('Paused: ${session.isPaused()}');
```

## 4. الترخيص

هذا المشروع مرخص افتراضيًا بموجب LGPL v3.0. ومع ذلك، اعتمادًا على إعدادات build الخاصة بـ FFmpeg والمكتبات الخارجية المستخدمة، قد يكون الترخيص الفعلي GPL v3.0. يرجى مراجعة تراخيص المكتبات المضمنة.

افهم الفرق بين تراخيص LGPL وGPL قبل استخدام هذا plugin في مشروعك.
