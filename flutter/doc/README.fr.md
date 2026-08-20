# FFmpegKit Extended pour Flutter

<div align="center">

<img src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/assets/banner.png" alt="FFmpegKit Extended Banner" width="100%">

[![Stars](https://img.shields.io/github/stars/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/stargazers) [![Forks](https://img.shields.io/github/forks/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/fork) [![Issues](https://img.shields.io/github/issues/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/issues) [![Downloads](https://img.shields.io/pub/dm/ffmpeg_kit_extended_flutter?style=flat-square&logoColor=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub version](https://img.shields.io/pub/v/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub likes](https://img.shields.io/pub/likes/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub points](https://img.shields.io/pub/points/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![License](https://img.shields.io/github/license/akashskypatel/ffmpeg-kit-extended?color=144DB3)](LICENSE)

</div>

## Translations

[English](../README.md) | [Español](README.es.md) | [简体中文](README.zh-CN.md) | [हिन्दी](README.hi.md) | [العربية](README.ar.md) | **Français** | [Português (Brasil)](README.pt-BR.md) | [日本語](README.ja.md)


`ffmpeg-kit-extended` est un plugin Flutter complet permettant d’exécuter des commandes de l’`API 9.0.1` de `FFmpeg`, `FFprobe` et `FFplay` sur `Android`, `iOS`, `macOS`, `Linux` et `Windows`. Il utilise `FFI` de Dart pour interagir directement avec les bibliothèques natives FFmpeg, avec de hautes performances, de la flexibilité et une prise en charge complète de la lecture vidéo.

Si vous aimez le projet et l’utilisez dans votre application, ajoutez une ⭐ à [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders) et [ffmpeg-kit-extended](https://github.com/akashskypatel/ffmpeg-kit-extended), ainsi qu’un 👍 sur [pub.dev](https://pub.dev/packages/ffmpeg_kit_extended_flutter).

## 1. Fonctionnalités

- **Prise en charge multiplateforme** : fonctionne sur `Android`, `iOS`, `macOS`, `Linux` et `Windows`.
  - **Android** : lecture vidéo complète avec rendu natif sur surface.
    - **x86** : l’architecture `x86` n’est pas prise en charge, car elle est héritée.
  - **iOS et macOS** : lecture vidéo haute performance avec `CVPixelBuffer` et intégration Metal.
    - **iOS** : prend en charge les `appareils` physiques et les `simulateurs`. L’architecture `x86_64` n’est pas prise en charge, car elle est héritée.
  - **Linux** : lecture vidéo complète avec intégration `OpenGL`.
    - **arm64** : l’architecture `arm64` n’est pas encore prise en charge; elle arrive bientôt.
- **`FFmpeg`, `FFprobe` et `FFplay`** : prise en charge de la [dernière `API 9.0.1`](https://www.ffmpeg.org/download.html) pour la manipulation multimédia, l’extraction d’informations et la lecture audio/vidéo.
- **Lecture vidéo** : lecture vidéo multiplateforme complète avec une API de surface unifiée.
- **Streaming en temps réel** : flux de position et de dimensions vidéo pour un suivi en direct.
- **Dart FFI** : liaisons natives directes pour des performances optimales.
- **Exécution asynchrone** : exécute des tâches longues sans bloquer le thread UI.
- **Exécution parallèle** : exécute plusieurs tâches en parallèle.
- **Callbacks** : hooks détaillés pour les logs, les statistiques et la fin de session.
- **Gestion des sessions** : contrôle complet du cycle de vie d’exécution: démarrer, annuler et lister.
- **Extensible** : conçu pour permettre le chargement et la configuration personnalisés des bibliothèques natives.
- **API complète d’introspection du package** : obtient des informations détaillées sur le package, notamment version, date de build, muxers, demuxers, encodeurs, décodeurs, filtres, etc.
- **Déployer des builds personnalisés** : vous pouvez déployer des builds personnalisés de ffmpeg-kit-extended. Voir: <https://github.com/akashskypatel/ffmpeg-kit-builders>

### Prise en charge des plateformes

| Plateforme | État | Lecture vidéo | Architecture | Exigences minimales |
| --- | --- | --- | --- | --- |
| Android (et Android TV) | ✅ Pris en charge | ✅ Native | armv7, arm64, x86_64 | API 26+ |
| iOS (et simulateur) | ✅ Pris en charge | ✅ Texture | arm64 | iOS 13+ |
| macOS | ✅ Pris en charge | ✅ Texture | arm64, x86_64 | macOS 13+ |
| Linux | ✅ Pris en charge | ✅ Texture | x86_64 | glibc 2.28+ |
| Windows | ✅ Pris en charge | ✅ Texture | x86_64 | Windows 8+ |

Vous devrez mettre à jour vous-même les exigences minimales de votre application pour correspondre au tableau ci-dessus.

## 🎬 Démo

<div align="center">
<a href="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif">Click here if the image doesn't load</a>
<br>
<img width="378" height="672" src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif?raw=true" alt="Demo" style="border-radius: 10px;" />
<br>

[_Video demonstration of FFmpegKit Extended Flutter plugin showing real-time video playback, FFmpeg command execution, and the comprehensive introspection API interface._](https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif)

</div>

## 2. Installation

1. Installez le package:

```bash
flutter pub add ffmpeg_kit_extended_flutter
```

2. Ajoutez la section `ffmpeg_kit_extended_config` à votre `pubspec.yaml`:

```yaml
ffmpeg_kit_extended_config:
  type: "base" # versions préempaquetées : debug, base, full, audio, video, video_hw
  gpl: true # activez pour inclure les bibliothèques GPL
  small: true # activez pour utiliser des versions plus petites
  # == OU ==
  # -------------------------------------------------------------
  # Vous pouvez indiquer un chemin distant ou local vers les bibliothèques libffmpegkit pour chaque plateforme
  # Cela vous permet de déployer des versions personnalisées de libffmpegkit.
  # Voir : https://github.com/akashskypatel/ffmpeg-kit-builders
  # -------------------------------------------------------------
  # windows: "path/to/ffmpeg-kit/libraries"
  # ios: "https://path/to/bundle.xcframework.zip"
```

**Remarque** : les bibliothèques natives sont désormais téléchargées et incluses automatiquement pendant le processus de build à l’aide de [Dart Hooks](https://dart.dev/tools/hooks). Aucun script de configuration manuel n’est requis.

**Important** : si vous changez de bundle après avoir déjà créé une build avec un autre bundle, exécutez `flutter clean` puis `flutter build` pour relancer le hook de build et télécharger les binaires mis à jour.

3. Importez le package dans votre code Dart:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
```

4. Initialisez le plugin au démarrage de l’application **avant** tout appel d’API:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FFmpegKitExtended.initialize();
  runApp(MyApp());
}
```

> **Important** : tout appel à une API FFmpeg, FFprobe ou FFplay avant la fin de `initialize()` lèvera une `StateError`.

### 2.1 Configuration propre aux plateformes

1. **iOS et simulateur iOS** : le Podfile de votre application doit être mis à jour pour ajouter des hooks post-install qui excluent les architectures non prises en charge. Ajoutez ceci au Podfile:

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

### 2.2 Builds préembarqués

- **base** : build de base avec les bibliothèques principales de FFmpeg, sans bibliothèques supplémentaires.
- **full** : build complet avec toutes les bibliothèques FFmpeg compatibles avec la plateforme. Voir: <https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries>
- **audio** : build avec bibliothèques FFmpeg audio uniquement.
- **video** : build avec bibliothèques FFmpeg vidéo uniquement.
- **video_hw** : build avec bibliothèques FFmpeg vidéo accélérées par matériel.

## French (Français)

### 2.2 Matrice des fonctionnalités

| Fonctionnalité | Base | Audio | Video | Video+Hardware | Full |
| -------------- | ---- | ----- | ----- | -------------- | ---- |
| Vidéo          |      |       | x     | x              | x    |
| Audio          |      | x     | x     | x              | x    |
| Streaming      |      | x     | x     | x              | x    |
| Matériel       |      |       |       | x              | x    |
| IA*            |      |       |       |                |      |
| HTTPS          | *    | x     | x     | x              | x    |
| Plateforme*    | x    | x     | x     | x              | x    |
| Autres*        |      |       |       |                | x    |

1. Les fonctionnalités d’IA ne sont pas prises en charge sur toutes les plateformes. Vous devez déployer votre propre build personnalisé de ffmpeg-kit-extended pour activer certaines fonctionnalités d’IA.
   - Consultez les [bibliothèques externes prises en charge](https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries) pour plus d’informations.

2. Les fonctionnalités de plateforme sont des bibliothèques intégrées à la plateforme prises en charge par FFmpeg, comme AVFoundation, VideoToolbox, etc. sur les plateformes Apple, ou DirectX et MediaFoundation sur Windows.

3. Les fonctionnalités HTTPS sont activées par défaut sur les plateformes disposant d’une prise en charge HTTPS intégrée, comme Windows ou Apple. Sur Linux et Android, OpenSSL est activé par défaut.

4. Les autres fonctionnalités sont des fonctionnalités supplémentaires qui ne sont pas couvertes par les catégories ci-dessus. Consultez les [bibliothèques externes prises en charge](https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries) pour plus d’informations.

## 3. Utilisation

### 3.1 Exécution de commande de base

Exécutez une commande FFmpeg de manière asynchrone:

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

### 3.2 Récupération d’informations multimédias

Utilisez `FFprobeKit` pour obtenir les métadonnées détaillées d’un fichier multimédia:

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

### 3.3 Gestion des logs et statistiques

Vous pouvez enregistrer des callbacks de logs et de statistiques pour améliorer le suivi:

```dart
FFmpegKit.executeAsync(
  '-i input.mp4 output.mkv',
  onComplete: (session) { /* Callback de fin d’exécution */ },
  onLog: (log) {
    print("Log: ${log.message}");
  },
  onStatistics: (statistics) {
    print("Progress: ${statistics.time} ms, size: ${statistics.size}");
  },
);
```

### 3.4 Gestion des sessions

Toutes les exécutions renvoient un objet `Session` qui permet de contrôler la tâche:

```dart
// Annuler une session précise
FFmpegKit.cancel(session);

// Annuler toutes les sessions actives
FFmpegKitExtended.cancelAllSessions();

// Lister toutes les sessions
final sessions = FFmpegKitExtended.getSessions();
// Ou lister uniquement les sessions FFmpeg
final ffmpegSessions = FFmpegKit.getFFmpegSessions();
```

### 3.5 Lecture vidéo FFplay

Le plugin prend en charge la lecture vidéo complète avec une API de surface unifiée et multiplateforme.

#### Lecture vidéo de base

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
    // Créer la surface avant de démarrer la lecture
    _surface = await FFplaySurface.create();

    final session = await FFplayKit.executeAsync('-i "$filePath"');

    // Écouter les dimensions de la vidéo
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

    // Écouter les mises à jour de position
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
        // Affichage vidéo (uniquement lorsque des images vidéo sont disponibles)
        if (_hasVideo && _surface != null)
          SizedBox(
            width: _videoWidth.toDouble(),
            height: _videoHeight.toDouble(),
            child: _surface!.toWidget(),
          ),

        // Commandes de lecture
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

#### Utilisation propre aux plateformes

La classe `FFplaySurface` gère automatiquement les différences entre plateformes:

- **Android** : utilise `SurfaceTexture` appuyé par `ANativeWindow` pour le rendu natif.
- **iOS/macOS** : utilise des textures `CVPixelBuffer` avec optimisation Metal.
- **Linux/Windows** : utilise des textures de tampon de pixels avec callbacks de frame.
- **Audio uniquement** : la surface est créée mais non affichée, ce qui évite les plantages.

#### Fonctionnalités avancées

```dart
// Obtenir les propriétés propres à la session
final session = await FFplayKit.executeAsync('-i video.mp4');

// Dimensions de la vidéo (disponibles lorsque la première image est décodée)
final width = session.getVideoWidth();
final height = session.getVideoHeight();

// Flux en temps réel
session.positionStream.listen((pos) => print('Position: ${pos}s'));
session.videoSizeStream.listen((size) => print('Size: ${size}'));

// Contrôle du volume
session.setVolume(0.8); // de 0.0 à 1.0
print('Volume: ${session.getVolume()}');

// État de la session
print('Playing: ${session.isPlaying()}');
print('Paused: ${session.isPaused()}');
```

## 4. Licence

Ce projet est sous licence LGPL v3.0 par défaut. Cependant, selon la configuration du build FFmpeg et les bibliothèques externes utilisées, la licence effective peut être GPL v3.0. Veuillez vérifier les licences des bibliothèques incluses.

Comprenez la différence entre les licences LGPL et GPL avant d’utiliser ce plugin dans votre projet.
