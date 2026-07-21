import React, {useCallback, useEffect, useMemo, useRef, useState} from 'react';
import {
  ActivityIndicator,
  Modal,
  PanResponder,
  Pressable,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  TextInput,
  useWindowDimensions,
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
  FFplayView,
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
const TAB_SYMBOLS: Record<TabName, string> = {
  FFmpeg: '▣',
  Stream: '≋',
  FFprobe: 'ⓘ',
  FFplay: '▶',
  Transcode: '⇄',
};
const EXAMPLE_DIR = `${Dirs.CacheDir}/ffmpeg_kit_extended_react_native_example`;
const TEST_VIDEO_PATH = `${EXAMPLE_DIR}/test_video.mp4`;
const TEST_AUDIO_PATH = `${EXAMPLE_DIR}/test_audio.wav`;
const REMOTE_LOG_PATH = `${EXAMPLE_DIR}/ffmpeg_kit_extended_react_native_example.log`;
const DEFAULT_REMOTE_URL = 'https://endpnt.com/hls/nasa4k/playlist.m3u8';
const MEDIA_INFO_FALLBACK =
  'https://raw.githubusercontent.com/tanersener/ffmpeg-kit/master/test-data/video.mp4';

const LOG_LEVELS = [
  LogLevel.Stderr,
  LogLevel.Quiet,
  LogLevel.Panic,
  LogLevel.Fatal,
  LogLevel.Error,
  LogLevel.Warning,
  LogLevel.Info,
  LogLevel.Verbose,
  LogLevel.Debug,
  LogLevel.Trace,
];

const SYSTEM_INFO_ITEMS = [
  ['Basic System Info', 'basic', 'ⓘ'],
  ['FFmpeg Version', 'ffmpeg-version', '✓'],
  ['FFmpeg Architecture', 'architecture', '▦'],
  ['FFmpegKit Version', 'ffmpegkit-version', 'ⓘ'],
  ['Package Name', 'package-name', '▣'],
  ['External Libraries', 'libraries', '▤'],
  ['Bundle Type', 'bundle', '◆'],
  ['GPL Status', 'gpl', '⚖'],
  ['Non-Free Status', 'nonfree', '▰'],
  ['Registered Codecs', 'codecs', '▣'],
  ['Registered Encoders', 'encoders', '↑'],
  ['Registered Decoders', 'decoders', '↓'],
  ['Registered Muxers', 'muxers', '↗'],
  ['Registered Demuxers', 'demuxers', '↘'],
  ['Registered Filters', 'filters', '▼'],
  ['Registered Protocols', 'protocols', '∞'],
  ['Registered Bitstream Filters', 'bsfs', '☷'],
  ['Build Configuration', 'build', '⌕'],
  ['Build Date', 'build-date', '□'],
] as const;

export function ExampleApp({platformName}: {platformName: 'Android' | 'iOS'}): React.JSX.Element {
  const {width, height} = useWindowDimensions();
  const isMobile = width < 600;
  const [activeTab, setActiveTab] = useState<TabName>('FFmpeg');
  const [initialized, setInitialized] = useState(false);
  const [status, setStatus] = useState('Initializing...');
  const [logLevelMenuVisible, setLogLevelMenuVisible] = useState(false);
  const [systemInfoMenuVisible, setSystemInfoMenuVisible] = useState(false);
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
  const [logPaneHeight, setLogPaneHeight] = useState(() =>
    Math.max(96, Math.min(180, height * 0.18)),
  );
  const videoSurfaceReadyRef = useRef(false);
  const logResizeStartRef = useRef(logPaneHeight);
  const logScrollRef = useRef<ScrollView>(null);

  const maxLogPaneHeight = Math.max(160, height * 0.65);
  const videoAspectRatio =
    videoSize.width > 0 && videoSize.height > 0
      ? videoSize.width / videoSize.height
      : 16 / 9;
  const videoMaxDimension = Math.max(1, Math.min(width, height) - 32);
  const videoDisplaySize =
    videoAspectRatio >= 1
      ? {
          width: videoMaxDimension,
          height: videoMaxDimension / videoAspectRatio,
        }
      : {
          width: videoMaxDimension * videoAspectRatio,
          height: videoMaxDimension,
        };

  const logResizePanResponder = useMemo(
    () =>
      PanResponder.create({
        onStartShouldSetPanResponder: () => true,
        onMoveShouldSetPanResponder: (_, gestureState) =>
          Math.abs(gestureState.dy) > 2,
        onPanResponderGrant: () => {
          logResizeStartRef.current = logPaneHeight;
        },
        onPanResponderMove: (_, gestureState) => {
          const nextHeight = logResizeStartRef.current - gestureState.dy;
          setLogPaneHeight(Math.max(96, Math.min(maxLogPaneHeight, nextHeight)));
        },
      }),
    [logPaneHeight, maxLogPaneHeight],
  );

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
        if (position >= 0) {
          setPlaybackPosition(position);
        }
        if (duration >= 0) {
          setPlaybackDuration(duration);
        }
        if (width > 0 && height > 0) {
          setVideoSize({width, height});
        }
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
    setLogPaneHeight(current =>
      Math.max(96, Math.min(maxLogPaneHeight, current)),
    );
  }, [maxLogPaneHeight]);

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
        case 'ffmpeg-version':
          appendLog(`FFmpeg Version: ${FFmpegKitExtended.getFFmpegVersion()}`);
          return;
        case 'architecture':
          appendLog(`FFmpeg Architecture: ${FFmpegKitExtended.getFFmpegArchitecture()}`);
          return;
        case 'ffmpegkit-version':
          appendLog(`FFmpegKit Version: ${FFmpegKitExtended.getVersion()}`);
          return;
        case 'package-name':
          appendLog(`Package Name: ${FFmpegKitExtended.getPackageName()}`);
          return;
        case 'bundle':
          appendLog(`Bundle Type: ${FFmpegKitExtended.getBundleType()}`);
          return;
        case 'gpl':
          appendLog(`GPL: ${FFmpegKitExtended.isGpl() ? 'enabled' : 'disabled'}`);
          return;
        case 'nonfree':
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
        case 'build-date':
          appendLog(`Build Date: ${FFmpegKitExtended.getBuildDate()}`);
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

  const waitForVideoSurface = useCallback(async () => {
    if (platformName !== 'Android' && platformName !== 'iOS') {
      return;
    }

    const timeoutAt = Date.now() + 2000;
    while (!videoSurfaceReadyRef.current && Date.now() < timeoutAt) {
      await new Promise(resolve => setTimeout(resolve, 25));
    }

    if (!videoSurfaceReadyRef.current) {
      throw new Error('FFplay video surface is not ready. Open the FFplay tab and try again.');
    }

    // Let the native view finish binding its platform video target/frame callback
    // before FFplay begins decoding the first frame.
    await new Promise(resolve => setTimeout(resolve, 50));
  }, [platformName]);

  const startPlayback = useCallback(
    async (command: string, label: string, requiresVideoSurface = true) => {
      if (playbackSession) {
        try {
          playbackSession.stop();
        } catch {
          // Ignore stale session cleanup.
        }
      }
      if (requiresVideoSurface) {
        await waitForVideoSurface();
      }
      appendLog(`--- Starting FFplay: ${label} ---`);
      appendLog(`Command: ${command}`);
      const session = FFplayKit.createSession(command);
      setPlaybackSession(session);
      setPlaybackPosition(0);
      setPlaybackDuration(0);
      setPlaybackState('Starting');
      setVideoSize({width: 0, height: 0});
      const initialVolume = session.getVolume();
      if (initialVolume >= 0) {
        setVolume(initialVolume);
      }
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
    [appendLog, playbackSession, waitForVideoSurface],
  );

  const playGenerated = useCallback(
    async (path: string, hasVideo: boolean) => {
      if (!(await FileSystem.exists(path))) {
        appendLog(`File not found: ${path}. Generate it first.`);
        return;
      }
      await startPlayback(
        `-hide_banner -loglevel info -autoexit -i ${quote(path)}`,
        path,
        hasVideo,
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
              <DemoButton label="Sync Version" onPress={() => void runGuarded('FFmpeg execute', runFfmpegAwaited)} />
              <DemoButton label="Help" onPress={() => void runGuarded('FFmpeg help', runHelp)} />
            </ButtonGrid>
            <CommandSection
              label="Enter FFmpeg command"
              value={ffmpegCommand}
              onChange={setFfmpegCommand}
              onRun={() => void runGuarded('Custom FFmpeg', runCustomFfmpeg)}
            />
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
              <DemoButton label="Sync Version" onPress={() => void runGuarded('FFprobe execute', runFfprobeAwaited)} />
            </ButtonGrid>
            <CommandSection
              label="Enter FFprobe command"
              value={ffprobeCommand}
              onChange={setFfprobeCommand}
              onRun={() => void runGuarded('Custom FFprobe', runCustomFfprobe)}
            />
          </View>
        );
      case 'FFplay':
        return (
          <View style={styles.section}>
            {platformName === 'Android' || platformName === 'iOS' ? (
              <>
                <View
                  style={[
                    styles.videoContainer,
                    {
                      width: videoDisplaySize.width,
                      height: videoDisplaySize.height,
                    },
                  ]}>
                  <FFplayView
                    style={styles.ffplayView}
                    onLayout={() => {
                      videoSurfaceReadyRef.current = true;
                    }}
                  />
                </View>
                <Text style={styles.help}>
                  {videoSize.width > 0 && videoSize.height > 0
                    ? `Decoded video: ${videoSize.width}x${videoSize.height}`
                    : 'FFplay video surface ready. Audio-only playback does not require video output.'}
                </Text>
              </>
            ) : null}
            <CommandSection
              label="Enter FFplay command"
              value={ffplayCommand}
              onChange={setFfplayCommand}
              onRun={() => void runGuarded('Custom FFplay', runCustomFfplay)}
            />
            <Text style={styles.subheading}>1. Generate Media:</Text>
            <ButtonGrid>
              <DemoButton label="Gen Video" onPress={() => void runGuarded('Generate video', generateTestVideo)} />
              <DemoButton label="Gen Audio" onPress={() => void runGuarded('Generate audio', generateTestAudio)} />
            </ButtonGrid>
            <Text style={styles.subheading}>2. Play Generated:</Text>
            <ButtonGrid>
              <DemoButton label="Play Video" onPress={() => void runGuarded('Play video', () => playGenerated(TEST_VIDEO_PATH, true))} />
              <DemoButton label="Play Audio" onPress={() => void runGuarded('Play audio', () => playGenerated(TEST_AUDIO_PATH, false))} />
            </ButtonGrid>
            <Text style={styles.subheading}>Controls:</Text>
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
              style={styles.playbackSlider}
              minimumTrackTintColor="#d0a7ff"
              maximumTrackTintColor="#4a444f"
              thumbTintColor="#d0a7ff"
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
              style={styles.playbackSlider}
              minimumTrackTintColor="#d0a7ff"
              maximumTrackTintColor="#4a444f"
              thumbTintColor="#d0a7ff"
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
    <View style={styles.root} accessibilityLabel={status}>
      <StatusBar barStyle="light-content" backgroundColor="#24212b" />

      <View style={styles.appBar}>
        <Text style={styles.title}>{isMobile ? 'FFmpeg Kit' : 'FFmpeg Kit Extended'}</Text>
        <View style={styles.appBarActions}>
          {!initialized ? <ActivityIndicator size="small" /> : null}
          <IconButton symbol="☷" label="Log Level" onPress={() => setLogLevelMenuVisible(true)} />
          <IconButton symbol="⚙" label="System Info" onPress={() => setSystemInfoMenuVisible(true)} />
          <IconButton symbol="⌫" label="Clear Logs" onPress={() => setLogs('')} />
        </View>
      </View>

      <View style={styles.tabs}>
        {TABS.map(tab => (
          <Pressable
            key={tab}
            accessibilityRole="tab"
            accessibilityState={{selected: activeTab === tab}}
            style={[styles.tab, activeTab === tab && styles.tabActive]}
            onPress={() => setActiveTab(tab)}>
            <Text style={[styles.tabIcon, activeTab === tab && styles.tabTextActive]}>{TAB_SYMBOLS[tab]}</Text>
            {!isMobile ? (
              <Text style={[styles.tabText, activeTab === tab && styles.tabTextActive]}>{tab}</Text>
            ) : null}
          </Pressable>
        ))}
      </View>

      <ScrollView
        style={styles.content}
        contentContainerStyle={styles.contentContainer}
        keyboardShouldPersistTaps="handled">
        {content}
      </ScrollView>

      <View
        accessibilityLabel="Resize log output"
        accessibilityRole="adjustable"
        style={styles.logResizeHandle}
        {...logResizePanResponder.panHandlers}>
        <View style={styles.logResizeGrip} />
      </View>

      <View style={[styles.logPane, {height: logPaneHeight}]}>
        <ScrollView ref={logScrollRef} style={styles.logScroll} contentContainerStyle={styles.logScrollContent}>
          <Text selectable style={styles.logText}>{logs}</Text>
        </ScrollView>
      </View>

      <PopupMenu visible={logLevelMenuVisible} onClose={() => setLogLevelMenuVisible(false)} width={220}>
        {LOG_LEVELS.map(level => {
          const selected = currentLogLevel === level;
          return (
            <MenuRow
              key={level}
              leading={selected ? '◉' : '○'}
              label={FFmpegKitConfig.logLevelToString(level).toUpperCase()}
              onPress={() => {
                setLogLevel(level);
                setLogLevelMenuVisible(false);
              }}
            />
          );
        })}
      </PopupMenu>

      <PopupMenu visible={systemInfoMenuVisible} onClose={() => setSystemInfoMenuVisible(false)} width={300} scrollable>
        {SYSTEM_INFO_ITEMS.map(([label, kind, leading]) => (
          <MenuRow
            key={kind}
            leading={leading}
            label={label}
            onPress={() => {
              setSystemInfoMenuVisible(false);
              logSystemInfo(kind);
            }}
          />
        ))}
      </PopupMenu>
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
      <Text style={styles.demoButtonIcon}>{buttonSymbol(label)}</Text>
      <Text style={styles.demoButtonText}>{label}</Text>
    </Pressable>
  );
}

function IconButton({
  symbol,
  label,
  onPress,
}: {
  symbol: string;
  label: string;
  onPress: () => void;
}): React.JSX.Element {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      hitSlop={8}
      onPress={onPress}
      style={({pressed}) => [styles.iconButton, pressed && styles.iconButtonPressed]}>
      <Text style={styles.iconButtonText}>{symbol}</Text>
    </Pressable>
  );
}

function PopupMenu({
  visible,
  onClose,
  width,
  scrollable = false,
  children,
}: {
  visible: boolean;
  onClose: () => void;
  width: number;
  scrollable?: boolean;
  children: React.ReactNode;
}): React.JSX.Element {
  const menu = <View style={[styles.popupMenu, {width}]}>{children}</View>;

  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <Pressable style={styles.popupBackdrop} onPress={onClose}>
        <Pressable style={styles.popupAnchor} onPress={event => event.stopPropagation()}>
          {scrollable ? (
            <ScrollView style={styles.popupScroll} contentContainerStyle={styles.popupScrollContent}>
              {menu}
            </ScrollView>
          ) : menu}
        </Pressable>
      </Pressable>
    </Modal>
  );
}

