# FFmpegKit Extended para Flutter

<div align="center">

<img src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/assets/banner.png" alt="Banner do FFmpegKit Extended" width="100%">

[![Stars](https://img.shields.io/github/stars/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/stargazers) [![Forks](https://img.shields.io/github/forks/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/fork) [![Issues](https://img.shields.io/github/issues/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/issues) [![Downloads](https://img.shields.io/pub/dm/ffmpeg_kit_extended_flutter?style=flat-square&logoColor=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub version](https://img.shields.io/pub/v/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub likes](https://img.shields.io/pub/likes/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub points](https://img.shields.io/pub/points/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![License](https://img.shields.io/github/license/akashskypatel/ffmpeg-kit-extended?color=144DB3)](LICENSE)

</div>

## Traduções

[Inglês](../README.md) | [Español](README.es.md) | [简体中文](README.zh-CN.md) | [हिन्दी](README.hi.md) | [العربية](README.ar.md) | [Français](README.fr.md) | **Português (Brasil)** | [日本語](README.ja.md)


`ffmpeg-kit-extended` é uma extensão Flutter completa para executar comandos da `API 9.0.1` do `FFmpeg`, `FFprobe` e `FFplay` no `Android`, `iOS`, `macOS`, `Linux` e `Windows`. Ela usa `FFI` do Dart para interagir diretamente com bibliotecas nativas do FFmpeg, oferecendo alto desempenho, flexibilidade e recursos completos de reprodução de vídeo.
As compilações Web usam o WebAssembly do Flutter com a mesma API pública; as plataformas nativas usam Dart FFI.

Se você gosta do projeto e o usa no seu app, deixe uma ⭐ em [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders) e [ffmpeg-kit-extended](https://github.com/akashskypatel/ffmpeg-kit-extended), e um 👍 no [pub.dev](https://pub.dev/packages/ffmpeg_kit_extended_flutter).

## 1. Recursos

- **Suporte multiplataforma**: funciona em `Android`, `iOS`, `macOS`, `Linux`, `Windows` e compilações Web com WebAssembly.
  - **Android**: reprodução de vídeo completa com renderização nativa em superfície.
    - **x86**: a arquitetura `x86` não é suportada por ser legada.
  - **iOS e macOS**: reprodução de vídeo de alto desempenho com `CVPixelBuffer` e integração Metal.
    - **iOS**: suporta `dispositivos` físicos e `simuladores`. A arquitetura `x86_64` não é suportada por ser legada.
  - **Linux**: reprodução de vídeo completa com integração `OpenGL`.
    - **arm64**: a arquitetura `arm64` ainda não é suportada; em breve.
- **Web (Wasm)**: baixa o pacote wasm32 correspondente durante o gancho de compilação e renderiza quadros RGBA do FFplay pela API de superfície unificada do Flutter. Use `flutter build web --wasm`.
- **`FFmpeg`, `FFprobe` e `FFplay`**: suporte à [`API 9.0.1` mais recente](https://www.ffmpeg.org/download.html) para manipulação de mídia, leitura de informações e reprodução de áudio/vídeo.
- **Reprodução de vídeo**: reprodução multiplataforma completa com API de superfície unificada.
- **Transmissão em tempo real**: fluxos de posição e dimensões do vídeo para monitoramento ao vivo.
- **Dart FFI**: vinculações nativas diretas para desempenho ideal.
- **Execução assíncrona**: execute tarefas longas sem bloquear a thread de UI.
- **Execução paralela**: execute várias tarefas em paralelo.
- **Retornos de chamada**: ganchos detalhados para registros, estatísticas e conclusão de sessão.
- **Gerenciamento de sessão**: controle completo do ciclo de vida de execução: iniciar, cancelar e listar.
- **Extensível**: projetado para permitir carregamento e configuração personalizados de bibliotecas nativas.
- **API completa de introspecção do pacote**: obtenha detalhes do pacote, incluindo versão, data de compilação, multiplexadores, demultiplexadores, codificadores, decodificadores, filtros etc.
- **Implantar compilações personalizadas**: você pode implantar compilações personalizadas do ffmpeg-kit-extended. Veja: <https://github.com/akashskypatel/ffmpeg-kit-builders>

### Suporte a plataformas

| Plataforma | Status | Reprodução de vídeo | Arquitetura | Requisitos mínimos |
| --- | --- | --- | --- | --- |
| Android (e Android TV) | ✅ Suportado | ✅ Nativa | armv7, arm64, x86_64 | API 26+ |
| iOS (e simulador) | ✅ Suportado | ✅ Texture | arm64 | iOS 13+ |
| macOS | ✅ Suportado | ✅ Texture | arm64, x86_64 | macOS 13+ |
| Linux | ✅ Suportado | ✅ Texture | x86_64 | glibc 2.28+ |
| Windows | ✅ Suportado | ✅ Texture | x86_64 | Windows 8+ |
| Web (Wasm) | ✅ Suportado | ✅ Quadros RGBA | wasm32 | Compilação Flutter Wasm |

Você precisará atualizar os requisitos mínimos do seu app para corresponder aos requisitos acima.

## 🎬 Demonstração

<div align="center">
<a href="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif">Clique aqui se a imagem não carregar</a>
<br>
<img width="378" height="672" src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif?raw=true" alt="Demonstração" style="border-radius: 10px;" />
<br>

[_Demonstração em vídeo da extensão FFmpegKit Extended para Flutter, mostrando reprodução de vídeo em tempo real, execução de comandos FFmpeg e a interface abrangente da API de introspecção._](https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif)

</div>

## 2. Instalação

Requisitos mínimos atuais: Flutter **3.47.0** e Dart **3.12.0**.

1. Instale o pacote:

```bash
flutter pub add ffmpeg_kit_extended_flutter
```

2. Adicione a seção oficial de Hooks `user_defines` ao `pubspec.yaml` raiz. `ffmpeg_kit_extended_config` permanece apenas como fallback de migração limitado:

```yaml
hooks:
  user_defines:
    ffmpeg_kit_extended_flutter:
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

**Comportamento atual:** as bibliotecas nativas e o pacote WebAssembly são baixados e agrupados automaticamente por meio do Dart Hooks. As compilações Web usam a substituição `wasm` ou `web` quando fornecida; caso contrário, o gancho seleciona o pacote correspondente à versão fixada. Os arquivos de substituição locais são rastreados, portanto não é necessário executar `flutter clean` quando o conteúdo deles muda.
As substituições de plataforma aceitam apenas caminhos locais ou URLs HTTP(S). URLs remotas usam a URL completa como identidade do cache e são atualizadas a cada execução do hook; bytes alterados invalidam a extração correspondente. Prefira URLs versionadas ou endereçadas por conteúdo.
**Importante:** execute a compilação novamente após alterar a configuração do pacote selecionado. As alterações no conteúdo das substituições locais são rastreadas como dependências e não exigem `flutter clean`.

3. Importe o pacote no seu código Dart:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
```

4. Inicialize a extensão na inicialização da aplicação **antes** de chamar qualquer API:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FFmpegKitExtended.initialize();
  runApp(MyApp());
}
```

> **Importante**: qualquer chamada à API do FFmpeg, FFprobe ou FFplay antes da conclusão de `initialize()` lançará um `StateError`.

**Espaços de trabalho do Dart Pub:** a `pubspec` raiz do package-config tem precedência. Caso contrário, somente as raízes do grafo de pacotes dentro da raiz, com um caminho de dependência normal para este pacote, podem fornecer configuração. Candidatos ambíguos falham em vez de adivinhar; se não houver um candidato aplicável, será usado o pequeno pacote `base` com LGPL. As substituições locais relativas são resolvidas a partir da `pubspec` que as define e rastreadas pelo gancho de compilação. Para Web, configure o pacote do aplicativo consumidor ao usar a preparação manual legada.

Por exemplo, na raiz do espaço de trabalho:

~~~yaml
hooks:
  user_defines:
    ffmpeg_kit_extended_flutter:
      type: "video"
      gpl: true
~~~

### Compilação e implantação Web

Para desenvolvimento local de Web com Wasm, use o isolamento de origem cruzada do Flutter para que o Wasm habilitado para pthread possa transferir memória compartilhada para seus trabalhadores:

~~~bash
flutter run -d web-server --cross-origin-isolation
~~~

Compile o Flutter Web com Wasm:

~~~bash
flutter clean
flutter build web --wasm
~~~

O pacote WebAssembly oferece suporte a pthread por padrão. Uma compilação sem pthread requer uma dependência WebAssembly personalizada e a compilação de um pacote a partir do ffmpeg-kit-builders.

O gancho de compilação baixa e verifica o pacote wasm32 e, em seguida, prepara o ambiente de execução Wasm, o carregador, a ponte de retornos de chamada e os módulos de suporte como recursos Web. Pacotes Wasm com threads exigem estes cabeçalhos de resposta HTTP:

ZIPs ou diretórios Web/Wasm personalizados devem conter exatamente um diretório de runtime coerente com `ffmpegkit.mjs` e `ffmpegkit.wasm`. Pares divididos ou ambíguos são rejeitados.

~~~http
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
~~~

Confirme que window.crossOriginIsolated é true antes de usar o pacote WebAssembly. Os recursos Wasm, JavaScript, trabalhadores e outros recursos obtidos devem atender à política COEP selecionada.

#### Limitação dos alvos de teste do Flutter

O Flutter avalia o gancho de compilação de recursos nativos para a plataforma hospedeira TargetPlatform.tester ao executar testes. Portanto, `flutter test` não pode fazer com que o gancho deste pacote selecione recursos para um alvo que não seja o hospedeiro. Isso se aplica a todas as plataformas-alvo. Use o comando de compilação ou execução específico da plataforma para validar o alvo.

### 2.1 Configuração específica de plataforma

1. **iOS e simulador iOS**: o hook seleciona as arquiteturas da XCFramework. O pacote iOS pré-compilado suporta `arm64`; `x86_64` de simulador só é suportado quando uma XCFramework personalizada realmente fornece essa slice. `EXCLUDED_ARCHS` do Podfile afeta apenas destinos posteriores do Xcode/CocoaPods; não escolhe a arquitetura do hook nem cria slices ausentes. Adicione o `post-install` abaixo apenas se o aplicativo precisar excluir esses destinos posteriores:

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

### 2.2 Compilações pré-empacotadas

- **base**: compilação básica com as bibliotecas principais do FFmpeg. Não contém bibliotecas extras.
- **full**: compilação completa com todas as bibliotecas FFmpeg compatíveis com a plataforma. Veja: <https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries>
- **audio**: compilação com bibliotecas FFmpeg apenas de áudio.
- **video**: compilação com bibliotecas FFmpeg apenas de vídeo.
- **video_hw**: compilação com bibliotecas FFmpeg de vídeo acelerado por hardware.

### 2.2 Matriz de recursos

#### Licença GPL

Ativar bibliotecas GPL faz com que o binário FFmpeg resultante seja licenciado sob GPL e pode exigir que seu aplicativo seja distribuído sob GPL. Use um pacote LGPL, a menos que compreenda as implicações da licença.

#### Inteligência artificial

Bibliotecas de inteligência artificial, como libopenvino e libtensorflow, estão disponíveis apenas para desktop nos pacotes publicados. libtorch está disponível apenas no Linux, libonnxruntime não está disponível no macOS x86_64 e bibliotecas de IA para GPU exigem uma implantação personalizada. A matriz atual indica suporte a IA nas compilações Full.

| Recurso      | Base | Audio | Video | Video+Hardware | Full |
| ------------ | ---- | ----- | ----- | -------------- | ---- |
| Vídeo        |      |       | x     | x              | x    |
| Áudio        |      | x     | x     | x              | x    |
| Transmissão  |      | x     | x     | x              | x    |
| Hardware     |      |       |       | x              | x    |
| IA*          |      |       |       |                | x*   |
| HTTPS        | *    | x     | x     | x              | x    |
| Plataforma*  | x    | x     | x     | x              | x    |
| Outros*      |      |       |       |                | x    |

1. Os recursos de IA não são compatíveis com todas as plataformas. Você deve implantar sua própria compilação personalizada do ffmpeg-kit-extended para habilitar determinados recursos de IA.
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
    print("Comando executado com sucesso");
  } else if (ReturnCode.isCancel(returnCode)) {
    print("Comando cancelado");
  } else {
    print("Comando falhou com o estado ${session.getState()}");
    final failStackTrace = session.getFailStackTrace();
    print("Rastreamento da pilha: $failStackTrace");
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
      print("Duração: ${info.duration}");
      print("Formato: ${info.format}");
      for (var stream in info.streams) {
          print("Tipo de fluxo: ${stream.type}, codec: ${stream.codec}");
      }
  }
});
```

### 3.3 Trabalhando com registros e estatísticas

Você pode registrar retornos de chamada de registros e estatísticas para melhorar o monitoramento:

```dart
FFmpegKit.executeAsync(
  '-i input.mp4 output.mkv',
  onComplete: (session) { /* Retorno de chamada de conclusão */ },
  onLog: (log) {
    print("Registro: ${log.message}");
  },
  onStatistics: (statistics) {
    print("Progresso: ${statistics.time} ms, tamanho: ${statistics.size}");
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

A extensão suporta reprodução de vídeo completa com uma API de superfície unificada e multiplataforma.

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
- **Linux/Windows**: usa texturas de buffer de pixels com retornos de chamada de quadros.
- **Web**: copia quadros RGBA8888 da memória Wasm e os renderiza como imagens Flutter.
- **Somente áudio**: a superfície é criada, mas não exibida, evitando falhas.

#### Recursos avançados

```dart
// Obter propriedades específicas da sessão
final session = await FFplayKit.executeAsync('-i video.mp4');

// Dimensões do vídeo (disponíveis quando o primeiro quadro é decodificado)
final width = session.getVideoWidth();
final height = session.getVideoHeight();

// Fluxos em tempo real
session.positionStream.listen((pos) => print('Posição: ${pos}s'));
session.videoSizeStream.listen((size) => print('Tamanho: ${size}'));

// Controle de volume
session.setVolume(0.8); // de 0.0 a 1.0
print('Volume: ${session.getVolume()}');

// Estado da sessão
print('Reproduzindo: ${session.isPlaying()}');
print('Pausado: ${session.isPaused()}');
```

### Tamanhos dos pacotes

As tabelas mostram os tamanhos descompactados dos binários `libffmpegkit` em MB decimais. Cada intervalo representa o mínimo medido para LGPL e o máximo medido para GPL nos artefatos da versão v0.11.2.

| Tipo de pacote | Android (MB) | iOS (MB) | macOS (MB) | Linux (MB) | Windows (MB) |
|-------------|--------------|----------|------------|------------|--------------|
| debug       | 81.2-82.0    | 37.8-38.2 | 41.6-42.0  | 133.5-139.6 | 480.4-490.8  |
| base        | 73.4-93.0    | 36.0-48.6 | 39.8-54.3  | 31.6-44.2   | 41.3-55.2    |
| audio       | 102.6-179.1  | 74.6-126.0| 79.8-134.2 | 49.3-86.7   | 82.9-124.1   |
| video       | 233.0-353.0  | 160.7-227.4| 183.5-255.5| 164.6-232.1 | 215.0-281.1  |
| video_hw    | 239.4-359.9  | 163.8-230.7| 186.8-259.0| 171.3-239.2 | 219.0-285.4  |
| full        | 267.1-387.5  | 182.0-248.8| 223.3-295.4| 209.0-276.2 | 248.4-314.8  |

## 4. Bibliotecas externas compatíveis<a id="libraries"></a>

A matriz completa e atual de plataformas e pacotes é mantida no [README canônico em inglês](../README.md#libraries).

## 5. Licença

Este projeto é licenciado sob LGPL v3.0 por padrão. No entanto, dependendo da configuração de compilação do FFmpeg e das bibliotecas externas usadas, a licença efetiva pode ser GPL v3.0. Revise as licenças das bibliotecas incluídas.

Entenda a diferença entre as licenças LGPL e GPL antes de usar esta extensão no seu projeto.
