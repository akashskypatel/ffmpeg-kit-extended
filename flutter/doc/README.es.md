# FFmpegKit Extended para Flutter

<div align="center">

<img src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/assets/banner.png" alt="Cabecera de FFmpegKit Extended" width="100%">

[![Stars](https://img.shields.io/github/stars/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/stargazers) [![Forks](https://img.shields.io/github/forks/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/fork) [![Issues](https://img.shields.io/github/issues/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/issues) [![Downloads](https://img.shields.io/pub/dm/ffmpeg_kit_extended_flutter?style=flat-square&logoColor=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub version](https://img.shields.io/pub/v/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub likes](https://img.shields.io/pub/likes/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub points](https://img.shields.io/pub/points/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![License](https://img.shields.io/github/license/akashskypatel/ffmpeg-kit-extended?color=144DB3)](LICENSE)

</div>

## Traducciones

[Inglés](../README.md) | **Español** | [简体中文](README.zh-CN.md) | [हिन्दी](README.hi.md) | [العربية](README.ar.md) | [Français](README.fr.md) | [Português (Brasil)](README.pt-BR.md) | [日本語](README.ja.md)


`ffmpeg-kit-extended` es un complemento completo de Flutter para ejecutar comandos de la `API 9.0.1` de `FFmpeg`, `FFprobe` y `FFplay` en `Android`, `iOS`, `macOS`, `Linux` y `Windows`. Usa `FFI` de Dart para interactuar directamente con las bibliotecas nativas de FFmpeg, ofreciendo alto rendimiento, flexibilidad y capacidades completas de reproducción de video.
Las compilaciones Web usan WebAssembly de Flutter con la misma API pública; las plataformas nativas usan Dart FFI.

Si te gusta el proyecto y lo usas en tu aplicación, deja una ⭐ en [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders) y [ffmpeg-kit-extended](https://github.com/akashskypatel/ffmpeg-kit-extended), y un 👍 en [pub.dev](https://pub.dev/packages/ffmpeg_kit_extended_flutter). ¡Ayuda mucho!

## 1. Funciones

- **Compatibilidad multiplataforma**: Funciona en `Android`, `iOS`, `macOS`, `Linux`, `Windows` y compilaciones Web habilitadas para WebAssembly.
  - **Android**: Reproducción de video completa con renderizado nativo en superficie.
    - **x86**: La arquitectura `x86` no es compatible por ser heredada.
  - **iOS y macOS**: Reproducción de alto rendimiento con `CVPixelBuffer` e integración con Metal.
    - **iOS**: Compatible con `dispositivos` físicos y `simuladores`. La arquitectura `x86_64` no es compatible por ser heredada.
  - **Linux**: Reproducción de video completa con integración `OpenGL`.
    - **arm64**: La arquitectura `arm64` aún no es compatible; estará disponible próximamente.
- **Web (Wasm)**: descarga el paquete wasm32 correspondiente durante el enlace de compilación y renderiza fotogramas RGBA de FFplay mediante la API de superficie unificada de Flutter. Usa `flutter build web --wasm`.
- **`FFmpeg`, `FFprobe` y `FFplay`**: Compatibilidad con la [`API 9.0.1` más reciente](https://www.ffmpeg.org/download.html) para manipulación de medios, recuperación de información y reproducción de audio/video.
- **Reproducción de video**: Reproducción multiplataforma completa con una API de superficie unificada.
- **Transmisión en tiempo real**: Flujos de posición y dimensiones de video para monitoreo en vivo.
- **Dart FFI**: Enlaces nativos directos para rendimiento óptimo.
- **Ejecución asíncrona**: Ejecuta tareas largas sin bloquear el hilo de UI.
- **Ejecución paralela**: Ejecuta varias tareas en paralelo.
- **Llamadas de retorno**: Ganchos detallados para registros, estadísticas y finalización de sesiones.
- **Gestión de sesiones**: Control completo del ciclo de vida de ejecución: iniciar, cancelar y listar.
- **Extensible**: Diseñado para permitir carga y configuración personalizadas de bibliotecas nativas.
- **API completa de introspección del paquete**: Obtén información detallada del paquete, incluida la versión, la fecha de compilación, los multiplexores, demultiplexores, codificadores, decodificadores, filtros, etc.
- **Implementar compilaciones personalizadas**: Puedes implementar compilaciones personalizadas de ffmpeg-kit-extended. Consulta: <https://github.com/akashskypatel/ffmpeg-kit-builders>

### Compatibilidad de plataformas

| Plataforma | Estado | Reproducción de video | Arquitectura | Requisitos mínimos |
| --- | --- | --- | --- | --- |
| Android (y Android TV) | ✅ Compatible | ✅ Nativa | armv7, arm64, x86_64 | API 26+ |
| iOS (y simulador) | ✅ Compatible | ✅ Texture | arm64 | iOS 13+ |
| macOS | ✅ Compatible | ✅ Texture | arm64, x86_64 | macOS 13+ |
| Linux | ✅ Compatible | ✅ Texture | x86_64 | glibc 2.28+ |
| Windows | ✅ Compatible | ✅ Texture | x86_64 | Windows 8+ |
| Web (Wasm) | ✅ Compatible | ✅ Fotogramas RGBA | wasm32 | Compilación Flutter Wasm |

Debes actualizar por tu cuenta los requisitos mínimos de tu aplicación para que coincidan con la tabla anterior.

## 🎬 Demostración

<div align="center">
<a href="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif">Haz clic aquí si la imagen no se carga</a>
<br>
<img width="378" height="672" src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif?raw=true" alt="Demostración" style="border-radius: 10px;" />
<br>

[_Demostración en video del complemento FFmpegKit Extended para Flutter que muestra reproducción de video en tiempo real, ejecución de comandos FFmpeg y la interfaz completa de la API de introspección._](https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif)

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

**Comportamiento actual:** Las bibliotecas nativas y el paquete WebAssembly se descargan y empaquetan automáticamente mediante Dart Hooks. Las compilaciones Web usan la anulación `wasm` o `web` cuando se proporciona; de lo contrario, el enlace selecciona el paquete correspondiente a la versión fijada. Los archivos de anulación locales se rastrean, por lo que no es necesario ejecutar `flutter clean` cuando cambia su contenido.
**Importante:** Vuelve a ejecutar la compilación después de cambiar la configuración del paquete seleccionado. Los cambios en el contenido de las anulaciones locales se rastrean como dependencias y no requieren `flutter clean`.

3. Importa el paquete en tu código Dart:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
```

4. Inicializa el complemento al arrancar la aplicación **antes** de llamar cualquier API:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FFmpegKitExtended.initialize();
  runApp(MyApp());
}
```

> **Importante**: Cualquier llamada a la API de FFmpeg, FFprobe o FFplay antes de que termine `initialize()` lanzará un `StateError`.

**Espacios de trabajo de Dart Pub:** La `pubspec` raíz de package-config tiene prioridad. De lo contrario, solo las raíces del grafo de paquetes dentro del árbol, con una ruta de dependencia normal hacia este paquete, pueden proporcionar configuración. Los candidatos ambiguos provocan un error en lugar de realizar una suposición; si no hay un candidato aplicable, se usa el paquete pequeño `base` con LGPL. Las anulaciones locales relativas se resuelven desde la `pubspec` que las define y el enlace de compilación las rastrea. Para Web, configura el paquete de la aplicación consumidora cuando uses preparación manual heredada.

Por ejemplo, en la raíz del espacio de trabajo:

~~~yaml
ffmpeg_kit_extended_config:
  type: "video"
  gpl: true
~~~

### Compilación y despliegue Web

Para el desarrollo local de Web con Wasm, usa el aislamiento de origen cruzado de Flutter para que Wasm habilitado con pthread pueda transferir memoria compartida a sus trabajadores:

~~~bash
flutter run -d web-server --cross-origin-isolation
~~~

Compila Flutter Web con Wasm:

~~~bash
flutter clean
flutter build web --wasm
~~~

El paquete WebAssembly incluye compatibilidad con pthread de forma predeterminada. Una compilación sin pthread requiere una dependencia WebAssembly personalizada y la compilación de un paquete desde ffmpeg-kit-builders.

El enlace de compilación descarga y verifica el paquete wasm32, y después prepara el entorno de ejecución Wasm, el cargador, el puente de llamadas de retorno y los módulos de soporte como recursos Web. Los paquetes Wasm con hilos requieren los siguientes encabezados de respuesta HTTP:

~~~http
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
~~~

Confirma que window.crossOriginIsolated sea true antes de usar el paquete WebAssembly. Los recursos Wasm, JavaScript, trabajadores y demás recursos descargados deben cumplir la política COEP seleccionada.

#### Limitación de los objetivos de prueba de Flutter

Flutter evalúa el enlace de compilación de recursos nativos para la plataforma anfitriona TargetPlatform.tester al ejecutar pruebas. Por lo tanto, `flutter test` no puede hacer que el enlace de esta biblioteca seleccione recursos para un objetivo que no sea el anfitrión. Esto se aplica a todas las plataformas objetivo. Usa el comando de compilación o ejecución específico de la plataforma para validar el objetivo.

### 2.1 Configuración específica de plataforma

1. **iOS y simulador de iOS**: Debes actualizar el Podfile de tu aplicación para agregar ganchos posteriores a la instalación (`post-install`) que excluyan la compilación para arquitecturas no compatibles. Agrega lo siguiente al Podfile:

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

### 2.2 Compilaciones preempaquetadas

- **base**: Compilación básica con las bibliotecas principales de FFmpeg. No contiene bibliotecas adicionales.
- **full**: Compilación completa con todas las bibliotecas FFmpeg compatibles con la plataforma. Consulta: <https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries>
- **audio**: Compilación con bibliotecas FFmpeg solo de audio.
- **video**: Compilación con bibliotecas FFmpeg solo de video.
- **video_hw**: Compilación con bibliotecas FFmpeg de video acelerado por hardware.

### 2.2 Matriz de características

#### Licencia GPL

Habilitar bibliotecas GPL hace que el binario FFmpeg resultante tenga licencia GPL y puede requerir que tu aplicación se distribuya bajo GPL. Usa un paquete LGPL a menos que comprendas las implicaciones de la licencia.

#### Inteligencia artificial

Las bibliotecas de inteligencia artificial, como libopenvino y libtensorflow, solo están disponibles para escritorio en los paquetes publicados. libtorch solo está disponible en Linux, libonnxruntime no está disponible en macOS x86_64 y las bibliotecas de IA para GPU requieren un despliegue personalizado. La matriz actual marca la compatibilidad con IA en las compilaciones Full.

| Característica | Base | Audio | Video | Video+Hardware | Full |
| -------------- | ---- | ----- | ----- | -------------- | ---- |
| Video          |      |       | x     | x              | x    |
| Audio          |      | x     | x     | x              | x    |
| Transmisión    |      | x     | x     | x              | x    |
| Hardware       |      |       |       | x              | x    |
| IA*            |      |       |       |                | x*   |
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
    print("Comando ejecutado correctamente");
  } else if (ReturnCode.isCancel(returnCode)) {
    print("Comando cancelado");
  } else {
    print("Comando fallido con estado ${session.getState()}");
    final failStackTrace = session.getFailStackTrace();
    print("Traza de pila: $failStackTrace");
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
      print("Duración: ${info.duration}");
      print("Formato: ${info.format}");
      for (var stream in info.streams) {
          print("Tipo de flujo: ${stream.type}, códec: ${stream.codec}");
      }
  }
});
```

### 3.3 Manejo de registros y estadísticas

Puedes registrar llamadas de retorno de registros y estadísticas para mejorar el monitoreo:

```dart
FFmpegKit.executeAsync(
  '-i input.mp4 output.mkv',
  onComplete: (session) { /* Llamada de retorno de finalización */ },
  onLog: (log) {
    print("Registro: ${log.message}");
  },
  onStatistics: (statistics) {
    print("Progreso: ${statistics.time} ms, tamaño: ${statistics.size}");
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

El complemento admite reproducción de video completa con una API de superficie unificada y multiplataforma.

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
- **Linux/Windows**: Usa texturas de búfer de píxeles con llamadas de retorno de fotogramas.
- **Web**: Copia fotogramas RGBA8888 desde la memoria Wasm y los renderiza como imágenes de Flutter.
- **Solo audio**: Se crea la superficie, pero no se muestra, evitando fallos.

#### Funciones avanzadas

```dart
// Obtener propiedades específicas de la sesión
final session = await FFplayKit.executeAsync('-i video.mp4');

// Dimensiones del video (disponibles cuando se decodifica el primer fotograma)
final width = session.getVideoWidth();
final height = session.getVideoHeight();

// Flujos en tiempo real
session.positionStream.listen((pos) => print('Posición: ${pos}s'));
session.videoSizeStream.listen((size) => print('Tamaño: ${size}'));

// Control de volumen
session.setVolume(0.8); // de 0.0 a 1.0
print('Volumen: ${session.getVolume()}');

// Estado de la sesión
print('Reproduciendo: ${session.isPlaying()}');
print('Pausado: ${session.isPaused()}');
```

### Tamaños de los paquetes

Las tablas muestran los tamaños de los binarios `libffmpegkit` sin comprimir en MB decimales. Cada rango representa el mínimo medido para LGPL y el máximo medido para GPL en los recursos de la versión v0.11.2.

| Tipo de paquete | Android (MB) | iOS (MB) | macOS (MB) | Linux (MB) | Windows (MB) |
|-------------|--------------|----------|------------|------------|--------------|
| debug       | 81.2-82.0    | 37.8-38.2 | 41.6-42.0  | 133.5-139.6 | 480.4-490.8  |
| base        | 73.4-93.0    | 36.0-48.6 | 39.8-54.3  | 31.6-44.2   | 41.3-55.2    |
| audio       | 102.6-179.1  | 74.6-126.0| 79.8-134.2 | 49.3-86.7   | 82.9-124.1   |
| video       | 233.0-353.0  | 160.7-227.4| 183.5-255.5| 164.6-232.1 | 215.0-281.1  |
| video_hw    | 239.4-359.9  | 163.8-230.7| 186.8-259.0| 171.3-239.2 | 219.0-285.4  |
| full        | 267.1-387.5  | 182.0-248.8| 223.3-295.4| 209.0-276.2 | 248.4-314.8  |

## 4. Bibliotecas externas compatibles<a id="libraries"></a>

La matriz completa y actual de plataformas y paquetes se mantiene en el [README inglés canónico](../README.md#libraries).

## 5. Licencia

Este proyecto se licencia bajo LGPL v3.0 por defecto. Sin embargo, dependiendo de la configuración de compilación de FFmpeg y las bibliotecas externas utilizadas, la licencia efectiva puede ser GPL v3.0. Revisa las licencias de las bibliotecas incluidas.

Comprende la diferencia entre las licencias LGPL y GPL antes de usar este complemento en tu proyecto.