function MenuRow({
  leading,
  label,
  onPress,
}: {
  leading: string;
  label: string;
  onPress: () => void;
}): React.JSX.Element {
  return (
    <Pressable style={({pressed}) => [styles.menuRow, pressed && styles.menuRowPressed]} onPress={onPress}>
      <Text style={styles.menuRowLeading}>{leading}</Text>
      <Text style={styles.menuRowText}>{label}</Text>
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
      <Text style={styles.commandLabel}>Custom Command:</Text>
      <View style={styles.commandRow}>
        <TextInput
          style={[styles.input, styles.commandInput]}
          value={value}
          placeholder={label}
          placeholderTextColor="#77727f"
          onChangeText={onChange}
          autoCapitalize="none"
          autoCorrect={false}
        />
        <DemoButton label="Run" onPress={onRun} compact />
      </View>
    </View>
  );
}

function buttonSymbol(label: string): string {
  switch (label) {
    case 'Gen Video':
      return '▣';
    case 'Gen Audio':
      return '♪';
    case 'Async Version':
      return 'ϟ';
    case 'Sync Version':
      return '◷';
    case 'Help':
      return '?';
    case 'Pick File':
    case 'Pick Video File':
      return '▤';
    case 'Get Media Info':
      return '◉';
    case 'Record Stream':
      return '⇩';
    case 'Play Video':
    case 'Run':
      return '▶';
    case 'Play Audio':
      return '♪';
    case 'Pause':
      return 'Ⅱ';
    case 'Resume':
      return '▶';
    case 'Stop':
      return '■';
    case '-1s':
      return '↤';
    case '+1s':
      return '↦';
    case 'Refresh':
      return '↻';
    case 'Cancel':
      return '×';
    case 'Transcode MP4 → AVI':
    case 'Transcoding...':
      return '⇄';
    case 'Clear Selection':
      return '×';
    default:
      return '•';
  }
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
  root: {
    flex: 1,
    backgroundColor: '#141218',
  },
  flexOne: {
    flex: 1,
  },
  appBar: {
    height: 56,
    paddingLeft: 16,
    paddingRight: 8,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#25222c',
  },
  appBarActions: {
    marginLeft: 'auto',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
  },
  title: {
    fontSize: 20,
    fontWeight: '500',
    color: '#f2edf6',
  },
  iconButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  iconButtonPressed: {
    backgroundColor: '#3b3544',
  },
  iconButtonText: {
    color: '#eee8f2',
    fontSize: 20,
    lineHeight: 24,
  },
  tabs: {
    height: 50,
    flexDirection: 'row',
    backgroundColor: '#211e27',
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#39343f',
  },
  tab: {
    flex: 1,
    minWidth: 48,
    paddingHorizontal: 4,
    alignItems: 'center',
    justifyContent: 'center',
    borderBottomWidth: 2,
    borderBottomColor: 'transparent',
  },
  tabActive: {
    borderBottomColor: '#d0a7ff',
    backgroundColor: '#2b2732',
  },
  tabIcon: {
    fontSize: 17,
    color: '#bcb4c3',
    lineHeight: 20,
  },
  tabText: {
    marginTop: 1,
    fontSize: 10,
    color: '#aaa2b1',
  },
  tabTextActive: {
    color: '#d9baff',
    fontWeight: '700',
  },
  content: {
    flex: 3,
    backgroundColor: '#141218',
  },
  contentContainer: {
    paddingBottom: 24,
  },
  section: {
    padding: 16,
    gap: 22,
  },
  heading: {
    fontSize: 18,
    fontWeight: '700',
    color: '#f2edf6',
  },
  subheading: {
    fontSize: 13,
    fontWeight: '700',
    color: '#eee8f2',
  },
  bodyStrong: {
    fontSize: 12,
    fontWeight: '600',
    color: '#eee8f2',
  },
  help: {
    fontSize: 12,
    color: '#b8b0bd',
    lineHeight: 17,
  },
  monoSmall: {
    marginTop: 8,
    fontSize: 11,
    color: '#69f0ae',
    fontFamily: 'monospace',
  },
  card: {
    padding: 16,
    gap: 10,
    borderRadius: 10,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#45404a',
    backgroundColor: '#1d1b20',
  },
  buttonGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
    alignItems: 'center',
  },
  demoButton: {
    minHeight: 34,
    paddingHorizontal: 13,
    paddingVertical: 7,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    alignSelf: 'flex-start',
    borderRadius: 17,
    backgroundColor: '#30283d',
  },
  demoButtonCompact: {
    minHeight: 32,
    paddingHorizontal: 11,
    paddingVertical: 6,
  },
  demoButtonDisabled: {
    opacity: 0.42,
  },
  demoButtonPressed: {
    backgroundColor: '#463755',
  },
  demoButtonIcon: {
    fontSize: 12,
    color: '#d8b9ff',
  },
  demoButtonText: {
    fontSize: 11,
    fontWeight: '600',
    color: '#eadcff',
  },
  commandSection: {
    gap: 8,
  },
  commandLabel: {
    fontSize: 12,
    fontWeight: '700',
    color: '#eee8f2',
  },
  commandRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  input: {
    minHeight: 40,
    paddingHorizontal: 11,
    paddingVertical: 7,
    borderWidth: 1,
    borderColor: '#6d6672',
    borderRadius: 4,
    backgroundColor: '#141218',
    color: '#f2edf6',
    fontSize: 13,
  },
  commandInput: {
    flex: 1,
    minWidth: 0,
    fontFamily: 'monospace',
    fontSize: 12,
  },
  rowBetween: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 8,
  },
  jobRow: {
    flexDirection: 'row',
    gap: 10,
    paddingVertical: 10,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#45404a',
  },
  videoContainer: {
    alignSelf: 'center',
    overflow: 'hidden',
    borderRadius: 4,
    backgroundColor: '#000000',
  },
  ffplayView: {
    width: '100%',
    height: '100%',
  },
  playbackSlider: {
    width: '100%',
    height: 40,
  },
  videoPlaceholder: {
    minHeight: 170,
    padding: 18,
    justifyContent: 'center',
    alignItems: 'center',
    gap: 8,
    borderRadius: 4,
    backgroundColor: '#000000',
  },
  videoPlaceholderTitle: {
    color: '#f2edf6',
    fontWeight: '700',
  },
  videoPlaceholderText: {
    color: '#b8b0bd',
    fontSize: 12,
    textAlign: 'center',
    lineHeight: 17,
  },
  progressTrack: {
    height: 10,
    borderRadius: 5,
    backgroundColor: '#39343f',
    overflow: 'hidden',
  },
  progressValue: {
    height: '100%',
    backgroundColor: '#d0a7ff',
  },
  logResizeHandle: {
    height: 18,
    alignItems: 'center',
    justifyContent: 'center',
    borderTopWidth: StyleSheet.hairlineWidth,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderColor: '#4a444f',
    backgroundColor: '#1d1b20',
  },
  logResizeGrip: {
    width: 44,
    height: 4,
    borderRadius: 2,
    backgroundColor: '#77727f',
  },
  logPane: {
    flexShrink: 0,
    backgroundColor: '#000000',
  },
  logScroll: {
    flex: 1,
  },
  logScrollContent: {
    padding: 8,
  },
  logText: {
    fontFamily: 'monospace',
    fontSize: 11,
    lineHeight: 15,
    color: '#69f0ae',
  },
  popupBackdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.08)',
  },
  popupAnchor: {
    position: 'absolute',
    top: 46,
    right: 8,
    maxHeight: '88%',
    alignItems: 'flex-end',
  },
  popupScroll: {
    maxHeight: 650,
  },
  popupScrollContent: {
    alignItems: 'flex-end',
  },
  popupMenu: {
    paddingVertical: 6,
    borderRadius: 4,
    backgroundColor: '#302d35',
    shadowColor: '#000000',
    shadowOpacity: 0.4,
    shadowRadius: 12,
    shadowOffset: {width: 0, height: 6},
    elevation: 12,
  },
  menuRow: {
    minHeight: 42,
    paddingHorizontal: 14,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  menuRowPressed: {
    backgroundColor: '#443e4a',
  },
  menuRowLeading: {
    width: 20,
    color: '#d6cde0',
    fontSize: 14,
    textAlign: 'center',
  },
  menuRowText: {
    flex: 1,
    color: '#f2edf6',
    fontSize: 13,
  },
});
