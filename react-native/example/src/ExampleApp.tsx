import React, {useCallback, useEffect, useMemo, useRef, useState} from 'react';
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import Slider from '@react-native-community/slider';
import {
  errorCodes,
  isErrorWithCode,
  keepLocalCopy,
  pick,
  types,
} from '@react-native-documents/picker';
import {Dirs, FileSystem, Util} from 'react-native-file-access';
import {
  FFmpegKit,
  FFmpegKitConfig,
  FFmpegKitExtended,
  FFplayKit,
  FFprobeKit,
  LogLevel,
  ReturnCode,
  SessionState,
  type FFmpegSession,
  type FFplaySession,
  type Statistics,
} from 'ffmpeg-kit-extended';

type TabName = 'FFmpeg' | 'Stream' | 'FFprobe' | 'FFplay' | 'Transcode';

type RemoteRecordingJob = {
  label: string;
  outputPath: string;
  session: FFmpegSession;
  sessionId: number;
  completed: boolean;
  requestedCancel: boolean;
  startedWriting: boolean;
  returnCode?: number;
};

const TABS: TabName[] = ['FFmpeg', 'Stream', 'FFprobe', 'FFplay', 'Transcode'];
const EXAMPLE_DIR = `${Dirs.CacheDir}/ffmpeg_kit_extended_react_native_example`;
const TEST_VIDEO_PATH = `${EXAMPLE_DIR}/test_video.mp4`;
const TEST_AUDIO_PATH = `${EXAMPLE_DIR}/test_audio.wav`;
const REMOTE_LOG_PATH = `${EXAMPLE_DIR}/ffmpeg_kit_extended_react_native_example.log`;
const DEFAULT_REMOTE_URL = 'https://endpnt.com/hls/nasa4k/playlist.m3u8';
const MEDIA_INFO_FALLBACK =
  'https://raw.githubusercontent.com/tanersener/ffmpeg-kit/master/test-data/video.mp4';

const LOG_LEVELS = [
  LogLevel.Quiet,
  LogLevel.Error,
  LogLevel.Warning,
  LogLevel.Info,
  LogLevel.Verbose,
  LogLevel.Debug,
  LogLevel.Trace,
];

