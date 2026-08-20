# FFmpegKit Extended para Flutter

<div align="center">

<img src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/assets/banner.png" alt="FFmpegKit Extended Banner" width="100%">

[![Stars](https://img.shields.io/github/stars/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/stargazers) [![Forks](https://img.shields.io/github/forks/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/fork) [![Issues](https://img.shields.io/github/issues/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/issues) [![Downloads](https://img.shields.io/pub/dm/ffmpeg_kit_extended_flutter?style=flat-square&logoColor=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub version](https://img.shields.io/pub/v/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub likes](https://img.shields.io/pub/likes/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub points](https://img.shields.io/pub/points/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![License](https://img.shields.io/github/license/akashskypatel/ffmpeg-kit-extended?color=144DB3)](LICENSE)

</div>

## Translations

[English](../README.md) | **Español** | [简体中文](README.zh-CN.md) | [हिन्दी](README.hi.md) | [العربية](README.ar.md) | [Français](README.fr.md) | [Português (Brasil)](README.pt-BR.md) | [日本語](README.ja.md)


`ffmpeg-kit-extended` es un plugin completo de Flutter para ejecutar comandos de la `API 9.0.1` de `FFmpeg`, `FFprobe` y `FFplay` en `Android`, `iOS`, `macOS`, `Linux` y `Windows`. Usa `FFI` de Dart para interactuar directamente con las bibliotecas nativas de FFmpeg, ofreciendo alto rendimiento, flexibilidad y capacidades completas de reproducción de video.

Si te gusta el proyecto y lo usas en tu aplicación, deja una ⭐ en [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders) y [ffmpeg-kit-extended](https://github.com/akashskypatel/ffmpeg-kit-extended), y un 👍 en [pub.dev](https://pub.dev/packages/ffmpeg_kit_extended_flutter). ¡Ayuda mucho!

## 1. Funciones

- **Compatibilidad multiplataforma**: Funciona en `Android`, `iOS`, `macOS`, `Linux` y `Windows`.
  - **Android**: Reproducción de video completa con renderizado nativo en superficie.
    - **x86**: La arquitectura `x86` no es compatible por ser heredada.
  - **iOS y macOS**: Reproducción de alto rendimiento con `CVPixelBuffer` e integración con Metal.
    - **iOS**: Compatible con `dispositivos` físicos y `simuladores`. La arquitectura `x86_64` no es compatible por ser heredada.
  - **Linux**: Reproducción de video completa con integración `OpenGL`.
    - **arm64**: La arquitectura `arm64` aún no es compatible; estará disponible próximamente.
- **`FFmpeg`, `FFprobe` y `FFplay`**: Compatibilidad con la [`API 9.0.1` más reciente](https://www.ffmpeg.org/download.html) para manipulación de medios, recuperación de información y reproducción de audio/video.
- **Reproducción de video**: Reproducción multiplataforma completa con una API de superficie unificada.
- **Streaming en tiempo real**: Flujos de posición y dimensiones de video para monitoreo en vivo.
- **Dart FFI**: Enlaces nativos directos para rendimiento óptimo.
- **Ejecución asíncrona**: Ejecuta tareas largas sin bloquear el hilo de UI.
- **Ejecución paralela**: Ejecuta varias tareas en paralelo.
- **Callbacks**: Hooks detallados para logs, estadísticas y finalización de sesiones.
- **Gestión de sesiones**: Control completo del ciclo de vida de ejecución: iniciar, cancelar y listar.
- **Extensible**: Diseñado para permitir carga y configuración personalizadas de bibliotecas nativas.
- **API completa de introspección del paquete**: Obtén información detallada del paquete, incluida versión, fecha de compilación, muxers, demuxers, codificadores, decodificadores, filtros, etc.
- **Implementar builds personalizados**: Puedes implementar builds personalizados de ffmpeg-kit-extended. Consulta: <https://github.com/akashskypatel/ffmpeg-kit-builders>

### Compatibilidad de plataformas

| Plataforma | Estado | Reproducción de video | Arquitectura | Requisitos mínimos |
| --- | --- | --- | --- | --- |
| Android (y Android TV) | ✅ Compatible | ✅ Nativa | armv7, arm64, x86_64 | API 26+ |
| iOS (y simulador) | ✅ Compatible | ✅ Texture | arm64 | iOS 13+ |
| macOS | ✅ Compatible | ✅ Texture | arm64, x86_64 | macOS 13+ |
| Linux | ✅ Compatible | ✅ Texture | x86_64 | glibc 2.28+ |
| Windows | ✅ Compatible | ✅ Texture | x86_64 | Windows 8+ |

Debes actualizar por tu cuenta los requisitos mínimos de tu aplicación para que coincidan con la tabla anterior.

## 🎬 Demo

<div align="center">
<a href="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif">Click here if the image doesn't load</a>
<br>
<img width="378" height="672" src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif?raw=true" alt="Demo" style="border-radius: 10px;" />
<br>

[_Video demonstration of FFmpegKit Extended Flutter plugin showing real-time video playback, FFmpeg command execution, and the comprehensive introspection API interface._](https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif)

</div>

## 2. Instalación

1. Instala el paquete:

```bash
flutter pub add ffmpeg_kit_extended_flutter
```

2. Agrega la sección `ffmpeg_kit_extended_config` a tu `pubspec.yaml`:

```yaml
ffmpeg_kit_extended_config:
  type: "base" # compilaciones preempaquetadas: debug, base, full, audio, video, video_hw
  gpl: true # actívalo para incluir bibliotecas GPL
  small: true # actívalo para usar compilaciones más pequeñas
  # == O ==
  # -------------------------------------------------------------
  # Puedes especificar una ruta remota o local a las bibliotecas libffmpegkit para cada plataforma
  # Esto te permite desplegar compilaciones personalizadas de libffmpegkit.
  # Consulta: https://github.com/akashskypatel/ffmpeg-kit-builders
  # -------------------------------------------------------------
  # windows: "path/to/ffmpeg-kit/libraries"
  # ios: "https://path/to/bundle.xcframework.zip"
```

**Nota**: Ahora las bibliotecas nativas se descargan y se empaquetan automáticamente durante el proceso de build mediante [Dart Hooks](https://dart.dev/tools/hooks). No se requiere ningún script de configuración manual.

**Importante**: Si cambias el bundle después de haber creado una build con otro bundle, debes ejecutar `flutter clean` y `flutter build` para volver a ejecutar el hook de build y descargar los binarios actualizados.

3. Importa el paquete en tu código Dart:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
```

4. Inicializa el plugin al arrancar la aplicación **antes** de llamar cualquier API:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FFmpegKitExtended.initialize();
  runApp(MyApp());
}
```

> **Importante**: Cualquier llamada a la API de FFmpeg, FFprobe o FFplay antes de que termine `initialize()` lanzará un `StateError`.

### 2.1 Configuración específica de plataforma

1. **iOS y simulador de iOS**: Debes actualizar el Podfile de tu app para agregar hooks post-install que excluyan la compilación para arquitecturas no compatibles. Agrega lo siguiente al Podfile:

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

### 2.2 Builds preempaquetados

- **base**: Build básico con las bibliotecas principales de FFmpeg. No contiene bibliotecas extra.
- **full**: Build completo con todas las bibliotecas FFmpeg compatibles con la plataforma. Consulta: <https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries>
- **audio**: Build con bibliotecas FFmpeg solo de audio.
- **video**: Build con bibliotecas FFmpeg solo de video.
- **video_hw**: Build con bibliotecas FFmpeg de video acelerado por hardware.

### 2.2 Matriz de características

| Característica | Base | Audio | Video | Video+Hardware | Full |
| -------------- | ---- | ----- | ----- | -------------- | ---- |
| Video          |      |       | x     | x              | x    |
| Audio          |      | x     | x     | x              | x    |
| Streaming      |      | x     | x     | x              | x    |
| Hardware       |      |       |       | x              | x    |
| IA*            |      |       |       |                |      |
| HTTPS          | *    | x     | x     | x              | x    |
| Plataforma*    | x    | x     | x     | x              | x    |
| Otras*         |      |       |       |                | x    |

1. Las características de IA no son compatibles con todas las plataformas. Debes desplegar tu propia compilación personalizada de ffmpeg-kit-extended para habilitar ciertas características de IA.
   - Consulta [Bibliotecas externas compatibles](https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries) para obtener más información.

2. Las características de plataforma son bibliotecas integradas de la plataforma compatibles con FFmpeg, como AVFoundation, VideoToolbox, etc. en plataformas Apple, o DirectX y MediaFoundation en Windows.

3. Las características HTTPS están habilitadas de forma predeterminada en plataformas que tienen compatibilidad HTTPS integrada, como Windows o Apple. En Linux y Android, OpenSSL está habilitado de forma predeterminada.

4. Otras características son características adicionales que no están cubiertas por las categorías anteriores. Consulta [Bibliotecas externas compatibles](https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries) para obtener más información.


## 3. Uso

### 3.1 Ejecución básica de comandos

Ejecuta un comando FFmpeg de forma asíncrona:

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

### 3.2 Obtener información de medios

Usa `FFprobeKit` para obtener metadatos detallados de un archivo multimedia:

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

### 3.3 Manejo de logs y estadísticas

Puedes registrar callbacks de logs y estadísticas para mejorar el monitoreo:

```dart
FFmpegKit.executeAsync(
  '-i input.mp4 output.mkv',
  onComplete: (session) { /* Callback de finalización */ },
  onLog: (log) {
    print("Log: ${log.message}");
  },
  onStatistics: (statistics) {
    print("Progress: ${statistics.time} ms, size: ${statistics.size}");
  },
);
```

### 3.4 Gestión de sesiones

Todas las ejecuciones devuelven un objeto `Session` que permite controlar la tarea:

```dart
// Cancelar una sesión específica
FFmpegKit.cancel(session);

// Cancelar todas las sesiones activas
FFmpegKitExtended.cancelAllSessions();

// Listar todas las sesiones
final sessions = FFmpegKitExtended.getSessions();
// O listar solo las sesiones de FFmpeg
final ffmpegSessions = FFmpegKit.getFFmpegSessions();
```

### 3.5 Reproducción de video con FFplay

El plugin admite reproducción de video completa con una API de superficie unificada y multiplataforma.

#### Reproducción básica de video

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
    // Crear la superficie antes de iniciar la reproducción
    _surface = await FFplaySurface.create();

    final session = await FFplayKit.executeAsync('-i "$filePath"');

    // Escuchar las dimensiones del video
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

    // Escuchar las actualizaciones de posición
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
        // Visualización de video (solo cuando hay fotogramas disponibles)
        if (_hasVideo && _surface != null)
          SizedBox(
            width: _videoWidth.toDouble(),
            height: _videoHeight.toDouble(),
            child: _surface!.toWidget(),
          ),

        // Controles de reproducción
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

#### Uso específico por plataforma

La clase `FFplaySurface` maneja automáticamente las diferencias entre plataformas:

- **Android**: Usa `SurfaceTexture` respaldado por `ANativeWindow` para renderizado nativo.
- **iOS/macOS**: Usa texturas `CVPixelBuffer` con optimización Metal.
- **Linux/Windows**: Usa texturas de búfer de píxeles con callbacks de frame.
- **Solo audio**: Se crea la superficie, pero no se muestra, evitando fallos.

#### Funciones avanzadas

```dart
// Obtener propiedades específicas de la sesión
final session = await FFplayKit.executeAsync('-i video.mp4');

// Dimensiones del video (disponibles cuando se decodifica el primer fotograma)
final width = session.getVideoWidth();
final height = session.getVideoHeight();

// Flujos en tiempo real
session.positionStream.listen((pos) => print('Position: ${pos}s'));
session.videoSizeStream.listen((size) => print('Size: ${size}'));

// Control de volumen
session.setVolume(0.8); // de 0.0 a 1.0
print('Volume: ${session.getVolume()}');

// Estado de la sesión
print('Playing: ${session.isPlaying()}');
print('Paused: ${session.isPaused()}');
```

## 4. Licencia

Este proyecto se licencia bajo LGPL v3.0 por defecto. Sin embargo, dependiendo de la configuración del build de FFmpeg y las bibliotecas externas utilizadas, la licencia efectiva puede ser GPL v3.0. Revisa las licencias de las bibliotecas incluidas.

Comprende la diferencia entre las licencias LGPL y GPL antes de usar este plugin en tu proyecto.
