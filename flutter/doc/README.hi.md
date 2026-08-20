# Flutter के लिए FFmpegKit Extended

<div align="center">

<img src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/assets/banner.png" alt="FFmpegKit Extended बैनर" width="100%">

[![Stars](https://img.shields.io/github/stars/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/stargazers) [![Forks](https://img.shields.io/github/forks/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/fork) [![Issues](https://img.shields.io/github/issues/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/issues) [![Downloads](https://img.shields.io/pub/dm/ffmpeg_kit_extended_flutter?style=flat-square&logoColor=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub version](https://img.shields.io/pub/v/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub likes](https://img.shields.io/pub/likes/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub points](https://img.shields.io/pub/points/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![License](https://img.shields.io/github/license/akashskypatel/ffmpeg-kit-extended?color=144DB3)](LICENSE)

</div>

## अनुवाद

[English](../README.md) | [Español](README.es.md) | [简体中文](README.zh-CN.md) | **हिन्दी** | [العربية](README.ar.md) | [Français](README.fr.md) | [Português (Brasil)](README.pt-BR.md) | [日本語](README.ja.md)

`ffmpeg-kit-extended` एक व्यापक Flutter प्लगइन है, जिससे `Android`, `iOS`, `macOS`, `Linux` और `Windows` पर `FFmpeg`, `FFprobe` और `FFplay` के `9.0.1 API` कमांड चलाए जा सकते हैं। यह Dart `FFI` के माध्यम से मूल FFmpeg पुस्तकालयों से सीधे संपर्क करता है, जिससे उच्च प्रदर्शन, लचीलापन और पूर्ण वीडियो-प्लेबैक क्षमता मिलती है।

यदि आपको यह परियोजना उपयोगी लगती है और आप इसे अपने ऐप में इस्तेमाल कर रहे हैं, तो [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders) और [ffmpeg-kit-extended](https://github.com/akashskypatel/ffmpeg-kit-extended) पर ⭐ दें, और [pub.dev](https://pub.dev/packages/ffmpeg_kit_extended_flutter) पर 👍 दें। इससे बहुत मदद मिलती है 🙏! कोडिंग का आनंद लें 🚀!

## 1. विशेषताएँ

- **बहु-प्लेटफ़ॉर्म समर्थन**: `Android`, `iOS`, `macOS`, `Linux` और `Windows` पर काम करता है।
  - **Android**: मूल सर्फ़ेस रेंडरिंग के साथ पूर्ण वीडियो-प्लेबैक समर्थन।
    - **x86**: पुरानी स्थिति के कारण `x86` आर्किटेक्चर समर्थित नहीं है।
  - **iOS और macOS**: `CVPixelBuffer` और Metal एकीकरण के साथ उच्च-प्रदर्शन वीडियो प्लेबैक।
    - **iOS**: वास्तविक `devices` और `simulators`, दोनों का समर्थन करता है। पुरानी स्थिति के कारण `x86_64` आर्किटेक्चर समर्थित नहीं है।
  - **Linux**: `OpenGL` एकीकरण के साथ पूर्ण वीडियो-प्लेबैक समर्थन।
    - **arm64**: `arm64` आर्किटेक्चर अभी समर्थित नहीं है; जल्द उपलब्ध होगा।
- **`FFmpeg`, `FFprobe` और `FFplay`**: मीडिया संसाधन, जानकारी निकालने और ऑडियो/वीडियो चलाने के लिए [नवीनतम `9.0.1 API`](https://www.ffmpeg.org/download.html) समर्थन।
- **वीडियो प्लेबैक**: एकीकृत सर्फ़ेस API के साथ पूर्ण बहु-प्लेटफ़ॉर्म वीडियो प्लेबैक।
- **रीयल-टाइम स्ट्रीमिंग**: लाइव प्लेबैक निगरानी के लिए स्थिति और वीडियो-आयाम स्ट्रीम।
- **Dart FFI**: सर्वोत्तम प्रदर्शन के लिए प्रत्यक्ष मूल बाइंडिंग।
- **असमकालिक निष्पादन**: UI थ्रेड को रोके बिना लंबी चलने वाली प्रक्रियाएँ चलाएँ।
- **समानांतर निष्पादन**: कई प्रक्रियाएँ साथ-साथ चलाएँ।
- **कॉलबैक समर्थन**: लॉग, आँकड़ों और सत्र पूरा होने के लिए विस्तृत हुक।
- **सत्र प्रबंधन**: निष्पादन जीवनचक्र पर पूरा नियंत्रण: शुरू करना, रद्द करना और सूची देखना।
- **विस्तार योग्य**: कस्टम मूल पुस्तकालय लोडिंग और कॉन्फ़िगरेशन की अनुमति देने के लिए बनाया गया।
- **पूर्ण पैकेज निरीक्षण API**: पैकेज के बारे में विस्तृत जानकारी प्राप्त करें, जैसे संस्करण, बिल्ड तिथि, उपलब्ध muxers, demuxers, encoders, decoders, filters आदि।
- **कस्टम बिल्ड तैनात करें**: आप ffmpeg-kit-extended के कस्टम बिल्ड तैनात कर सकते हैं। देखें: <https://github.com/akashskypatel/ffmpeg-kit-builders>

### प्लेटफ़ॉर्म समर्थन

| प्लेटफ़ॉर्म | स्थिति | वीडियो प्लेबैक | आर्किटेक्चर | न्यूनतम आवश्यकताएँ |
| --- | --- | --- | --- | --- |
| Android और Android TV | ✅ समर्थित | ✅ मूल | armv7, arm64, x86_64 | API 26+ |
| iOS और सिम्युलेटर | ✅ समर्थित | ✅ टेक्सचर | arm64 | iOS 13+ |
| macOS | ✅ समर्थित | ✅ टेक्सचर | arm64, x86_64 | macOS 13+ |
| Linux | ✅ समर्थित | ✅ टेक्सचर | x86_64 | glibc 2.28+ |
| Windows | ✅ समर्थित | ✅ टेक्सचर | x86_64 | Windows 8+ |

ऊपर दी गई आवश्यकताओं से मेल खाने के लिए आपको अपने ऐप की न्यूनतम आवश्यकताएँ स्वयं अपडेट करनी होंगी।

## 🎬 डेमो

<div align="center">
<a href="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif">यदि छवि लोड नहीं होती है तो यहाँ क्लिक करें</a>
<br>
<img width="378" height="672" src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif?raw=true" alt="डेमो" style="border-radius: 10px;" />
<br>

[_FFmpegKit Extended Flutter प्लगइन का वीडियो प्रदर्शन, जिसमें रीयल-टाइम वीडियो प्लेबैक, FFmpeg कमांड निष्पादन और व्यापक निरीक्षण API इंटरफ़ेस दिखाया गया है।_](https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif)

</div>

## 2. स्थापना

1. पैकेज स्थापित करें:

```bash
flutter pub add ffmpeg_kit_extended_flutter
```

2. अपने `pubspec.yaml` में `ffmpeg_kit_extended_config` अनुभाग जोड़ें:

```yaml
ffmpeg_kit_extended_config:
  type: "base" # पहले से बंडल किए गए बिल्ड: debug, base, full, audio, video, video_hw
  gpl: true # GPL पुस्तकालय शामिल करने के लिए सक्षम करें
  small: true # छोटे बिल्ड इस्तेमाल करने के लिए सक्षम करें
  # == या ==
  # -------------------------------------------------------------
  # आप हर प्लेटफ़ॉर्म के लिए libffmpegkit पुस्तकालयों का दूरस्थ या स्थानीय पथ दे सकते हैं
  # इससे आप libffmpegkit के कस्टम बिल्ड तैनात कर सकते हैं।
  # देखें: https://github.com/akashskypatel/ffmpeg-kit-builders
  # -------------------------------------------------------------
  # windows: "path/to/ffmpeg-kit/libraries"
  # ios: "https://path/to/bundle.xcframework.zip"
```

**ध्यान दें**: मूल पुस्तकालय अब [Dart Hooks](https://dart.dev/tools/hooks) का उपयोग करके बिल्ड प्रक्रिया के दौरान अपने-आप डाउनलोड और बंडल किए जाते हैं। किसी मैन्युअल कॉन्फ़िगरेशन स्क्रिप्ट की आवश्यकता नहीं है।

**महत्वपूर्ण**: यदि आप किसी दूसरे बंडल से पहले ही बिल्ड बना चुके हैं और उसके बाद बंडल बदलते हैं, तो नए बंडल चयन के लिए बिल्ड हुक फिर से चलाने और अपडेट किए गए बाइनरी डाउनलोड करने हेतु `flutter clean` और `flutter build` चलाना होगा।

3. अपने Dart कोड में पैकेज आयात करें:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
```

4. किसी भी API को कॉल करने से **पहले**, ऐप शुरू होते समय प्लगइन प्रारंभ करें:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FFmpegKitExtended.initialize();
  runApp(MyApp());
}
```

> **महत्वपूर्ण**: `initialize()` पूरा होने से पहले की गई कोई भी FFmpeg, FFprobe या FFplay API कॉल `StateError` फेंकेगी।

### 2.1 प्लेटफ़ॉर्म-विशिष्ट कॉन्फ़िगरेशन

1. **iOS और iOS सिम्युलेटर**: असमर्थित आर्किटेक्चर के लिए बिल्ड बनने से रोकने हेतु आपके ऐप के Podfile में post-install hooks जोड़ने होंगे। अपने Podfile में यह जोड़ें:

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

### 2.2 पहले से बंडल किए गए बिल्ड

- **base**: मूल FFmpeg पुस्तकालयों वाला बुनियादी बिल्ड। इसमें कोई अतिरिक्त पुस्तकालय शामिल नहीं है।
- **full**: प्लेटफ़ॉर्म-संगत सभी FFmpeg पुस्तकालयों वाला पूर्ण बिल्ड। देखें: <https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries>
- **audio**: केवल ऑडियो FFmpeg पुस्तकालयों वाला बिल्ड।
- **video**: केवल वीडियो FFmpeg पुस्तकालयों वाला बिल्ड।
- **video_hw**: हार्डवेयर-त्वरित वीडियो FFmpeg पुस्तकालयों वाला बिल्ड।

### 2.2 विशेषता मैट्रिक्स

| विशेषता | Base | Audio | Video | Video+Hardware | Full |
| --- | --- | --- | --- | --- | --- |
| वीडियो | | | x | x | x |
| ऑडियो | | x | x | x | x |
| स्ट्रीमिंग | | x | x | x | x |
| हार्डवेयर | | | | x | x |
| AI* | | | | | |
| HTTPS | * | x | x | x | x |
| प्लेटफ़ॉर्म* | x | x | x | x | x |
| अन्य* | | | | | x |

1. AI विशेषताएँ सभी प्लेटफ़ॉर्म पर समर्थित नहीं हैं। कुछ AI विशेषताओं को सक्षम करने के लिए आपको ffmpeg-kit-extended का अपना कस्टम बिल्ड तैनात करना होगा।
   - अधिक जानकारी के लिए [समर्थित बाहरी पुस्तकालय](https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries) देखें।

2. प्लेटफ़ॉर्म विशेषताएँ वे अंतर्निहित प्लेटफ़ॉर्म पुस्तकालय हैं जिनका FFmpeg समर्थन करता है, जैसे Apple प्लेटफ़ॉर्म पर AVFoundation, VideoToolbox आदि, या Windows पर DirectX और MediaFoundation।

3. HTTPS विशेषताएँ उन प्लेटफ़ॉर्म पर डिफ़ॉल्ट रूप से सक्षम होती हैं जिनमें अंतर्निहित HTTPS समर्थन होता है, जैसे Windows या Apple। Linux और Android पर OpenSSL डिफ़ॉल्ट रूप से सक्षम होता है।

4. अन्य विशेषताएँ वे अतिरिक्त सुविधाएँ हैं जो ऊपर दी गई श्रेणियों में शामिल नहीं हैं। अधिक जानकारी के लिए [समर्थित बाहरी पुस्तकालय](https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries) देखें।

## 3. उपयोग

### 3.1 बुनियादी कमांड निष्पादन

FFmpeg कमांड को असमकालिक रूप से चलाएँ:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

FFmpegKit.executeAsync('-i input.mp4 -c:v libx264 output.mp4', onComplete: (session) async {
  final returnCode = session.getReturnCode();

  if (ReturnCode.isSuccess(returnCode)) {
    print("कमांड सफल रहा");
  } else if (ReturnCode.isCancel(returnCode)) {
    print("कमांड रद्द किया गया");
  } else {
    print("कमांड इस स्थिति के साथ विफल रहा: ${session.getState()}");
    final failStackTrace = session.getFailStackTrace();
    print("स्टैक ट्रेस: $failStackTrace");
  }
});
```

### 3.2 मीडिया जानकारी प्राप्त करना

किसी मीडिया फ़ाइल के बारे में विस्तृत मेटाडेटा पाने के लिए `FFprobeKit` का उपयोग करें:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

FFprobeKit.getMediaInformationAsync('path/to/video.mp4', onComplete: (session) {
  final info = session.getMediaInformation();
  if (info != null) {
      print("अवधि: ${info.duration}");
      print("फ़ॉर्मैट: ${info.format}");
      for (var stream in info.streams) {
          print("स्ट्रीम प्रकार: ${stream.type}, कोडेक: ${stream.codec}");
      }
  }
});
```

### 3.3 लॉग और आँकड़े संभालना

बेहतर निगरानी के लिए आप लॉग और आँकड़ों वाले कॉलबैक दर्ज कर सकते हैं:

```dart
FFmpegKit.executeAsync(
  '-i input.mp4 output.mkv',
  onComplete: (session) { /* पूरा होने पर चलने वाला कॉलबैक */ },
  onLog: (log) {
    print("लॉग: ${log.message}");
  },
  onStatistics: (statistics) {
    print("प्रगति: ${statistics.time} ms, आकार: ${statistics.size}");
  },
);
```

### 3.4 सत्र प्रबंधन

हर निष्पादन एक `Session` ऑब्जेक्ट लौटाता है, जिसका उपयोग कार्य को नियंत्रित करने के लिए किया जा सकता है:

```dart
// किसी विशेष सत्र को रद्द करें
FFmpegKit.cancel(session);

// सभी सक्रिय सत्रों को रद्द करें
FFmpegKitExtended.cancelAllSessions();

// सभी सत्रों की सूची लें
final sessions = FFmpegKitExtended.getSessions();
// या केवल FFmpeg सत्रों की सूची लें
final ffmpegSessions = FFmpegKit.getFFmpegSessions();
```

### 3.5 FFplay वीडियो प्लेबैक

यह प्लगइन एकीकृत बहु-प्लेटफ़ॉर्म सर्फ़ेस API के साथ पूर्ण वीडियो प्लेबैक का समर्थन करता है।

#### बुनियादी वीडियो प्लेबैक

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
    // प्लेबैक शुरू करने से पहले सर्फ़ेस बनाएँ
    _surface = await FFplaySurface.create();

    final session = await FFplayKit.executeAsync('-i "$filePath"');

    // वीडियो आयामों को सुनें
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

    // स्थिति अपडेट सुनें
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
        // वीडियो प्रदर्शन: केवल तब जब वीडियो फ़्रेम उपलब्ध हों
        if (_hasVideo && _surface != null)
          SizedBox(
            width: _videoWidth.toDouble(),
            height: _videoHeight.toDouble(),
            child: _surface!.toWidget(),
          ),

        // प्लेबैक नियंत्रण
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

#### प्लेटफ़ॉर्म-विशिष्ट उपयोग

`FFplaySurface` क्लास प्लेटफ़ॉर्म के अंतर अपने-आप संभालती है:

- **Android**: मूल रेंडरिंग के लिए `SurfaceTexture` आधारित `ANativeWindow` का उपयोग करता है।
- **iOS/macOS**: Metal अनुकूलन के साथ `CVPixelBuffer` टेक्सचर का उपयोग करता है।
- **Linux/Windows**: फ़्रेम कॉलबैक के साथ पिक्सेल-बफ़र टेक्सचर का उपयोग करता है।
- **केवल ऑडियो**: क्रैश रोकने के लिए सर्फ़ेस बनाया जाता है, लेकिन दिखाया नहीं जाता।

#### उन्नत विशेषताएँ

```dart
// सत्र-विशिष्ट गुण प्राप्त करें
final session = await FFplayKit.executeAsync('-i video.mp4');

// वीडियो आयाम: पहला फ़्रेम डिकोड होने पर उपलब्ध
final width = session.getVideoWidth();
final height = session.getVideoHeight();

// रीयल-टाइम स्ट्रीम
session.positionStream.listen((pos) => print('स्थिति: ${pos}s'));
session.videoSizeStream.listen((size) => print('आकार: ${size}'));

// वॉल्यूम नियंत्रण
session.setVolume(0.8); // 0.0 से 1.0 तक
print('वॉल्यूम: ${session.getVolume()}');

// सत्र स्थिति
print('चल रहा है: ${session.isPlaying()}');
print('रुका हुआ है: ${session.isPaused()}');
```

## 4. लाइसेंस

यह परियोजना डिफ़ॉल्ट रूप से LGPL v3.0 के अंतर्गत लाइसेंस प्राप्त है। हालांकि, अंतर्निहित FFmpeg बिल्ड कॉन्फ़िगरेशन और उपयोग किए गए बाहरी पुस्तकालयों के आधार पर प्रभावी लाइसेंस GPL v3.0 हो सकता है। कृपया शामिल पुस्तकालयों के लाइसेंस देखें।

अपने प्रोजेक्ट में इस प्लगइन का उपयोग करने से पहले LGPL और GPL लाइसेंस के बीच का अंतर समझ लें।

अपने एप्लिकेशन में GPL-लाइसेंस प्राप्त घटकों का उपयोग करने पर आपके एप्लिकेशन को भी GPL के अंतर्गत लाइसेंस करना पड़ सकता है।