export function ExampleApp({platformName}: {platformName: 'Android' | 'iOS'}): React.JSX.Element {
  const [activeTab, setActiveTab] = useState<TabName>('FFmpeg');
  const [initialized, setInitialized] = useState(false);
  const [status, setStatus] = useState('Initializing...');
  const [logs, setLogs] = useState('');
  const [ffmpegCommand, setFfmpegCommand] = useState('-version');
  const [ffprobeCommand, setFfprobeCommand] = useState('-version');
  const [ffplayCommand, setFfplayCommand] = useState('-i test_video.mp4');
  const [remoteStreamUrl, setRemoteStreamUrl] = useState(DEFAULT_REMOTE_URL);
  const [currentLogLevel, setCurrentLogLevel] = useState(LogLevel.Info);
  const [selectedProbePath, setSelectedProbePath] = useState<string>();
  const [remoteJobs, setRemoteJobs] = useState<RemoteRecordingJob[]>([]);
  const [recordingCounter, setRecordingCounter] = useState(1);
  const [transcodeInputPath, setTranscodeInputPath] = useState<string>();
  const [transcodeOutputPath, setTranscodeOutputPath] = useState<string>();
  const [transcodeProgress, setTranscodeProgress] = useState(0);
  const [transcodeStatus, setTranscodeStatus] = useState('');
  const [isTranscoding, setIsTranscoding] = useState(false);
  const [playbackSession, setPlaybackSession] = useState<FFplaySession>();
  const [playbackPosition, setPlaybackPosition] = useState(0);
  const [playbackDuration, setPlaybackDuration] = useState(0);
  const [playbackState, setPlaybackState] = useState('Stopped');
  const [videoSize, setVideoSize] = useState({width: 0, height: 0});
  const [volume, setVolume] = useState(0.5);
  const logScrollRef = useRef<ScrollView>(null);

  const appendLog = useCallback((message: string) => {
    const line = message.endsWith('\n') ? message : `${message}\n`;
    setLogs(previous => `${previous}${line}`.slice(-250_000));
  }, []);

  const runGuarded = useCallback(
    async (label: string, operation: () => Promise<void> | void) => {
      try {
        await operation();
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        appendLog(`${label} failed: ${message}`);
      }
    },
    [appendLog],
  );

  useEffect(() => {
    void (async () => {
      try {
        if (!(await FileSystem.exists(EXAMPLE_DIR))) {
          await FileSystem.mkdir(EXAMPLE_DIR);
        }
        FFmpegKitExtended.initialize();
        setCurrentLogLevel(FFmpegKitConfig.getLogLevel());
        setInitialized(true);
        setStatus(`Ready on ${platformName}`);
        appendLog(`FFmpegKit Extended initialized on ${platformName}.`);
        appendLog(`Example working directory: ${EXAMPLE_DIR}`);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        setStatus('Initialization failed');
        appendLog(`Initialization failed: ${message}`);
      }
    })();
  }, [appendLog, platformName]);

  useEffect(() => {
    if (!playbackSession) {
      return;
    }
    const timer = setInterval(() => {
      try {
        const position = playbackSession.getPosition();
        const duration = playbackSession.getMediaDuration();
        const width = playbackSession.getVideoWidth();
        const height = playbackSession.getVideoHeight();
        setPlaybackPosition(position);
        setPlaybackDuration(duration);
        setVideoSize({width, height});
        setPlaybackState(
          playbackSession.isPlaying()
            ? 'Playing'
            : playbackSession.isPaused()
              ? 'Paused'
              : 'Stopped',
        );
      } catch {
        // The native session may have been removed between completion and this poll.
      }
    }, 250);
    return () => clearInterval(timer);
  }, [playbackSession]);

  useEffect(() => {
    logScrollRef.current?.scrollToEnd({animated: false});
  }, [logs]);

  const generateTestVideo = useCallback(async () => {
    appendLog(`--- Generating Test Video with Audio: ${TEST_VIDEO_PATH} ---`);
    const command =
      '-hide_banner -loglevel quiet -f lavfi -i testsrc=duration=5:size=512x512:rate=30 ' +
      '-f lavfi -i sine=frequency=1000:duration=5 -c:v mpeg2video -c:a aac -shortest -y ' +
      quote(TEST_VIDEO_PATH);
    const session = await FFmpegKit.executeAsync(command, {
      logCallback: log => appendLog(log.message),
    });
    appendLog(
      session.getReturnCode() === ReturnCode.Success
        ? 'Video with audio generated successfully.'
        : `Generation failed. Code: ${session.getReturnCode()}`,
    );
  }, [appendLog]);

  const generateTestAudio = useCallback(async () => {
    appendLog(`--- Generating Test Audio: ${TEST_AUDIO_PATH} ---`);
    const command =
      '-hide_banner -loglevel quiet -f lavfi -i sine=frequency=1000:duration=10 -y ' +
      quote(TEST_AUDIO_PATH);
    const session = await FFmpegKit.executeAsync(command, {
      logCallback: log => appendLog(log.message),
    });
    appendLog(
      session.getReturnCode() === ReturnCode.Success
        ? 'Audio generated successfully.'
        : `Generation failed. Code: ${session.getReturnCode()}`,
    );
  }, [appendLog]);

  const runFfmpegVersion = useCallback(async () => {
    appendLog('--- Running FFmpeg -version (Async) ---');
    const session = await FFmpegKit.executeAsync('-version', {
      logCallback: log => appendLog(log.message),
    });
    appendLog(`Return code: ${session.getReturnCode()}`);
  }, [appendLog]);

  const runFfmpegAwaited = useCallback(async () => {
    appendLog('--- Running FFmpeg -version (awaited execute()) ---');
    appendLog('React Native execute() is Promise-based and does not block the JS runtime.');
    const session = await FFmpegKit.execute('-version');
    appendLog(session.getOutput() || 'No output captured.');
    appendLog(`Return code: ${session.getReturnCode()}`);
  }, [appendLog]);

  const runCustomFfmpeg = useCallback(async () => {
    appendLog(`--- Running Custom FFmpeg: ${ffmpegCommand} ---`);
    const session = await FFmpegKit.executeAsync(ffmpegCommand, {
      logCallback: log => appendLog(log.message),
    });
    appendLog(`Return code: ${session.getReturnCode()}`);
  }, [appendLog, ffmpegCommand]);

  const runHelp = useCallback(async () => {
    appendLog('--- Running FFmpeg Help ---');
    await FFmpegKit.executeAsync('-h', {
      logCallback: log => appendLog(log.message),
    });
  }, [appendLog]);

  const logSystemInfo = useCallback((kind: string) => {
    try {
      switch (kind) {
        case 'basic':
          appendLog('--- System & Config Information ---');
          appendLog(`FFmpeg Version: ${FFmpegKitExtended.getFFmpegVersion()}`);
          appendLog(`FFmpegKit Version: ${FFmpegKitExtended.getVersion()}`);
          appendLog(`Build Date: ${FFmpegKitExtended.getBuildDate()}`);
          appendLog(`Package Name: ${FFmpegKitExtended.getPackageName()}`);
          appendLog(
            `Log Level: ${FFmpegKitConfig.logLevelToString(FFmpegKitConfig.getLogLevel())}`,
          );
          return;
        case 'architecture':
          appendLog(`FFmpeg Architecture: ${FFmpegKitExtended.getFFmpegArchitecture()}`);
          return;
        case 'bundle':
          appendLog(`Bundle Type: ${FFmpegKitExtended.getBundleType()}`);
          appendLog(`GPL: ${FFmpegKitExtended.isGpl() ? 'enabled' : 'disabled'}`);
          appendLog(`Non-free: ${FFmpegKitExtended.isNonfree() ? 'enabled' : 'disabled'}`);
          return;
        case 'libraries':
          appendLog(`External Libraries:\n${FFmpegKitExtended.getExternalLibraries() || 'None'}`);
          return;
        case 'codecs':
          appendLog(`Registered Codecs:\n${FFmpegKitExtended.getRegisteredCodecs() || 'None'}`);
          return;
        case 'encoders':
          appendLog(`Registered Encoders:\n${FFmpegKitExtended.getRegisteredEncoders() || 'None'}`);
          return;
        case 'decoders':
          appendLog(`Registered Decoders:\n${FFmpegKitExtended.getRegisteredDecoders() || 'None'}`);
          return;
        case 'muxers':
          appendLog(`Registered Muxers:\n${FFmpegKitExtended.getRegisteredMuxers() || 'None'}`);
          return;
        case 'demuxers':
          appendLog(`Registered Demuxers:\n${FFmpegKitExtended.getRegisteredDemuxers() || 'None'}`);
          return;
        case 'filters':
          appendLog(`Registered Filters:\n${FFmpegKitExtended.getRegisteredFilters() || 'None'}`);
          return;
        case 'protocols':
          appendLog(`Registered Protocols:\n${FFmpegKitExtended.getRegisteredProtocols() || 'None'}`);
          return;
        case 'bsfs':
          appendLog(
            `Registered Bitstream Filters:\n${FFmpegKitExtended.getRegisteredBitstreamFilters() || 'None'}`,
          );
          return;
        case 'build':
          appendLog(`Build Configuration:\n${FFmpegKitExtended.getBuildConfiguration() || 'None'}`);
          return;
      }
    } catch (error) {
      appendLog(`System information failed: ${String(error)}`);
    }
  }, [appendLog]);

  const setLogLevel = useCallback(
    (level: LogLevel) => {
      FFmpegKitConfig.setLogLevel(level);
      setCurrentLogLevel(level);
      appendLog(`Log level set to ${FFmpegKitConfig.logLevelToString(level)}.`);
    },
    [appendLog],
  );

  const runRemoteRecording = useCallback(async () => {
    const url = remoteStreamUrl.trim();
    if (!url) {
      appendLog('Remote stream URL is empty.');
      return;
    }

    await FileSystem.writeFile(REMOTE_LOG_PATH, '');
    const label = String(recordingCounter);
    const outputPath = `${EXAMPLE_DIR}/remote_recording_${recordingCounter}.ts`;
    setRecordingCounter(value => value + 1);
    if (await FileSystem.exists(outputPath)) {
      await FileSystem.unlink(outputPath);
    }

    appendLog('--- Running remote stream recording ---');
    appendLog(`Source: ${url}`);
    appendLog(`Output: ${outputPath}`);
    appendLog(`Scenario log: ${REMOTE_LOG_PATH}`);

    const command = [
      '-y',
      '-nostdin',
      '-hide_banner',
      '-loglevel error',
      '-reconnect 1',
      '-reconnect_at_eof 1',
      '-reconnect_streamed 1',
      '-reconnect_delay_max 5',
      '-rw_timeout 5000000',
      '-max_delay 5000000',
      '-i',
      quote(url),
      '-map 0',
      '-c copy',
      '-f mpegts',
      quote(outputPath),
    ].join(' ');

    const session = FFmpegKit.createSession(command);
    const job: RemoteRecordingJob = {
      label,
      outputPath,
      session,
      sessionId: session.getSessionId(),
      completed: false,
      requestedCancel: false,
      startedWriting: false,
    };
    setRemoteJobs(previous => [...previous, job]);

    const appendScenarioLog = async (message: string) => {
      appendLog(message);
      try {
        await FileSystem.appendFile(REMOTE_LOG_PATH, `${message}\n`);
      } catch {
        // UI logging remains useful if file logging fails.
      }
    };

    void session
      .executeAsync({
        logCallback: log => {
          void appendScenarioLog(`[${label}][log][session=${log.sessionId}] ${log.message}`);
        },
        statisticsCallback: statistics => {
          void appendScenarioLog(formatRemoteStatistics(label, statistics));
          if (statistics.size > 0) {
            setRemoteJobs(previous =>
              previous.map(item =>
                item.sessionId === session.getSessionId()
                  ? {...item, startedWriting: true}
                  : item,
              ),
            );
          }
        },
        completeCallback: completed => {
          setRemoteJobs(previous =>
            previous.map(item =>
              item.sessionId === completed.getSessionId()
                ? {
                    ...item,
                    completed: true,
                    returnCode: completed.getReturnCode(),
                  }
                : item,
            ),
          );
          void appendScenarioLog(
            `[${label}] complete. sessionId=${completed.getSessionId()} returnCode=${completed.getReturnCode()}`,
          );
        },
      })
      .catch(error => {
        setRemoteJobs(previous =>
          previous.map(item =>
            item.sessionId === session.getSessionId()
              ? {...item, completed: true}
              : item,
          ),
        );
        appendLog(`[${label}] session execution failed: ${String(error)}`);
      });
  }, [appendLog, recordingCounter, remoteStreamUrl]);

  const cancelRemoteJob = useCallback(
    (sessionId: number) => {
      const job = remoteJobs.find(item => item.sessionId === sessionId);
      if (!job) {
        return;
      }
      job.session.cancel();
      setRemoteJobs(previous =>
        previous.map(item =>
          item.sessionId === sessionId ? {...item, requestedCancel: true} : item,
        ),
      );
      appendLog(`Requested cancel for session ${sessionId}.`);
    },
    [appendLog, remoteJobs],
  );

  const refreshSessions = useCallback(() => {
    const sessions = FFmpegKitExtended.getSessions();
    const running = sessions.filter(session => session.getState() === SessionState.Running);
    appendLog(`Session history: ${sessions.length}; currently running: ${running.length}.`);
    setRemoteJobs(previous =>
      previous.map(job => ({
        ...job,
        completed:
          job.completed ||
          !running.some(session => session.getSessionId() === job.sessionId),
      })),
    );
  }, [appendLog]);

  const runFfprobeVersion = useCallback(async () => {
    appendLog('--- Running FFprobe -version (Async) ---');
    const session = await FFprobeKit.executeAsync('-version');
    appendLog(session.getOutput() || 'No output found in session object.');
    appendLog(`Return code: ${session.getReturnCode()}`);
  }, [appendLog]);

  const runFfprobeAwaited = useCallback(async () => {
    appendLog('--- Running FFprobe -version (awaited execute()) ---');
    const session = await FFprobeKit.execute('-version');
    appendLog(session.getOutput() || 'No output captured.');
    appendLog(`Return code: ${session.getReturnCode()}`);
  }, [appendLog]);

  const pickLocalFile = useCallback(async (videoOnly: boolean) => {
    try {
      const [picked] = await pick({
        mode: 'import',
        type: videoOnly ? [types.video] : undefined,
      });
      const [copy] = await keepLocalCopy({
        destination: 'cachesDirectory',
        files: [{uri: picked.uri, fileName: picked.name ?? 'picked-media'}],
      });
      if (copy.status !== 'success') {
        throw new Error(copy.copyError);
      }
      return localPathFromUri(copy.localUri);
    } catch (error) {
      if (isErrorWithCode(error) && error.code === errorCodes.OPERATION_CANCELED) {
        return undefined;
      }
      throw error;
    }
  }, []);

  const pickProbeFile = useCallback(async () => {
    const path = await pickLocalFile(false);
    if (path) {
      setSelectedProbePath(path);
      appendLog(`Selected for probe: ${path}`);
    }
  }, [appendLog, pickLocalFile]);

  const runMediaInformation = useCallback(async () => {
    const localTestExists = await FileSystem.exists(TEST_VIDEO_PATH);
    const probePath = selectedProbePath ?? (localTestExists ? TEST_VIDEO_PATH : MEDIA_INFO_FALLBACK);
    appendLog(`--- Getting Media Information for ${probePath} ---`);
    const session = await FFprobeKit.getMediaInformation(probePath);
    const info = session.getMediaInformation();
    if (!info) {
      appendLog('Failed to retrieve media information.');
      appendLog(session.getLogsAsString());
      return;
    }
    appendLog(`Format: ${info.format ?? 'unknown'}`);
    appendLog(`Duration: ${info.duration ?? 'unknown'}s`);
    appendLog(`Bitrate: ${info.bitrate ?? 'unknown'}`);
    appendLog(`Streams count: ${info.streams.length}`);
    appendLog(`Media Information: ${info.allPropertiesJson ?? '{}'}`);
    info.streams.forEach((stream, index) => {
      appendLog(
        ` Stream #${index}: ${stream.type ?? '?'} (${stream.codec ?? '?'}) - ${stream.width ?? 0}x${stream.height ?? 0}`,
      );
    });
  }, [appendLog, selectedProbePath]);

  const runCustomFfprobe = useCallback(async () => {
    appendLog(`--- Running Custom FFprobe: ${ffprobeCommand} ---`);
    const session = await FFprobeKit.executeAsync(ffprobeCommand);
    appendLog(session.getOutput() || 'No output captured.');
    appendLog(`Return code: ${session.getReturnCode()}`);
  }, [appendLog, ffprobeCommand]);

  const startPlayback = useCallback(
    async (command: string, label: string) => {
      if (playbackSession) {
        try {
          playbackSession.stop();
        } catch {
          // Ignore stale session cleanup.
        }
      }
      appendLog(`--- Starting FFplay: ${label} ---`);
      const session = FFplayKit.createSession(command);
      setPlaybackSession(session);
      setPlaybackPosition(0);
      setPlaybackDuration(0);
      setPlaybackState('Starting');
      setVideoSize({width: 0, height: 0});
      setVolume(session.getVolume());
      void session
        .executeAsync({
          logCallback: log => appendLog(log.message),
          completeCallback: completed => {
            appendLog(`FFplay finished. Return code: ${completed.getReturnCode()}`);
            setPlaybackState('Stopped');
            setPlaybackSession(current =>
              current?.getSessionId() === completed.getSessionId() ? undefined : current,
            );
          },
        })
        .catch(error => appendLog(`FFplay failed: ${String(error)}`));
    },
    [appendLog, playbackSession],
  );

  const playGenerated = useCallback(
    async (path: string) => {
      if (!(await FileSystem.exists(path))) {
        appendLog(`File not found: ${path}. Generate it first.`);
        return;
      }
      await startPlayback(
        `-hide_banner -loglevel quiet -autoexit -i ${quote(path)}`,
        path,
      );
    },
    [appendLog, startPlayback],
  );

  const runCustomFfplay = useCallback(async () => {
    await startPlayback(ffplayCommand, ffplayCommand);
  }, [ffplayCommand, startPlayback]);

  const seekPlayback = useCallback(
    (deltaSeconds: number) => {
      if (!playbackSession) {
        return;
      }
      const next = Math.max(0, playbackSession.getPosition() + deltaSeconds);
      playbackSession.seek(next);
      setPlaybackPosition(next);
    },
    [playbackSession],
  );

  const pickTranscodeFile = useCallback(async () => {
    const path = await pickLocalFile(true);
    if (!path) {
      return;
    }
    const fileName = Util.basename(path);
    const dot = fileName.lastIndexOf('.');
    const baseName = dot > 0 ? fileName.slice(0, dot) : fileName;
    const output = `${EXAMPLE_DIR}/${baseName}_transcoded.avi`;
    setTranscodeInputPath(path);
    setTranscodeOutputPath(output);
    appendLog(`Selected file: ${path}`);
  }, [appendLog, pickLocalFile]);

  const transcodeVideo = useCallback(async () => {
    if (isTranscoding) {
      appendLog('Transcode already in progress.');
      return;
    }

    let inputPath = transcodeInputPath;
    let outputPath = transcodeOutputPath;
    if (!inputPath || !(await FileSystem.exists(inputPath))) {
      inputPath = TEST_VIDEO_PATH;
      outputPath = `${EXAMPLE_DIR}/test_video.avi`;
      if (!(await FileSystem.exists(inputPath))) {
        appendLog('Source video not found. Generating test video first...');
        await generateTestVideo();
      }
    }
    if (!(await FileSystem.exists(inputPath))) {
      appendLog('Failed to create source video.');
      return;
    }

    setIsTranscoding(true);
    setTranscodeProgress(0);
    setTranscodeStatus('Starting transcode...');
    appendLog(`--- Transcoding: ${inputPath} -> ${outputPath} ---`);

    const mediaSession = await FFprobeKit.getMediaInformation(inputPath);
    const durationMs = Math.max(
      0,
      (Number.parseFloat(mediaSession.getMediaInformation()?.duration ?? '0') || 0) * 1000,
    );
    const session = FFmpegKit.createSession(
      `-hide_banner -i ${quote(inputPath)} -c:v mpeg4 -c:a aac -b:v 2M -y ${quote(outputPath ?? `${EXAMPLE_DIR}/output.avi`)}`,
    );
    try {
      await session.executeAsync({
        logCallback: log => appendLog(log.message),
        statisticsCallback: statistics => {
          const progress = durationMs > 0 ? Math.min(1, statistics.time / durationMs) : 0;
          setTranscodeProgress(progress);
          const message =
            `Time: ${(statistics.time / 1000).toFixed(1)}s | ` +
            `Elapsed: ${(statistics.timeElapsed / 1000).toFixed(1)}s | ` +
            `Speed: ${statistics.speed.toFixed(2)}x | ` +
            `Frame: ${statistics.videoFrameNumber} | ` +
            `Quality: ${statistics.videoQuality.toFixed(2)} | ` +
            `Progress: ${(progress * 100).toFixed(1)}% | ` +
            `Bitrate: ${statistics.bitrate} | FPS: ${statistics.videoFps} | ` +
            `Drop: ${statistics.dropFrames} | Dup: ${statistics.dupFrames}`;
          setTranscodeStatus(message);
        },
      });
      if (session.getReturnCode() === ReturnCode.Success) {
        setTranscodeProgress(1);
        setTranscodeStatus('Transcode complete.');
        appendLog(`Video transcoded successfully: ${outputPath}`);
      } else {
        setTranscodeStatus('Transcode failed.');
        appendLog(`Transcode failed. Code: ${session.getReturnCode()}`);
      }
    } finally {
      setIsTranscoding(false);
    }
  }, [
    appendLog,
    generateTestVideo,
    isTranscoding,
    transcodeInputPath,
    transcodeOutputPath,
  ]);

  const activeJobs = useMemo(
    () => remoteJobs.filter(job => !job.completed),
    [remoteJobs],
  );

  const content = (() => {
    switch (activeTab) {
      case 'FFmpeg':
        return (
          <View style={styles.section}>
            <ButtonGrid>
              <DemoButton label="Gen Video" onPress={() => void runGuarded('Generate video', generateTestVideo)} />
              <DemoButton label="Gen Audio" onPress={() => void runGuarded('Generate audio', generateTestAudio)} />
              <DemoButton label="Async Version" onPress={() => void runGuarded('FFmpeg version', runFfmpegVersion)} />
              <DemoButton label="Awaited Version" onPress={() => void runGuarded('FFmpeg execute', runFfmpegAwaited)} />
              <DemoButton label="Help" onPress={() => void runGuarded('FFmpeg help', runHelp)} />
            </ButtonGrid>
            <CommandSection
              label="Custom FFmpeg Command"
              value={ffmpegCommand}
              onChange={setFfmpegCommand}
              onRun={() => void runGuarded('Custom FFmpeg', runCustomFfmpeg)}
            />
            <Text style={styles.subheading}>System / Build Information</Text>
            <ButtonGrid>
              <DemoButton label="Basic Info" onPress={() => logSystemInfo('basic')} />
              <DemoButton label="Architecture" onPress={() => logSystemInfo('architecture')} />
              <DemoButton label="Bundle / License" onPress={() => logSystemInfo('bundle')} />
              <DemoButton label="Libraries" onPress={() => logSystemInfo('libraries')} />
              <DemoButton label="Codecs" onPress={() => logSystemInfo('codecs')} />
              <DemoButton label="Encoders" onPress={() => logSystemInfo('encoders')} />
              <DemoButton label="Decoders" onPress={() => logSystemInfo('decoders')} />
              <DemoButton label="Muxers" onPress={() => logSystemInfo('muxers')} />
              <DemoButton label="Demuxers" onPress={() => logSystemInfo('demuxers')} />
              <DemoButton label="Filters" onPress={() => logSystemInfo('filters')} />
              <DemoButton label="Protocols" onPress={() => logSystemInfo('protocols')} />
              <DemoButton label="Bitstream Filters" onPress={() => logSystemInfo('bsfs')} />
              <DemoButton label="Build Config" onPress={() => logSystemInfo('build')} />
            </ButtonGrid>
          </View>
        );
      case 'Stream':
        return (
          <View style={styles.section}>
            <Card>
              <Text style={styles.subheading}>Remote Stream Recording</Text>
              <Text style={styles.help}>Stream a remote URL and record it to an MPEG-TS file in the app cache.</Text>
              <TextInput
                style={styles.input}
                value={remoteStreamUrl}
                onChangeText={setRemoteStreamUrl}
                autoCapitalize="none"
                autoCorrect={false}
              />
              <DemoButton label="Record Stream" onPress={() => void runGuarded('Remote recording', runRemoteRecording)} />
            </Card>
            <Card>
              <View style={styles.rowBetween}>
                <Text style={styles.subheading}>Currently Running Sessions</Text>
                <DemoButton label="Refresh" onPress={refreshSessions} compact />
              </View>
              <Text style={styles.help}>Sessions: {activeJobs.length}</Text>
              {activeJobs.length === 0 ? (
                <Text style={styles.help}>No active streaming jobs.</Text>
              ) : (
                activeJobs.map(job => (
                  <View key={job.sessionId} style={styles.jobRow}>
                    <View style={styles.flexOne}>
                      <Text style={styles.bodyStrong}>
                        Session {job.sessionId} · {job.requestedCancel ? 'cancelling' : 'running'}
                      </Text>
                      <Text style={styles.help} numberOfLines={2}>{job.session.getCommand()}</Text>
                      <Text style={styles.help}>{job.startedWriting ? 'Output started' : 'Waiting for output'}</Text>
                    </View>
                    <DemoButton label="Cancel" onPress={() => cancelRemoteJob(job.sessionId)} compact />
                  </View>
                ))
              )}
            </Card>
          </View>
        );
      case 'FFprobe':
        return (
          <View style={styles.section}>
            {selectedProbePath ? <Text style={styles.help}>Selected: {Util.basename(selectedProbePath)}</Text> : null}
            <ButtonGrid>
              <DemoButton label="Pick File" onPress={() => void runGuarded('Pick probe file', pickProbeFile)} />
              <DemoButton label="Get Media Info" onPress={() => void runGuarded('Media information', runMediaInformation)} />
              <DemoButton label="Async Version" onPress={() => void runGuarded('FFprobe version', runFfprobeVersion)} />
              <DemoButton label="Awaited Version" onPress={() => void runGuarded('FFprobe execute', runFfprobeAwaited)} />
            </ButtonGrid>
            <CommandSection
              label="Custom FFprobe Command"
              value={ffprobeCommand}
              onChange={setFfprobeCommand}
              onRun={() => void runGuarded('Custom FFprobe', runCustomFfprobe)}
            />
          </View>
        );
      case 'FFplay':
        return (
          <View style={styles.section}>
            <View style={styles.videoPlaceholder}>
              <Text style={styles.videoPlaceholderTitle}>FFplay Native Video Surface</Text>
              <Text style={styles.videoPlaceholderText}>
                {videoSize.width > 0 && videoSize.height > 0
                  ? `Decoded video: ${videoSize.width}x${videoSize.height}`
                  : 'No video frame surface attached'}
              </Text>
              <Text style={styles.videoPlaceholderText}>
                The TurboModule exposes playback controls. Rendering will appear here after the Fabric FFplayView component is implemented.
              </Text>
            </View>
            <CommandSection
              label="Custom FFplay Command"
              value={ffplayCommand}
              onChange={setFfplayCommand}
              onRun={() => void runGuarded('Custom FFplay', runCustomFfplay)}
            />
            <Text style={styles.subheading}>1. Generate Media</Text>
            <ButtonGrid>
              <DemoButton label="Gen Video" onPress={() => void runGuarded('Generate video', generateTestVideo)} />
              <DemoButton label="Gen Audio" onPress={() => void runGuarded('Generate audio', generateTestAudio)} />
            </ButtonGrid>
            <Text style={styles.subheading}>2. Play Generated</Text>
            <ButtonGrid>
              <DemoButton label="Play Video" onPress={() => void runGuarded('Play video', () => playGenerated(TEST_VIDEO_PATH))} />
              <DemoButton label="Play Audio" onPress={() => void runGuarded('Play audio', () => playGenerated(TEST_AUDIO_PATH))} />
            </ButtonGrid>
            <Text style={styles.subheading}>Controls</Text>
            <ButtonGrid>
              <DemoButton label="Pause" onPress={() => playbackSession?.pause()} compact />
              <DemoButton label="Resume" onPress={() => playbackSession?.resume()} compact />
              <DemoButton label="Stop" onPress={() => playbackSession?.stop()} compact />
              <DemoButton label="-1s" onPress={() => seekPlayback(-1)} compact />
              <DemoButton label="+1s" onPress={() => seekPlayback(1)} compact />
            </ButtonGrid>
            <Text style={styles.bodyStrong}>State: {playbackState}</Text>
            <Text style={styles.help}>
              Position: {playbackPosition.toFixed(1)}s / {playbackDuration.toFixed(1)}s
            </Text>
            <Slider
              minimumValue={0}
              maximumValue={Math.max(1, playbackDuration)}
              value={Math.min(playbackPosition, Math.max(1, playbackDuration))}
              disabled={!playbackSession || playbackDuration <= 0}
              onSlidingComplete={value => {
                playbackSession?.seek(value);
                setPlaybackPosition(value);
              }}
            />
            <Text style={styles.bodyStrong}>Volume: {Math.round(volume * 100)}%</Text>
            <Slider
              minimumValue={0}
              maximumValue={1}
              step={0.05}
              value={volume}
              disabled={!playbackSession}
              onValueChange={value => {
                setVolume(value);
                playbackSession?.setVolume(value);
              }}
            />
          </View>
        );
      case 'Transcode':
        return (
          <View style={styles.section}>
            <Text style={styles.heading}>Video Transcode (MP4 → AVI)</Text>
            <Text style={styles.help}>Converts a video to MPEG-4 video + AAC audio in an AVI container and tracks FFmpeg statistics.</Text>
            <Card>
              <Text style={styles.subheading}>Input File</Text>
              <Text style={styles.help}>
                {transcodeInputPath
                  ? Util.basename(transcodeInputPath)
                  : 'No file selected; the generated test video will be used.'}
              </Text>
              {transcodeOutputPath ? <Text style={styles.help}>Output: {Util.basename(transcodeOutputPath)}</Text> : null}
              <ButtonGrid>
                <DemoButton
                  label="Pick Video File"
                  disabled={isTranscoding}
                  onPress={() => void runGuarded('Pick transcode file', pickTranscodeFile)}
                />
                {transcodeInputPath ? (
                  <DemoButton
                    label="Clear Selection"
                    disabled={isTranscoding}
                    onPress={() => {
                      setTranscodeInputPath(undefined);
                      setTranscodeOutputPath(undefined);
                    }}
                  />
                ) : null}
              </ButtonGrid>
            </Card>
            {(isTranscoding || transcodeProgress > 0) ? (
              <Card>
                <View style={styles.rowBetween}>
                  <Text style={styles.bodyStrong}>{isTranscoding ? 'Transcoding...' : 'Complete'}</Text>
                  <Text style={styles.bodyStrong}>{(transcodeProgress * 100).toFixed(1)}%</Text>
                </View>
                <View style={styles.progressTrack}>
                  <View style={[styles.progressValue, {width: `${Math.min(100, transcodeProgress * 100)}%`}]} />
                </View>
                <Text style={styles.monoSmall}>{transcodeStatus}</Text>
              </Card>
            ) : null}
            <DemoButton
              label={isTranscoding ? 'Transcoding...' : 'Transcode MP4 → AVI'}
              disabled={isTranscoding}
              onPress={() => void runGuarded('Transcode', transcodeVideo)}
            />
            <Card>
              <Text style={styles.subheading}>About Transcoding</Text>
              <Text style={styles.help}>• Default input: generated test_video.mp4</Text>
              <Text style={styles.help}>• Output: app cache as [input]_transcoded.avi</Text>
              <Text style={styles.help}>• Progress: derived from FFmpeg statistics time versus FFprobe duration</Text>
              <Text style={styles.help}>• Optional: import a video using the native document picker</Text>
            </Card>
          </View>
        );
    }
  })();

  return (
    <View style={styles.root}>
      <StatusBar barStyle="light-content" />
      <View style={styles.header}>
        <View style={styles.flexOne}>
          <Text style={styles.title}>FFmpeg Kit Extended</Text>
          <Text style={styles.status}>{status}</Text>
        </View>
        {!initialized ? <ActivityIndicator /> : null}
        <DemoButton label="Clear Logs" compact onPress={() => setLogs('')} />
      </View>

      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.logLevelRow}>
        <Text style={styles.logLevelLabel}>Log:</Text>
        {LOG_LEVELS.map(level => (
          <Pressable
            key={level}
            style={[styles.levelButton, currentLogLevel === level && styles.levelButtonActive]}
            onPress={() => setLogLevel(level)}>
            <Text style={styles.levelButtonText}>{FFmpegKitConfig.logLevelToString(level)}</Text>
          </Pressable>
        ))}
      </ScrollView>

      <View style={styles.tabs}>
        {TABS.map(tab => (
          <Pressable
            key={tab}
            style={[styles.tab, activeTab === tab && styles.tabActive]}
            onPress={() => setActiveTab(tab)}>
            <Text style={[styles.tabText, activeTab === tab && styles.tabTextActive]}>{tab}</Text>
          </Pressable>
        ))}
      </View>

      <ScrollView style={styles.content} contentContainerStyle={styles.contentContainer} keyboardShouldPersistTaps="handled">
        {content}
      </ScrollView>

      <View style={styles.logPane}>
        <Text style={styles.logTitle}>Logs</Text>
        <ScrollView ref={logScrollRef} style={styles.logScroll}>
          <Text selectable style={styles.logText}>{logs || 'No output yet.'}</Text>
        </ScrollView>
      </View>
    </View>
  );
}

