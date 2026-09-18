# FFmpegKit Extended لـ Flutter

<div align="center">

<img src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/assets/banner.png" alt="شعار FFmpegKit Extended" width="100%">

[![Stars](https://img.shields.io/github/stars/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/stargazers) [![Forks](https://img.shields.io/github/forks/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/fork) [![Issues](https://img.shields.io/github/issues/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/issues) [![Downloads](https://img.shields.io/pub/dm/ffmpeg_kit_extended_flutter?style=flat-square&logoColor=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub version](https://img.shields.io/pub/v/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub likes](https://img.shields.io/pub/likes/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub points](https://img.shields.io/pub/points/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![License](https://img.shields.io/github/license/akashskypatel/ffmpeg-kit-extended?color=144DB3)](LICENSE)

</div>

## الترجمات

[الإنجليزية](../README.md) | [Español](README.es.md) | [简体中文](README.zh-CN.md) | [हिन्दी](README.hi.md) | **العربية** | [Français](README.fr.md) | [Português (Brasil)](README.pt-BR.md) | [日本語](README.ja.md)


`ffmpeg-kit-extended` هو إضافة Flutter شاملة لتنفيذ أوامر `FFmpeg` و`FFprobe` و`FFplay` باستخدام `9.0.1 API` على `Android` و`iOS` و`macOS` و`Linux` و`Windows`. يستخدم Dart `FFI` للتعامل مباشرة مع مكتبات FFmpeg الأصلية، مما يوفر أداءً عاليًا ومرونة وقدرات كاملة لتشغيل الفيديو.
تستخدم إصدارات Web تقنية WebAssembly في Flutter مع واجهة API العامة نفسها؛ بينما تستخدم المنصات الأصلية Dart FFI.

إذا أعجبك المشروع وتستخدمه في تطبيقك، ضع ⭐ على [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders) و[ffmpeg-kit-extended](https://github.com/akashskypatel/ffmpeg-kit-extended)، وضع 👍 على [pub.dev](https://pub.dev/packages/ffmpeg_kit_extended_flutter).

## 1. الميزات

- **دعم متعدد المنصات**: يعمل على `Android` و`iOS` و`macOS` و`Linux` و`Windows` و`Web` المُمكّن باستخدام WebAssembly.
  - **Android**: دعم كامل لتشغيل الفيديو مع تصيير أصلي عبر surface.
    - **x86**: معمارية `x86` غير مدعومة لأنها قديمة.
  - **iOS وmacOS**: تشغيل فيديو عالي الأداء باستخدام `CVPixelBuffer` وتكامل Metal.
    - **iOS**: يدعم `الأجهزة` الفعلية و`المحاكيات`. معمارية `x86_64` غير مدعومة لأنها قديمة.
  - **Linux**: دعم كامل لتشغيل الفيديو مع تكامل `OpenGL`.
    - **arm64**: معمارية `arm64` غير مدعومة حاليًا، وستتوفر قريبًا.
- **Web (Wasm)**: ينزّل حزمة wasm32 المطابقة عبر خطاف البناء، ويعرض إطارات FFplay بصيغة RGBA باستخدام واجهة surface API الموحدة في Flutter. استخدم `flutter build web --wasm`.
- **`FFmpeg` و`FFprobe` و`FFplay`**: دعم [أحدث `9.0.1 API`](https://www.ffmpeg.org/download.html) لمعالجة الوسائط، واسترجاع المعلومات، وتشغيل الصوت/الفيديو.
- **تشغيل الفيديو**: تشغيل فيديو كامل متعدد المنصات باستخدام API موحد للسطح.
- **البث في الوقت الحقيقي**: تدفقات لموضع التشغيل وأبعاد الفيديو لمراقبة التشغيل المباشر.
- **Dart FFI**: روابط أصلية مباشرة لأفضل أداء.
- **تنفيذ غير متزامن**: تشغيل المهام الطويلة دون حظر خيط واجهة المستخدم.
- **تنفيذ متوازٍ**: تشغيل عدة مهام بالتوازي.
- **دعم الاستدعاءات الراجعة**: خطافات مفصلة للسجلات والإحصاءات وانتهاء الجلسة.
- **إدارة الجلسات**: تحكم كامل في دورة حياة التنفيذ: البدء، الإلغاء، والقائمة.
- **قابل للتوسعة**: مصمم لدعم تحميل وتكوين مكتبات أصلية مخصصة.
- **API كاملة لفحص الحزمة**: الحصول على معلومات تفصيلية عن الحزمة، مثل الإصدار وتاريخ البناء وعمليات المزج والفكّ والترميز وفكّ الترميز والمرشحات وغيرها.
- **نشر بُنى مخصصة**: يمكنك نشر بُنى مخصصة من ffmpeg-kit-extended. راجع: <https://github.com/akashskypatel/ffmpeg-kit-builders>

### دعم المنصات

| المنصة | الحالة | تشغيل الفيديو | المعمارية | الحد الأدنى للمتطلبات |
| --- | --- | --- | --- | --- |
| Android وAndroid TV | ✅ مدعوم | ✅ أصلي | armv7, arm64, x86_64 | API 26+ |
| iOS والمحاكي | ✅ مدعوم | ✅ Texture | arm64 | iOS 13+ |
| macOS | ✅ مدعوم | ✅ Texture | arm64, x86_64 | macOS 13+ |
| Linux | ✅ مدعوم | ✅ Texture | x86_64 | glibc 2.28+ |
| Windows | ✅ مدعوم | ✅ Texture | x86_64 | Windows 8+ |
| Web (Wasm) | ✅ مدعوم | ✅ إطارات RGBA | wasm32 | بناء Flutter Wasm |

يجب عليك تحديث الحد الأدنى لمتطلبات تطبيقك بنفسك ليتطابق مع المتطلبات أعلاه.

## 🎬 عرض توضيحي

<div align="center">
<a href="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif">انقر هنا إذا لم تُحمّل الصورة</a>
<br>
<img width="378" height="672" src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif?raw=true" alt="عرض توضيحي" style="border-radius: 10px;" />
<br>

[_عرض توضيحي لفيديو إضافة FFmpegKit Extended لـ Flutter يوضح تشغيل الفيديو في الوقت الفعلي، وتنفيذ أوامر FFmpeg، وواجهة API الشاملة للفحص._](https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif)

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

**السلوك الحالي:** يتم تنزيل المكتبات الأصلية وحزمة WebAssembly وتجميعهما تلقائيًا عبر Dart Hooks. تستخدم إصدارات Web إعداد `wasm` أو `web` البديل عند توفيره؛ وإلا يحدد الخطاف الحزمة المطابقة للإصدار المثبت. تتم متابعة ملفات الإعدادات البديلة المحلية، لذلك لا يلزم تشغيل `flutter clean` عند تغيير محتوياتها.
**مهم:** أعد تشغيل البناء بعد تغيير إعداد الحزمة المحددة. تُتتبّع تغييرات محتوى الإعدادات البديلة المحلية باعتبارها تبعيات، ولا تتطلب `flutter clean`.

3. استورد الحزمة في كود Dart:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
```

4. قم بتهيئة الإضافة عند بدء التطبيق **قبل** استدعاء أي API:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FFmpegKitExtended.initialize();
  runApp(MyApp());
}
```

> **مهم**: أي استدعاء لـ FFmpeg أو FFprobe أو FFplay API قبل اكتمال `initialize()` سيرمي `StateError`.

**مساحات عمل Dart Pub:** تتقدّم `pubspec` الموجودة في جذر package-config. وإلا، لا يجوز توفير الإعداد إلا من جذور رسم بياني للحزم تقع داخل الجذر وتملك مسار تبعية عاديًا إلى هذه الحزمة. تفشل الحالات التي تحتوي على مرشحين غير واضحين بدلًا من التخمين؛ وإذا لم يوجد مرشح منطبق، تُستخدم حزمة `base` الصغيرة المرخصة بـ LGPL. تُحلّ مسارات الإعدادات البديلة المحلية النسبية انطلاقًا من `pubspec` المعرِّفة، ويتابعها خطاف البناء. بالنسبة إلى Web، اضبط حزمة التطبيق المستهلكة عند استخدام التجهيز اليدوي القديم.

على سبيل المثال، في جذر مساحة العمل:

~~~yaml
ffmpeg_kit_extended_config:
  type: "video"
  gpl: true
~~~

### بناء Web ونشره

للتطوير المحلي لـ Web باستخدام Wasm، استخدم عزل الأصل المشترك في Flutter لكي تتمكن Wasm المفعّلة بـ pthread من نقل الذاكرة المشتركة إلى العمال:

~~~bash
flutter run -d web-server --cross-origin-isolation
~~~

أنشئ Flutter Web باستخدام Wasm:

~~~bash
flutter clean
flutter build web --wasm
~~~

تدعم حزمة WebAssembly pthread افتراضيًا. ويتطلب البناء غير المعتمد على pthread تبعية WebAssembly مخصصة وبناء حزمة من ffmpeg-kit-builders.

ينزّل خطاف البناء حزمة wasm32 ويتحقق منها، ثم يجهّز وقت تشغيل Wasm والمحمّل وجسر الاستدعاءات الراجعة ووحدات الدعم كأصول Web. تتطلب حزم Wasm متعددة الخيوط رؤوس استجابة HTTP التالية:

~~~http
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
~~~

تحقق من أن قيمة window.crossOriginIsolated هي true قبل استخدام حزمة WebAssembly. يجب أن تستوفي أصول Wasm وJavaScript والعمال وغيرها التي يتم جلبها سياسة COEP المحددة.

#### قيد أهداف الاختبار في Flutter

يقيّم Flutter خطاف بناء الأصول الأصلية للمنصة المضيفة TargetPlatform.tester عند تشغيل الاختبارات. لذلك لا يمكن لـ `flutter test` جعل خطاف هذه الحزمة يختار أصولًا لمنصة غير مضيفة. ينطبق ذلك على جميع المنصات المستهدفة. استخدم أمر البناء أو التشغيل الخاص بالمنصة للتحقق من الهدف.

### 2.1 إعداد خاص بالمنصة

1. **iOS ومحاكي iOS**: يجب تحديث Podfile في تطبيقك لإضافة خطافات ما بعد التثبيت (`post-install`) تستثني المعماريات غير المدعومة. أضف التالي إلى Podfile:

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

### 2.2 البُنى المرفقة مسبقًا

- **base**: بنية أساسية تحتوي على مكتبات FFmpeg الأساسية فقط، ولا تحتوي على مكتبات إضافية.
- **full**: بنية كاملة بكل مكتبات FFmpeg المتوافقة مع المنصة. راجع: <https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries>
- **audio**: بنية تحتوي على مكتبات FFmpeg الخاصة بالصوت فقط.
- **video**: بنية تحتوي على مكتبات FFmpeg الخاصة بالفيديو فقط.
- **video_hw**: بنية تحتوي على مكتبات FFmpeg الخاصة بالفيديو المسرّع عتاديًا.

### 2.2 مصفوفة الميزات

#### ترخيص GPL

يؤدي تمكين مكتبات GPL إلى جعل ملف FFmpeg الناتج مرخصًا بـ GPL، وقد يتطلب توزيع تطبيقك بموجب GPL. استخدم حزمة LGPL ما لم تكن تفهم تبعات الترخيص.

#### الذكاء الاصطناعي

مكتبات الذكاء الاصطناعي مثل libopenvino وlibtensorflow مخصصة لأجهزة سطح المكتب فقط في الحزم المنشورة. تتوفر libtorch على Linux فقط، ولا تتوفر libonnxruntime على macOS بمعمارية x86_64، وتتطلب مكتبات الذكاء الاصطناعي المعتمدة على GPU نشرًا مخصصًا. يوضح الجدول الحالي دعم الذكاء الاصطناعي في بُنى Full.

| الميزة     | Base | Audio | Video | Video+Hardware | Full |
| ---------- | ---- | ----- | ----- | -------------- | ---- |
| الفيديو    |      |       | x     | x              | x    |
| الصوت      |      | x     | x     | x              | x    |
| البث       |      | x     | x     | x              | x    |
| العتاد     |      |       |       | x              | x    |
| الذكاء الاصطناعي* |      |       |       |                | x*   |
| HTTPS      | *    | x     | x     | x              | x    |
| المنصة*    | x    | x     | x     | x              | x    |
| أخرى*      |      |       |       |                | x    |

1. ميزات الذكاء الاصطناعي غير مدعومة على جميع المنصات. يجب عليك نشر بنية مخصصة خاصة بك من ffmpeg-kit-extended لتمكين بعض ميزات الذكاء الاصطناعي.
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
    print("نجح الأمر");
  } else if (ReturnCode.isCancel(returnCode)) {
    print("أُلغي الأمر");
  } else {
    print("فشل الأمر بالحالة ${session.getState()}");
    final failStackTrace = session.getFailStackTrace();
    print("تتبّع المكدس: $failStackTrace");
  }
});
```

### 3.2 جلب معلومات الوسائط

استخدم `FFprobeKit` للحصول على بيانات وصفية تفصيلية عن ملف وسائط:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

FFprobeKit.getMediaInformationAsync('path/to/video.mp4', onComplete: (session) {
  final info = session.getMediaInformation();
  if (info != null) {
      print("المدة: ${info.duration}");
      print("التنسيق: ${info.format}");
      for (var stream in info.streams) {
          print("نوع التدفق: ${stream.type}، برنامج الترميز: ${stream.codec}");
      }
  }
});
```

### 3.3 التعامل مع السجلات والإحصاءات

يمكنك تسجيل الاستدعاءات الراجعة للسجلات والإحصاءات لتحسين المراقبة:

```dart
FFmpegKit.executeAsync(
  '-i input.mp4 output.mkv',
  onComplete: (session) { /* استدعاء الإكمال */ },
  onLog: (log) {
    print("السجل: ${log.message}");
  },
  onStatistics: (statistics) {
    print("التقدم: ${statistics.time} مللي ثانية، الحجم: ${statistics.size}");
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

تدعم الإضافة تشغيل فيديو كامل باستخدام API سطح موحد متعدد المنصات.

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

- **Android**: يستخدم `SurfaceTexture` مدعومًا بـ `ANativeWindow` للتصيير الأصلي.
- **iOS/macOS**: يستخدم أنسجة من `CVPixelBuffer` مع تحسين Metal.
- **Linux/Windows**: يستخدم أنسجة مخازن البكسل مع استدعاءات الإطارات.
- **Web**: ينسخ إطارات RGBA8888 من ذاكرة Wasm ويرسمها كصور Flutter.
- **الصوت فقط**: يتم إنشاء السطح لكن لا يتم عرضه، مما يمنع الأعطال.

#### ميزات متقدمة

```dart
// الحصول على خصائص خاصة بالجلسة
final session = await FFplayKit.executeAsync('-i video.mp4');

// أبعاد الفيديو (تتوفر عند فك ترميز الإطار الأول)
final width = session.getVideoWidth();
final height = session.getVideoHeight();

// التدفقات في الوقت الحقيقي
session.positionStream.listen((pos) => print('الموضع: ${pos}s'));
session.videoSizeStream.listen((size) => print('الحجم: ${size}'));

// التحكم في مستوى الصوت
session.setVolume(0.8); // من 0.0 إلى 1.0
print('مستوى الصوت: ${session.getVolume()}');

// حالة الجلسة
print('قيد التشغيل: ${session.isPlaying()}');
print('متوقف مؤقتًا: ${session.isPaused()}');
```

### أحجام الحزم

تعرض الجداول أحجام ثنائيات `libffmpegkit` غير المضغوطة بالميغابايت العشري. يوضح كل نطاق الحد الأدنى المقاس لحزمة LGPL والحد الأقصى المقاس لحزمة GPL في إصدارات v0.11.2.

| نوع الحزمة | Android (MB) | iOS (MB) | macOS (MB) | Linux (MB) | Windows (MB) |
|-------------|--------------|----------|------------|------------|--------------|
| debug       | 81.2-82.0    | 37.8-38.2 | 41.6-42.0  | 133.5-139.6 | 480.4-490.8  |
| base        | 73.4-93.0    | 36.0-48.6 | 39.8-54.3  | 31.6-44.2   | 41.3-55.2    |
| audio       | 102.6-179.1  | 74.6-126.0| 79.8-134.2 | 49.3-86.7   | 82.9-124.1   |
| video       | 233.0-353.0  | 160.7-227.4| 183.5-255.5| 164.6-232.1 | 215.0-281.1  |
| video_hw    | 239.4-359.9  | 163.8-230.7| 186.8-259.0| 171.3-239.2 | 219.0-285.4  |
| full        | 267.1-387.5  | 182.0-248.8| 223.3-295.4| 209.0-276.2 | 248.4-314.8  |

## 4. المكتبات الخارجية المدعومة<a id="libraries"></a>

تتم صيانة مصفوفة المنصات والحزم الحالية الكاملة في [README الإنجليزي الأساسي](../README.md#libraries).

## 5. الترخيص

هذا المشروع مرخص افتراضيًا بموجب LGPL v3.0. ومع ذلك، اعتمادًا على إعدادات البناء الخاصة بـ FFmpeg والمكتبات الخارجية المستخدمة، قد يكون الترخيص الفعلي GPL v3.0. يرجى مراجعة تراخيص المكتبات المضمنة.

افهم الفرق بين تراخيص LGPL وGPL قبل استخدام هذه الإضافة في مشروعك.
