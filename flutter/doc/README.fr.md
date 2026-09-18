# FFmpegKit Extended pour Flutter

<div align="center">

<img src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/assets/banner.png" alt="Bannière FFmpegKit Extended" width="100%">

[![Stars](https://img.shields.io/github/stars/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/stargazers) [![Forks](https://img.shields.io/github/forks/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/fork) [![Issues](https://img.shields.io/github/issues/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/issues) [![Downloads](https://img.shields.io/pub/dm/ffmpeg_kit_extended_flutter?style=flat-square&logoColor=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub version](https://img.shields.io/pub/v/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub likes](https://img.shields.io/pub/likes/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub points](https://img.shields.io/pub/points/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![License](https://img.shields.io/github/license/akashskypatel/ffmpeg-kit-extended?color=144DB3)](LICENSE)

</div>

## Traductions

[Anglais](../README.md) | [Español](README.es.md) | [简体中文](README.zh-CN.md) | [हिन्दी](README.hi.md) | [العربية](README.ar.md) | **Français** | [Português (Brasil)](README.pt-BR.md) | [日本語](README.ja.md)


`ffmpeg-kit-extended` est une extension Flutter complète permettant d’exécuter des commandes de l’`API 9.0.1` de `FFmpeg`, `FFprobe` et `FFplay` sur `Android`, `iOS`, `macOS`, `Linux` et `Windows`. Elle utilise `FFI` de Dart pour interagir directement avec les bibliothèques natives FFmpeg, avec de hautes performances, de la flexibilité et une prise en charge complète de la lecture vidéo.
Les compilations Web utilisent WebAssembly de Flutter avec la même API publique; les plateformes natives utilisent Dart FFI.

Si vous aimez le projet et l’utilisez dans votre application, ajoutez une ⭐ à [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders) et [ffmpeg-kit-extended](https://github.com/akashskypatel/ffmpeg-kit-extended), ainsi qu’un 👍 sur [pub.dev](https://pub.dev/packages/ffmpeg_kit_extended_flutter).

## 1. Fonctionnalités

- **Prise en charge multiplateforme** : fonctionne sur `Android`, `iOS`, `macOS`, `Linux`, `Windows` et les compilations Web compatibles WebAssembly.
  - **Android** : lecture vidéo complète avec rendu natif sur surface.
    - **x86** : l’architecture `x86` n’est pas prise en charge, car elle est héritée.
  - **iOS et macOS** : lecture vidéo haute performance avec `CVPixelBuffer` et intégration Metal.
    - **iOS** : prend en charge les `appareils` physiques et les `simulateurs`. L’architecture `x86_64` n’est pas prise en charge, car elle est héritée.
  - **Linux** : lecture vidéo complète avec intégration `OpenGL`.
    - **arm64** : l’architecture `arm64` n’est pas encore prise en charge; elle arrive bientôt.
- **Web (Wasm)** : télécharge le paquet wasm32 correspondant pendant le mécanisme de compilation et restitue les images RGBA de FFplay via l’API de surface Flutter unifiée. Utilisez `flutter build web --wasm`.
- **`FFmpeg`, `FFprobe` et `FFplay`** : prise en charge de la [dernière `API 9.0.1`](https://www.ffmpeg.org/download.html) pour la manipulation multimédia, l’extraction d’informations et la lecture audio/vidéo.
- **Lecture vidéo** : lecture vidéo multiplateforme complète avec une API de surface unifiée.
- **Diffusion en temps réel** : flux de position et de dimensions vidéo pour un suivi en direct.
- **Dart FFI** : liaisons natives directes pour des performances optimales.
- **Exécution asynchrone** : exécute des tâches longues sans bloquer le thread de l’interface utilisateur.
- **Exécution parallèle** : exécute plusieurs tâches en parallèle.
- **Appels de retour** : crochets détaillés pour les journaux, les statistiques et la fin de session.
- **Gestion des sessions** : contrôle complet du cycle de vie d’exécution: démarrer, annuler et lister.
- **Extensible** : conçu pour permettre le chargement et la configuration personnalisés des bibliothèques natives.
- **API complète d’introspection du paquet** : obtient des informations détaillées sur le paquet, notamment la version, la date de compilation, les multiplexeurs, démultiplexeurs, encodeurs, décodeurs, filtres, etc.
- **Déployer des compilations personnalisées** : vous pouvez déployer des compilations personnalisées de ffmpeg-kit-extended. Voir: <https://github.com/akashskypatel/ffmpeg-kit-builders>

### Prise en charge des plateformes

| Plateforme | État | Lecture vidéo | Architecture | Exigences minimales |
| --- | --- | --- | --- | --- |
| Android (et Android TV) | ✅ Pris en charge | ✅ Natif | armv7, arm64, x86_64 | API 26+ |
| iOS (et simulateur) | ✅ Pris en charge | ✅ Texture | arm64 | iOS 13+ |
| macOS | ✅ Pris en charge | ✅ Texture | arm64, x86_64 | macOS 13+ |
| Linux | ✅ Pris en charge | ✅ Texture | x86_64 | glibc 2.28+ |
| Windows | ✅ Pris en charge | ✅ Texture | x86_64 | Windows 8+ |
| Web (Wasm) | ✅ Pris en charge | ✅ Images RGBA | wasm32 | Compilation Flutter Wasm |

Vous devrez mettre à jour vous-même les exigences minimales de votre application pour correspondre au tableau ci-dessus.

## 🎬 Démo

<div align="center">
<a href="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif">Cliquez ici si l’image ne se charge pas</a>
<br>
<img width="378" height="672" src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif?raw=true" alt="Démonstration" style="border-radius: 10px;" />
<br>

[_Démonstration vidéo de l’extension FFmpegKit Extended pour Flutter montrant la lecture vidéo en temps réel, l’exécution de commandes FFmpeg et l’interface complète de l’API d’introspection._](https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif)

</div>

## 2. Installation

1. Installez le paquet :

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

**Comportement actuel :** les bibliothèques natives et le paquet WebAssembly sont téléchargés et regroupés automatiquement via Dart Hooks. Les compilations Web utilisent la substitution `wasm` ou `web` lorsqu’elle est fournie; sinon, le mécanisme sélectionne le paquet correspondant à la version figée. Les fichiers de substitution locaux sont suivis; il n’est donc pas nécessaire d’exécuter `flutter clean` lorsque leur contenu change.
**Important :** relancez la compilation après avoir modifié la configuration du paquet sélectionné. Les modifications du contenu des substitutions locales sont suivies comme des dépendances et ne nécessitent pas `flutter clean`.

3. Importez le paquet dans votre code Dart :

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
```

4. Initialisez l’extension au démarrage de l’application **avant** tout appel d’API :

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FFmpegKitExtended.initialize();
  runApp(MyApp());
}
```

> **Important** : tout appel à une API FFmpeg, FFprobe ou FFplay avant la fin de `initialize()` lèvera une `StateError`.

**Espaces de travail Dart Pub :** la `pubspec` racine de package-config est prioritaire. Sinon, seules les racines du graphe de paquets situées dans l’arborescence, avec un chemin de dépendance normal vers ce paquet, peuvent fournir une configuration. Les candidats ambigus provoquent un échec plutôt qu’une supposition; en l’absence de candidat applicable, le petit paquet `base` sous LGPL est utilisé. Les substitutions locales relatives sont résolues depuis la `pubspec` qui les définit et suivies par le mécanisme de compilation. Pour Web, configurez le paquet de l’application consommatrice lors de l’utilisation d’une préparation manuelle héritée.

Par exemple, à la racine de l’espace de travail :

~~~yaml
ffmpeg_kit_extended_config:
  type: "video"
  gpl: true
~~~

### Compilation et déploiement Web

Pour le développement local de Web avec Wasm, utilisez l’isolation d’origine de Flutter afin que Wasm avec pthread puisse transférer la mémoire partagée à ses travailleurs :

~~~bash
flutter run -d web-server --cross-origin-isolation
~~~

Compilez Flutter Web avec Wasm :

~~~bash
flutter clean
flutter build web --wasm
~~~

Le paquet WebAssembly prend en charge pthread par défaut. Une compilation sans pthread nécessite une dépendance WebAssembly personnalisée et la compilation d’un paquet depuis ffmpeg-kit-builders.

Le mécanisme de compilation télécharge et vérifie le paquet wasm32, puis prépare l’environnement d’exécution Wasm, le chargeur, le pont d’appels de retour et les modules de prise en charge comme ressources Web. Les paquets Wasm multithread nécessitent les en-têtes de réponse HTTP suivants :

~~~http
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
~~~

Vérifiez que window.crossOriginIsolated vaut true avant d’utiliser le paquet WebAssembly. Les ressources Wasm, JavaScript, travailleurs et autres ressources récupérées doivent respecter la politique COEP sélectionnée.

#### Limitation des cibles de test de Flutter

Lors de l’exécution des tests, Flutter évalue le mécanisme de compilation des ressources natives pour la plateforme hôte TargetPlatform.tester. Par conséquent, `flutter test` ne peut pas demander au mécanisme de cette bibliothèque de sélectionner des ressources pour une cible autre que l’hôte. Cela s’applique à toutes les plateformes cibles. Utilisez la commande de compilation ou d’exécution propre à la plateforme pour valider la cible.

### 2.1 Configuration propre aux plateformes

1. **iOS et simulateur iOS** : le Podfile de votre application doit être mis à jour pour ajouter des crochets post-installation (`post-install`) qui excluent les architectures non prises en charge. Ajoutez ceci au Podfile :

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

### 2.2 Compilations préemballées

- **base** : compilation de base avec les bibliothèques principales de FFmpeg, sans bibliothèques supplémentaires.
- **full** : compilation complète avec toutes les bibliothèques FFmpeg compatibles avec la plateforme. Voir : <https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries>
- **audio** : compilation avec bibliothèques FFmpeg audio uniquement.
- **video** : compilation avec bibliothèques FFmpeg vidéo uniquement.
- **video_hw** : compilation avec bibliothèques FFmpeg vidéo accélérées par matériel.

### 2.2 Matrice des fonctionnalités

#### Licence GPL

L’activation des bibliothèques GPL rend le binaire FFmpeg résultant soumis à la licence GPL et peut obliger à distribuer votre application sous GPL. Utilisez un paquet LGPL sauf si vous comprenez les implications de la licence.

#### Intelligence artificielle

Les bibliothèques d’intelligence artificielle telles que libopenvino et libtensorflow sont réservées aux ordinateurs de bureau dans les paquets publiés. libtorch est disponible uniquement sous Linux, libonnxruntime n’est pas disponible sur macOS x86_64 et les bibliothèques d’IA pour GPU nécessitent un déploiement personnalisé. La matrice actuelle indique la prise en charge de l’IA dans les compilations Full.

| Fonctionnalité | Base | Audio | Video | Video+Hardware | Full |
| -------------- | ---- | ----- | ----- | -------------- | ---- |
| Vidéo          |      |       | x     | x              | x    |
| Audio          |      | x     | x     | x              | x    |
| Diffusion      |      | x     | x     | x              | x    |
| Matériel       |      |       |       | x              | x    |
| IA*            |      |       |       |                | x*   |
| HTTPS          | *    | x     | x     | x              | x    |
| Plateforme*    | x    | x     | x     | x              | x    |
| Autres*        |      |       |       |                | x    |

1. Les fonctionnalités d’IA ne sont pas prises en charge sur toutes les plateformes. Vous devez déployer votre propre compilation personnalisée de ffmpeg-kit-extended pour activer certaines fonctionnalités d’IA.
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
    print("Commande réussie");
  } else if (ReturnCode.isCancel(returnCode)) {
    print("Commande annulée");
  } else {
    print("Commande échouée avec l’état ${session.getState()}");
    final failStackTrace = session.getFailStackTrace();
    print("Trace de la pile : $failStackTrace");
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
      print("Durée : ${info.duration}");
      print("Format : ${info.format}");
      for (var stream in info.streams) {
          print("Type de flux : ${stream.type}, codec : ${stream.codec}");
      }
  }
});
```

### 3.3 Gestion des journaux et statistiques

Vous pouvez enregistrer des appels de retour de journaux et de statistiques pour améliorer le suivi :

```dart
FFmpegKit.executeAsync(
  '-i input.mp4 output.mkv',
  onComplete: (session) { /* Appel de retour de fin d’exécution */ },
  onLog: (log) {
    print("Journal : ${log.message}");
  },
  onStatistics: (statistics) {
    print("Progression : ${statistics.time} ms, taille : ${statistics.size}");
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

L’extension prend en charge la lecture vidéo complète avec une API de surface unifiée et multiplateforme.

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
- **Linux/Windows** : utilise des textures de tampon de pixels avec des appels de retour d’images.
- **Web** : copie des images RGBA8888 depuis la mémoire Wasm et les restitue comme images Flutter.
- **Audio uniquement** : la surface est créée mais non affichée, ce qui évite les plantages.

#### Fonctionnalités avancées

```dart
// Obtenir les propriétés propres à la session
final session = await FFplayKit.executeAsync('-i video.mp4');

// Dimensions de la vidéo (disponibles lorsque la première image est décodée)
final width = session.getVideoWidth();
final height = session.getVideoHeight();

// Flux en temps réel
session.positionStream.listen((pos) => print('Position : ${pos}s'));
session.videoSizeStream.listen((size) => print('Taille : ${size}'));

// Contrôle du volume
session.setVolume(0.8); // de 0.0 à 1.0
print('Volume : ${session.getVolume()}');

// État de la session
print('En lecture : ${session.isPlaying()}');
print('En pause : ${session.isPaused()}');
```

### Tailles des paquets

Les tableaux indiquent les tailles non compressées des binaires `libffmpegkit` en Mo décimaux. Chaque plage correspond au minimum mesuré pour LGPL et au maximum mesuré pour GPL dans les ressources de la version v0.11.2.

| Type de paquet | Android (MB) | iOS (MB) | macOS (MB) | Linux (MB) | Windows (MB) |
|-------------|--------------|----------|------------|------------|--------------|
| debug       | 81.2-82.0    | 37.8-38.2 | 41.6-42.0  | 133.5-139.6 | 480.4-490.8  |
| base        | 73.4-93.0    | 36.0-48.6 | 39.8-54.3  | 31.6-44.2   | 41.3-55.2    |
| audio       | 102.6-179.1  | 74.6-126.0| 79.8-134.2 | 49.3-86.7   | 82.9-124.1   |
| video       | 233.0-353.0  | 160.7-227.4| 183.5-255.5| 164.6-232.1 | 215.0-281.1  |
| video_hw    | 239.4-359.9  | 163.8-230.7| 186.8-259.0| 171.3-239.2 | 219.0-285.4  |
| full        | 267.1-387.5  | 182.0-248.8| 223.3-295.4| 209.0-276.2 | 248.4-314.8  |

## 4. Bibliothèques externes prises en charge<a id="libraries"></a>

La matrice complète et actuelle des plateformes et des paquets est maintenue dans le [README anglais de référence](../README.md#libraries).

## 5. Licence

Ce projet est sous licence LGPL v3.0 par défaut. Cependant, selon la configuration de compilation de FFmpeg et les bibliothèques externes utilisées, la licence effective peut être GPL v3.0. Veuillez vérifier les licences des bibliothèques incluses.

Comprenez la différence entre les licences LGPL et GPL avant d’utiliser cette extension dans votre projet.