function ButtonGrid({children}: {children: React.ReactNode}): React.JSX.Element {
  return <View style={styles.buttonGrid}>{children}</View>;
}

function Card({children}: {children: React.ReactNode}): React.JSX.Element {
  return <View style={styles.card}>{children}</View>;
}

function DemoButton({
  label,
  onPress,
  compact = false,
  disabled = false,
}: {
  label: string;
  onPress: () => void;
  compact?: boolean;
  disabled?: boolean;
}): React.JSX.Element {
  return (
    <Pressable
      disabled={disabled}
      onPress={onPress}
      style={({pressed}) => [
        styles.demoButton,
        compact && styles.demoButtonCompact,
        disabled && styles.demoButtonDisabled,
        pressed && !disabled && styles.demoButtonPressed,
      ]}>
      <Text style={styles.demoButtonText}>{label}</Text>
    </Pressable>
  );
}

function CommandSection({
  label,
  value,
  onChange,
  onRun,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  onRun: () => void;
}): React.JSX.Element {
  return (
    <View style={styles.commandSection}>
      <Text style={styles.subheading}>{label}</Text>
      <TextInput
        style={[styles.input, styles.commandInput]}
        value={value}
        onChangeText={onChange}
        autoCapitalize="none"
        autoCorrect={false}
      />
      <DemoButton label="Run" onPress={onRun} />
    </View>
  );
}

