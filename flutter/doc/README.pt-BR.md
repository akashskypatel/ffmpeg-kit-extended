# FFmpegKit Extended para Flutter

<div align="center">

<img src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/assets/banner.png" alt="FFmpegKit Extended Banner" width="100%">

[![Stars](https://img.shields.io/github/stars/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/stargazers) [![Forks](https://img.shields.io/github/forks/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/fork) [![Issues](https://img.shields.io/github/issues/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/issues) [![Downloads](https://img.shields.io/pub/dm/ffmpeg_kit_extended_flutter?style=flat-square&logoColor=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub version](https://img.shields.io/pub/v/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub likes](https://img.shields.io/pub/likes/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub points](https://img.shields.io/pub/points/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![License](https://img.shields.io/github/license/akashskypatel/ffmpeg-kit-extended?color=144DB3)](LICENSE)

</div>

## Translations

[English](../README.md) | [Español](README.es.md) | [简体中文](README.zh-CN.md) | [हिन्दी](README.hi.md) | [العربية](README.ar.md) | [Français](README.fr.md) | **Português (Brasil)** | [日本語](README.ja.md)


`ffmpeg-kit-extended` é um plugin Flutter completo para executar comandos da `API 9.0.1` do `FFmpeg`, `FFprobe` e `FFplay` no `Android`, `iOS`, `macOS`, `Linux` e `Windows`. Ele usa `FFI` do Dart para interagir diretamente com bibliotecas nativas do FFmpeg, oferecendo alto desempenho, flexibilidade e recursos completos de reprodução de vídeo.

Se você gosta do projeto e o usa no seu app, deixe uma ⭐ em [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders) e [ffmpeg-kit-extended](https://github.com/akashskypatel/ffmpeg-kit-extended), e um 👍 no [pub.dev](https://pub.dev/packages/ffmpeg_kit_extended_flutter).

## 1. Recursos

- **Suporte multiplataforma**: funciona em `Android`, `iOS`, `macOS`, `Linux` e `Windows`.
  - **Android**: reprodução de vídeo completa com renderização nativa em superfície.
    - **x86**: a arquitetura `x86` não é suportada por ser legada.
  - **iOS e macOS**: reprodução de vídeo de alto desempenho com `CVPixelBuffer` e integração Metal.
    - **iOS**: suporta `dispositivos` físicos e `simuladores`. A arquitetura `x86_64` não é suportada por ser legada.
  - **Linux**: reprodução de vídeo completa com integração `OpenGL`.
    - **arm64**: a arquitetura `arm64` ainda não é suportada; em breve.
- **`FFmpeg`, `FFprobe` e `FFplay`**: suporte à [`API 9.0.1` mais recente](https://www.ffmpeg.org/download.html#release_8.1) para manipulação de mídia, leitura de informações e reprodução de áudio/vídeo.
- **Reprodução de vídeo**: reprodução multiplataforma completa com API de superfície unificada.
- **Streaming em tempo real**: streams de posição e dimensões do vídeo para monitoramento ao vivo.
- **Dart FFI**: bindings nativos diretos para desempenho ideal.
- **Execução assíncrona**: execute tarefas longas sem bloquear a thread de UI.
- **Execução paralela**: execute várias tarefas em paralelo.
- **Callbacks**: hooks detalhados para logs, estatísticas e conclusão de sessão.
- **Gerenciamento de sessão**: controle completo do ciclo de vida de execução: iniciar, cancelar e listar.
- **Extensível**: projetado para permitir carregamento e configuração personalizados de bibliotecas nativas.
- **API completa de introspecção do pacote**: obtenha detalhes do pacote, incluindo versão, data de build, muxers, demuxers, codificadores, decodificadores, filtros etc.
- **Implantar builds personalizados**: você pode implantar builds personalizados do ffmpeg-kit-extended. Veja: <https://github.com/akashskypatel/ffmpeg-kit-builders>

### Suporte a plataformas

| Plataforma | Status | Reprodução de vídeo | Arquitetura | Requisitos mínimos |
| --- | --- | --- | --- | --- |
| Android (e Android TV) | ✅ Suportado | ✅ Nativa | armv7, arm64, x86_64 | API 26+ |
| iOS (e simulador) | ✅ Suportado | ✅ Texture | arm64 | iOS 13+ |
| macOS | ✅ Suportado | ✅ Texture | arm64, x86_64 | macOS 13+ |
| Linux | ✅ Suportado | ✅ Texture | x86_64 | glibc 2.28+ |
| Windows | ✅ Suportado | ✅ Texture | x86_64 | Windows 8+ |

Você precisará atualizar os requisitos mínimos do seu app para corresponder aos requisitos acima.

## 🎬 Demonstração

<div align="center">
<a href="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif">Click here if the image doesn't load</a>
<br>
<img width="378" height="672" src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif?raw=true" alt="Demo" style="border-radius: 10px;" />
<br>

[_Video demonstration of FFmpegKit Extended Flutter plugin showing real-time video playback, FFmpeg command execution, and the comprehensive introspection API interface._](https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif)

</div>

## 2. Instalação

1. Instale o pacote:

```bash
flutter pub add ffmpeg_kit_extended_flutter
```

2. Adicione a seção `ffmpeg_kit_extended_config` ao seu `pubspec.yaml`:

```yaml
ffmpeg_kit_extended_config:
  type: "base" # compilações pré-empacotadas: debug, base, full, audio, video, video_hw
  gpl: true # habilite para incluir bibliotecas GPL
  small: true # habilite para usar compilações menores
  # == OU ==
  # -------------------------------------------------------------
  # Você pode especificar um caminho remoto ou local para as bibliotecas libffmpegkit em cada plataforma
  # Isso permite implantar compilações personalizadas da libffmpegkit.
  # Veja: https://github.com/akashskypatel/ffmpeg-kit-builders
  # -------------------------------------------------------------
  # windows: "path/to/ffmpeg-kit/libraries"
  # ios: "https://path/to/bundle.xcframework.zip"
```

**Observação**: as bibliotecas nativas agora são baixadas e empacotadas automaticamente durante o processo de build usando [Dart Hooks](https://dart.dev/tools/hooks). Nenhum script de configuração manual é necessário.

**Importante**: se você trocar o bundle depois de já ter criado uma build com outro bundle, execute `flutter clean` e `flutter build` para executar novamente o hook de build e baixar os binários atualizados.

3. Importe o pacote no seu código Dart:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
```

4. Inicialize o plugin na inicialização da aplicação **antes** de chamar qualquer API:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FFmpegKitExtended.initialize();
  runApp(MyApp());
}
```

> **Importante**: qualquer chamada à API do FFmpeg, FFprobe ou FFplay antes da conclusão de `initialize()` lançará um `StateError`.

### 2.1 Configuração específica de plataforma

1. **iOS e simulador iOS**: o Podfile do seu app precisa ser atualizado para adicionar hooks post-install que excluem arquiteturas não suportadas. Adicione isto ao Podfile:

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

### 2.2 Builds pré-empacotados

- **base**: build básico com as bibliotecas principais do FFmpeg. Não contém bibliotecas extras.
- **full**: build completo com todas as bibliotecas FFmpeg compatíveis com a plataforma. Veja: <https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries>
- **audio**: build com bibliotecas FFmpeg apenas de áudio.
- **video**: build com bibliotecas FFmpeg apenas de vídeo.
- **video_hw**: build com bibliotecas FFmpeg de vídeo acelerado por hardware.

### 2.2 Matriz de recursos

| Recurso      | Base | Audio | Video | Video+Hardware | Full |
| ------------ | ---- | ----- | ----- | -------------- | ---- |
| Vídeo        |      |       | x     | x              | x    |
| Áudio        |      | x     | x     | x              | x    |
| Streaming    |      | x     | x     | x              | x    |
| Hardware     |      |       |       | x              | x    |
| IA*          |      |       |       |                |      |
| HTTPS        | *    | x     | x     | x              | x    |
| Plataforma*  | x    | x     | x     | x              | x    |
| Outros*      |      |       |       |                | x    |

1. Os recursos de IA não são compatíveis com todas as plataformas. Você deve implantar sua própria build personalizada do ffmpeg-kit-extended para habilitar determinados recursos de IA.
   - Consulte as [bibliotecas externas compatíveis](https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries) para obter mais informações.

2. Os recursos de plataforma são bibliotecas integradas da plataforma compatíveis com o FFmpeg, como AVFoundation, VideoToolbox etc. em plataformas Apple, ou DirectX e MediaFoundation no Windows.

3. Os recursos HTTPS são habilitados por padrão em plataformas que têm suporte HTTPS integrado, como Windows ou Apple. No Linux e Android, o OpenSSL é habilitado por padrão.

4. Outros recursos são recursos adicionais que não são cobertos pelas categorias acima. Consulte as [bibliotecas externas compatíveis](https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries) para obter mais informações.

## 3. Uso

### 3.1 Execução básica de comando

Execute um comando FFmpeg de forma assíncrona:

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

### 3.2 Recuperar informações de mídia

Use `FFprobeKit` para obter metadados detalhados sobre um arquivo de mídia:

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

### 3.3 Trabalhando com logs e estatísticas

Você pode registrar callbacks de logs e estatísticas para melhorar o monitoramento:

```dart
FFmpegKit.executeAsync(
  '-i input.mp4 output.mkv',
  onComplete: (session) { /* Callback de conclusão */ },
  onLog: (log) {
    print("Log: ${log.message}");
  },
  onStatistics: (statistics) {
    print("Progress: ${statistics.time} ms, size: ${statistics.size}");
  },
);
```

### 3.4 Gerenciamento de sessões

Todas as execuções retornam um objeto `Session` que pode ser usado para controlar a tarefa:

```dart
// Cancelar uma sessão específica
FFmpegKit.cancel(session);

// Cancelar todas as sessões ativas
FFmpegKitExtended.cancelAllSessions();

// Listar todas as sessões
final sessions = FFmpegKitExtended.getSessions();
// Ou listar apenas as sessões do FFmpeg
final ffmpegSessions = FFmpegKit.getFFmpegSessions();
```

### 3.5 Reprodução de vídeo com FFplay

O plugin suporta reprodução de vídeo completa com uma API de superfície unificada e multiplataforma.

#### Reprodução básica de vídeo

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
    // Criar a superfície antes de iniciar a reprodução
    _surface = await FFplaySurface.create();

    final session = await FFplayKit.executeAsync('-i "$filePath"');

    // Escutar as dimensões do vídeo
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

    // Escutar as atualizações de posição
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
        // Exibição de vídeo (somente quando houver quadros de vídeo disponíveis)
        if (_hasVideo && _surface != null)
          SizedBox(
            width: _videoWidth.toDouble(),
            height: _videoHeight.toDouble(),
            child: _surface!.toWidget(),
          ),

        // Controles de reprodução
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

A classe `FFplaySurface` lida automaticamente com diferenças entre plataformas:

- **Android**: usa `SurfaceTexture` com `ANativeWindow` para renderização nativa.
- **iOS/macOS**: usa texturas `CVPixelBuffer` com otimização Metal.
- **Linux/Windows**: usa texturas de buffer de pixels com callbacks de frame.
- **Somente áudio**: a superfície é criada, mas não exibida, evitando falhas.

#### Recursos avançados

```dart
// Obter propriedades específicas da sessão
final session = await FFplayKit.executeAsync('-i video.mp4');

// Dimensões do vídeo (disponíveis quando o primeiro quadro é decodificado)
final width = session.getVideoWidth();
final height = session.getVideoHeight();

// Streams em tempo real
session.positionStream.listen((pos) => print('Position: ${pos}s'));
session.videoSizeStream.listen((size) => print('Size: ${size}'));

// Controle de volume
session.setVolume(0.8); // de 0.0 a 1.0
print('Volume: ${session.getVolume()}');

// Estado da sessão
print('Playing: ${session.isPlaying()}');
print('Paused: ${session.isPaused()}');
```

## 4. Licença

Este projeto é licenciado sob LGPL v3.0 por padrão. No entanto, dependendo da configuração de build do FFmpeg e das bibliotecas externas usadas, a licença efetiva pode ser GPL v3.0. Revise as licenças das bibliotecas incluídas.

Entenda a diferença entre as licenças LGPL e GPL antes de usar este plugin no seu projeto.
