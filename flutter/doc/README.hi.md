# Flutter के लिए FFmpegKit Extended

<div align="center">

<img src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/assets/banner.png" alt="FFmpegKit Extended बैनर" width="100%">

[![Stars](https://img.shields.io/github/stars/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/stargazers) [![Forks](https://img.shields.io/github/forks/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/fork) [![Issues](https://img.shields.io/github/issues/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/issues) [![Downloads](https://img.shields.io/pub/dm/ffmpeg_kit_extended_flutter?style=flat-square&logoColor=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub version](https://img.shields.io/pub/v/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub likes](https://img.shields.io/pub/likes/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub points](https://img.shields.io/pub/points/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![License](https://img.shields.io/github/license/akashskypatel/ffmpeg-kit-extended?color=144DB3)](LICENSE)

</div>

## अनुवाद

[अंग्रेज़ी](../README.md) | [Español](README.es.md) | [简体中文](README.zh-CN.md) | **हिन्दी** | [العربية](README.ar.md) | [Français](README.fr.md) | [Português (Brasil)](README.pt-BR.md) | [日本語](README.ja.md)

`ffmpeg-kit-extended` एक व्यापक Flutter प्लगइन है, जिससे `Android`, `iOS`, `macOS`, `Linux` और `Windows` पर `FFmpeg`, `FFprobe` और `FFplay` के `9.0.1 API` कमांड चलाए जा सकते हैं। यह Dart `FFI` के माध्यम से मूल FFmpeg पुस्तकालयों से सीधे संपर्क करता है, जिससे उच्च प्रदर्शन, लचीलापन और पूर्ण वीडियो-प्लेबैक क्षमता मिलती है।
Web बिल्ड Flutter WebAssembly का उपयोग करते हैं और वही सार्वजनिक API प्रदान करते हैं; मूल प्लेटफ़ॉर्म Dart FFI का उपयोग करते हैं।

यदि आपको यह परियोजना उपयोगी लगती है और आप इसे अपने ऐप में इस्तेमाल कर रहे हैं, तो [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders) और [ffmpeg-kit-extended](https://github.com/akashskypatel/ffmpeg-kit-extended) पर ⭐ दें, और [pub.dev](https://pub.dev/packages/ffmpeg_kit_extended_flutter) पर 👍 दें। इससे बहुत मदद मिलती है 🙏! कोडिंग का आनंद लें 🚀!

## 1. विशेषताएँ

- **बहु-प्लेटफ़ॉर्म समर्थन**: `Android`, `iOS`, `macOS`, `Linux`, `Windows` और WebAssembly-सक्षम Web बिल्ड पर काम करता है।
  - **Android**: मूल सर्फ़ेस रेंडरिंग के साथ पूर्ण वीडियो-प्लेबैक समर्थन।
    - **x86**: पुरानी स्थिति के कारण `x86` आर्किटेक्चर समर्थित नहीं है।
  - **iOS और macOS**: `CVPixelBuffer` और Metal एकीकरण के साथ उच्च-प्रदर्शन वीडियो प्लेबैक।
    - **iOS**: वास्तविक `डिवाइस` और `सिम्युलेटर`, दोनों का समर्थन करता है। पुरानी स्थिति के कारण `x86_64` आर्किटेक्चर समर्थित नहीं है।
  - **Linux**: `OpenGL` एकीकरण के साथ पूर्ण वीडियो-प्लेबैक समर्थन।
    - **arm64**: `arm64` आर्किटेक्चर अभी समर्थित नहीं है; जल्द उपलब्ध होगा।
- **Web (Wasm)**: बिल्ड हुक के दौरान संबंधित wasm32 बंडल डाउनलोड करता है और Flutter की एकीकृत surface API के माध्यम से FFplay RGBA फ़्रेम रेंडर करता है। `flutter build web --wasm` का उपयोग करें।
- **`FFmpeg`, `FFprobe` और `FFplay`**: मीडिया संसाधन, जानकारी निकालने और ऑडियो/वीडियो चलाने के लिए [नवीनतम `9.0.1 API`](https://www.ffmpeg.org/download.html) समर्थन।
- **वीडियो प्लेबैक**: एकीकृत सर्फ़ेस API के साथ पूर्ण बहु-प्लेटफ़ॉर्म वीडियो प्लेबैक।
- **रीयल-टाइम स्ट्रीमिंग**: लाइव प्लेबैक निगरानी के लिए स्थिति और वीडियो-आयाम स्ट्रीम।
- **Dart FFI**: सर्वोत्तम प्रदर्शन के लिए प्रत्यक्ष मूल बाइंडिंग।
- **असमकालिक निष्पादन**: UI थ्रेड को रोके बिना लंबी चलने वाली प्रक्रियाएँ चलाएँ।
- **समानांतर निष्पादन**: कई प्रक्रियाएँ साथ-साथ चलाएँ।
- **कॉलबैक समर्थन**: लॉग, आँकड़ों और सत्र पूरा होने के लिए विस्तृत हुक।
- **सत्र प्रबंधन**: निष्पादन जीवनचक्र पर पूरा नियंत्रण: शुरू करना, रद्द करना और सूची देखना।
- **विस्तार योग्य**: कस्टम मूल पुस्तकालय लोडिंग और कॉन्फ़िगरेशन की अनुमति देने के लिए बनाया गया।
- **पूर्ण पैकेज निरीक्षण API**: पैकेज के बारे में विस्तृत जानकारी प्राप्त करें, जैसे संस्करण, बिल्ड तिथि, उपलब्ध muxer, demuxer, encoder, decoder, filter आदि।
- **कस्टम बिल्ड तैनात करें**: आप ffmpeg-kit-extended के कस्टम बिल्ड तैनात कर सकते हैं। देखें: <https://github.com/akashskypatel/ffmpeg-kit-builders>

### प्लेटफ़ॉर्म समर्थन

| प्लेटफ़ॉर्म | स्थिति | वीडियो प्लेबैक | आर्किटेक्चर | न्यूनतम आवश्यकताएँ |
| --- | --- | --- | --- | --- |
| Android और Android TV | ✅ समर्थित | ✅ मूल | armv7, arm64, x86_64 | API 26+ |
| iOS और सिम्युलेटर | ✅ समर्थित | ✅ टेक्सचर | arm64 | iOS 13+ |
| macOS | ✅ समर्थित | ✅ टेक्सचर | arm64, x86_64 | macOS 13+ |
| Linux | ✅ समर्थित | ✅ टेक्सचर | x86_64 | glibc 2.28+ |
| Windows | ✅ समर्थित | ✅ टेक्सचर | x86_64 | Windows 8+ |
| Web (Wasm) | ✅ समर्थित | ✅ RGBA फ़्रेम | wasm32 | Flutter Wasm बिल्ड |

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

वर्तमान न्यूनतम आवश्यकताएँ: Flutter **3.47.0** और Dart **3.12.0**।

1. पैकेज स्थापित करें:

```bash
flutter pub add ffmpeg_kit_extended_flutter
```

2. workspace-root (या standalone app-root) `pubspec.yaml` में आधिकारिक Hooks `user_defines` अनुभाग जोड़ें। `ffmpeg_kit_extended_config` केवल सीमित migration fallback के रूप में रखा गया है:

```yaml
hooks:
  user_defines:
    ffmpeg_kit_extended_flutter:
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

**वर्तमान व्यवहार:** मूल पुस्तकालय और WebAssembly बंडल Dart Hooks के माध्यम से अपने-आप डाउनलोड और बंडल किए जाते हैं। Web बिल्ड दिए जाने पर `wasm` या `web` ओवरराइड का उपयोग करते हैं; अन्यथा हुक पिन किए गए रिलीज़ से मेल खाने वाला बंडल चुनता है। स्थानीय ओवरराइड फ़ाइलों को ट्रैक किया जाता है, इसलिए उनकी सामग्री बदलने पर `flutter clean` आवश्यक नहीं है।
प्लेटफ़ॉर्म ओवरराइड केवल स्थानीय पथ या HTTP(S) URL स्वीकार करते हैं। दूरस्थ URL पूरी URL को cache identity के रूप में उपयोग करते हैं और हर hook run में refresh होते हैं; बदली हुई bytes संबंधित extraction को invalid कर देती हैं। reproducible builds के लिए versioned या content-addressed URL पसंद करें।
**महत्वपूर्ण:** चुने गए बंडल का कॉन्फ़िगरेशन बदलने के बाद बिल्ड फिर से चलाएँ। स्थानीय ओवरराइड की सामग्री में बदलाव को निर्भरता के रूप में ट्रैक किया जाता है और इनके लिए `flutter clean` आवश्यक नहीं है।

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

**Dart Pub कार्यक्षेत्र:** package-config की रूट `pubspec` को प्राथमिकता दी जाती है। अन्यथा, केवल रूट के भीतर मौजूद पैकेज-ग्राफ़ रूट, जिनका इस पैकेज तक सामान्य निर्भरता पथ हो, कॉन्फ़िगरेशन प्रदान कर सकते हैं। अस्पष्ट उम्मीदवार अनुमान लगाने के बजाय विफल हो जाते हैं; यदि कोई लागू उम्मीदवार नहीं है, तो LGPL वाला छोटा `base` बंडल उपयोग किया जाता है। सापेक्ष स्थानीय ओवरराइड को परिभाषित करने वाली `pubspec` से हल किया जाता है और बिल्ड हुक द्वारा ट्रैक किया जाता है। Web के लिए, लीगेसी मैन्युअल स्टेजिंग का उपयोग करते समय उपभोग करने वाले ऐप पैकेज को कॉन्फ़िगर करें।

उदाहरण के लिए, कार्यक्षेत्र की रूट में:

~~~yaml
hooks:
  user_defines:
    ffmpeg_kit_extended_flutter:
      type: "video"
      gpl: true
~~~

### Web बिल्ड और परिनियोजन

स्थानीय Web Wasm विकास के लिए Flutter cross-origin isolation का उपयोग करें, ताकि pthread-सक्षम Wasm साझा मेमोरी को अपने वर्कर तक भेज सके:

~~~bash
flutter run -d web-server --cross-origin-isolation
~~~

Wasm के साथ Flutter Web बिल्ड करें:

~~~bash
flutter clean
flutter build web --wasm
~~~

WebAssembly बंडल में डिफ़ॉल्ट रूप से pthread समर्थन है। बिना pthread वाले बिल्ड के लिए कस्टम WebAssembly निर्भरता और ffmpeg-kit-builders से बंडल बिल्ड आवश्यक है।

बिल्ड हुक wasm32 बंडल डाउनलोड और सत्यापित करता है, फिर Wasm रनटाइम, लोडर, कॉलबैक ब्रिज और समर्थन मॉड्यूल को Web एसेट के रूप में स्टेज करता है। थ्रेड वाले Wasm बंडल के लिए ये HTTP प्रतिक्रिया हेडर आवश्यक हैं:

Custom Web/Wasm ZIP या directory में `ffmpegkit.mjs` और `ffmpegkit.wasm` दोनों वाला ठीक एक coherent runtime directory होना चाहिए। Split या ambiguous pairs अस्वीकार किए जाते हैं।

~~~http
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
~~~

WebAssembly बंडल का उपयोग करने से पहले पुष्टि करें कि window.crossOriginIsolated true है। प्राप्त किए गए Wasm, JavaScript, वर्कर और अन्य एसेट को चुनी गई COEP नीति का पालन करना होगा।

#### Flutter परीक्षण लक्ष्य की सीमा

परीक्षण चलाते समय Flutter होस्ट TargetPlatform.tester के लिए मूल-एसेट बिल्ड हुक का मूल्यांकन करता है। इसलिए `flutter test` इस पैकेज के हुक को गैर-होस्ट लक्ष्य के लिए एसेट चुनने के लिए बाध्य नहीं कर सकता। यह सभी लक्षित प्लेटफ़ॉर्म पर लागू होता है। लक्ष्य सत्यापन के लिए प्लेटफ़ॉर्म-विशिष्ट बिल्ड या रन कमांड का उपयोग करें।

### 2.1 प्लेटफ़ॉर्म-विशिष्ट कॉन्फ़िगरेशन

1. **iOS और iOS सिम्युलेटर**: build hook XCFramework architecture चुनता है। Prebuilt iOS package `arm64` को support करता है; simulator `x86_64` तभी support होगा जब custom XCFramework वास्तव में वह slice दे। Podfile `EXCLUDED_ARCHS` केवल downstream Xcode/CocoaPods targets को प्रभावित करता है; यह hook architecture नहीं चुनता और missing slice नहीं बनाता। Downstream targets को exclude करना हो तभी यह `post-install` जोड़ें:

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

#### GPL लाइसेंस

GPL पुस्तकालय सक्षम करने पर परिणामी FFmpeg बाइनरी GPL-लाइसेंस प्राप्त हो जाती है और आपके ऐप को GPL के अंतर्गत वितरित करना आवश्यक हो सकता है। जब तक आप लाइसेंस के प्रभावों को न समझें, LGPL बंडल का उपयोग करें।

#### कृत्रिम बुद्धिमत्ता

libopenvino और libtensorflow जैसे कृत्रिम बुद्धिमत्ता पुस्तकालय प्रकाशित बंडल में केवल डेस्कटॉप के लिए हैं। libtorch केवल Linux पर उपलब्ध है, libonnxruntime x86_64 macOS पर उपलब्ध नहीं है और GPU-आधारित कृत्रिम बुद्धिमत्ता पुस्तकालयों के लिए कस्टम परिनियोजन आवश्यक है। वर्तमान मैट्रिक्स Full बिल्ड में कृत्रिम बुद्धिमत्ता समर्थन दर्शाता है।

| विशेषता | Base | Audio | Video | Video+Hardware | Full |
| --- | --- | --- | --- | --- | --- |
| वीडियो | | | x | x | x |
| ऑडियो | | x | x | x | x |
| स्ट्रीमिंग | | x | x | x | x |
| हार्डवेयर | | | | x | x |
| कृत्रिम बुद्धिमत्ता* | | | | | x* |
| HTTPS | * | x | x | x | x |
| प्लेटफ़ॉर्म* | x | x | x | x | x |
| अन्य* | | | | | x |

1. कृत्रिम बुद्धिमत्ता की विशेषताएँ सभी प्लेटफ़ॉर्म पर समर्थित नहीं हैं। कुछ कृत्रिम बुद्धिमत्ता विशेषताओं को सक्षम करने के लिए आपको ffmpeg-kit-extended का अपना कस्टम बिल्ड तैनात करना होगा।
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
- **Web**: Wasm मेमोरी से जनरेशन-ट्रैक किए गए RGBA8888 फ़्रेम लेकर उन्हें Flutter इमेज के रूप में रेंडर करता है।
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

### बंडल आकार

तालिकाएँ `libffmpegkit` बाइनरी के असंपीड़ित आकार दशमलव MB में दिखाती हैं। प्रत्येक सीमा v0.11.2 रिलीज़ एसेट में LGPL के मापे गए न्यूनतम और GPL के मापे गए अधिकतम को दर्शाती है।

| बंडल प्रकार | Android (MB) | iOS (MB) | macOS (MB) | Linux (MB) | Windows (MB) |
|-------------|--------------|----------|------------|------------|--------------|
| debug       | 81.2-82.0    | 37.8-38.2 | 41.6-42.0  | 133.5-139.6 | 480.4-490.8  |
| base        | 73.4-93.0    | 36.0-48.6 | 39.8-54.3  | 31.6-44.2   | 41.3-55.2    |
| audio       | 102.6-179.1  | 74.6-126.0| 79.8-134.2 | 49.3-86.7   | 82.9-124.1   |
| video       | 233.0-353.0  | 160.7-227.4| 183.5-255.5| 164.6-232.1 | 215.0-281.1  |
| video_hw    | 239.4-359.9  | 163.8-230.7| 186.8-259.0| 171.3-239.2 | 219.0-285.4  |
| full        | 267.1-387.5  | 182.0-248.8| 223.3-295.4| 209.0-276.2 | 248.4-314.8  |

## 4. समर्थित बाहरी पुस्तकालय<a id="libraries"></a>

वर्तमान प्लेटफ़ॉर्म और बंडल की पूरी मैट्रिक्स [अंग्रेज़ी के मूल README](../README.md#libraries) में रखी जाती है।

## 5. लाइसेंस

यह परियोजना डिफ़ॉल्ट रूप से LGPL v3.0 के अंतर्गत लाइसेंस प्राप्त है। हालांकि, अंतर्निहित FFmpeg बिल्ड कॉन्फ़िगरेशन और उपयोग किए गए बाहरी पुस्तकालयों के आधार पर प्रभावी लाइसेंस GPL v3.0 हो सकता है। कृपया शामिल पुस्तकालयों के लाइसेंस देखें।

अपने प्रोजेक्ट में इस प्लगइन का उपयोग करने से पहले LGPL और GPL लाइसेंस के बीच का अंतर समझ लें।

अपने एप्लिकेशन में GPL-लाइसेंस प्राप्त घटकों का उपयोग करने पर आपके एप्लिकेशन को भी GPL के अंतर्गत लाइसेंस करना पड़ सकता है।