function quote(value: string): string {
  return `"${value.replace(/(["\\])/g, '\\$1')}"`;
}

function localPathFromUri(uri: string): string {
  const withoutScheme = uri.replace(/^file:\/\//, '');
  try {
    return decodeURIComponent(withoutScheme);
  } catch {
    return withoutScheme;
  }
}

function formatRemoteStatistics(label: string, statistics: Statistics): string {
  return (
    `[${label}][stats][session=${statistics.sessionId}] ` +
    `time=${statistics.time} size=${statistics.size} bitrate=${statistics.bitrate} ` +
    `speed=${statistics.speed} fps=${statistics.videoFps} frame=${statistics.videoFrameNumber}`
  );
}

const styles = StyleSheet.create({
  root: {flex: 1, backgroundColor: '#101114'},
  header: {
    minHeight: 62,
    paddingHorizontal: 14,
    paddingVertical: 10,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    backgroundColor: '#17191e',
  },
  flexOne: {flex: 1},
  title: {fontSize: 19, fontWeight: '700', color: '#f3f4f6'},
  status: {fontSize: 12, color: '#9ca3af', marginTop: 2},
  tabs: {flexDirection: 'row', backgroundColor: '#17191e', borderBottomWidth: 1, borderBottomColor: '#30333a'},
  tab: {flex: 1, paddingVertical: 11, alignItems: 'center'},
  tabActive: {borderBottomWidth: 2, borderBottomColor: '#60a5fa'},
  tabText: {fontSize: 12, color: '#9ca3af'},
  tabTextActive: {color: '#f3f4f6', fontWeight: '700'},
  content: {flex: 3},
  contentContainer: {paddingBottom: 24},
  section: {padding: 14, gap: 16},
  heading: {fontSize: 20, fontWeight: '700', color: '#f3f4f6'},
  subheading: {fontSize: 15, fontWeight: '700', color: '#e5e7eb', marginBottom: 8},
  bodyStrong: {fontSize: 13, fontWeight: '600', color: '#e5e7eb'},
  help: {fontSize: 12, color: '#9ca3af', lineHeight: 18},
  monoSmall: {fontSize: 11, color: '#a7f3d0', fontFamily: 'monospace', marginTop: 10},
  card: {backgroundColor: '#1b1e24', borderRadius: 10, padding: 14, gap: 8, borderWidth: 1, borderColor: '#30333a'},
  buttonGrid: {flexDirection: 'row', flexWrap: 'wrap', gap: 8, alignItems: 'center'},
  demoButton: {backgroundColor: '#2563eb', borderRadius: 7, paddingHorizontal: 13, paddingVertical: 9, alignSelf: 'flex-start'},
  demoButtonCompact: {paddingHorizontal: 10, paddingVertical: 7},
  demoButtonDisabled: {opacity: 0.45},
  demoButtonPressed: {opacity: 0.75},
  demoButtonText: {fontSize: 12, fontWeight: '700', color: '#ffffff'},
  commandSection: {gap: 8},
  input: {backgroundColor: '#111318', color: '#f3f4f6', borderWidth: 1, borderColor: '#3f434c', borderRadius: 7, paddingHorizontal: 10, paddingVertical: 9},
  commandInput: {fontFamily: 'monospace'},
  rowBetween: {flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 8},
  jobRow: {flexDirection: 'row', gap: 10, paddingVertical: 10, borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: '#3f434c'},
  videoPlaceholder: {minHeight: 180, backgroundColor: '#000000', borderRadius: 8, padding: 18, justifyContent: 'center', alignItems: 'center', gap: 8},
  videoPlaceholderTitle: {color: '#f3f4f6', fontWeight: '700'},
  videoPlaceholderText: {color: '#9ca3af', fontSize: 12, textAlign: 'center', lineHeight: 17},
  progressTrack: {height: 12, borderRadius: 6, backgroundColor: '#30333a', overflow: 'hidden'},
  progressValue: {height: '100%', backgroundColor: '#3b82f6'},
  logPane: {flex: 2, minHeight: 150, backgroundColor: '#000000', borderTopWidth: 1, borderTopColor: '#30333a'},
  logTitle: {fontSize: 11, color: '#9ca3af', paddingHorizontal: 10, paddingTop: 7},
  logScroll: {paddingHorizontal: 10, paddingVertical: 6},
  logText: {fontFamily: 'monospace', fontSize: 11, lineHeight: 15, color: '#86efac'},
  logLevelRow: {paddingHorizontal: 10, paddingVertical: 7, gap: 6, alignItems: 'center', backgroundColor: '#111318'},
  logLevelLabel: {color: '#9ca3af', fontSize: 11, marginRight: 2},
  levelButton: {borderRadius: 12, paddingHorizontal: 8, paddingVertical: 4, backgroundColor: '#2a2d34'},
  levelButtonActive: {backgroundColor: '#1d4ed8'},
  levelButtonText: {color: '#e5e7eb', fontSize: 10},
});
