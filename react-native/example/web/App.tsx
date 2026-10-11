import React, {useCallback, useEffect, useLayoutEffect, useRef, useState} from 'react';
import {
  Alert,
  AppBar,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  IconButton,
  LinearProgress,
  Menu,
  MenuItem,
  Paper,
  Slider,
  Stack,
  Tab,
  Tabs,
  TextField,
  Tooltip,
  Toolbar,
  Typography,
} from '@mui/material';
import {
  AudioFileRounded,
  CheckCircleRounded,
  CloudUploadRounded,
  DeleteOutlineRounded,
  FastForwardRounded,
  FastRewindRounded,
  FileOpenRounded,
  FullscreenRounded,
  HelpOutlineRounded,
  InfoOutlined,
  MovieCreationRounded,
  MusicNoteRounded,
  PauseRounded,
  PlayArrowRounded,
  PlayCircleOutlineRounded,
  RadioButtonCheckedRounded,
  RefreshRounded,
  SettingsRounded,
  StopRounded,
  TimerRounded,
  TransformRounded,
  TuneRounded,
  VolumeOffRounded,
  VolumeUpRounded,
} from '@mui/icons-material';
import {
  FFmpegKit,
  FFmpegKitExtended,
  FFplayKit,
  FFplayView,
  FFprobeKit,
  LogLevel,
  ReturnCode,
  SessionState,
} from 'ffmpeg-kit-extended';
import type {FFmpegSession, FFplaySession, Session, Statistics} from 'ffmpeg-kit-extended';

const TEST_FRAME_SOURCE =
  'color=c=red:size=512x512:rate=30:duration=2[red];' +
  'color=c=green:size=512x512:rate=30:duration=2[green];' +
  'color=c=blue:size=512x512:rate=30:duration=2[blue];' +
  'color=c=white:size=512x512:rate=30:duration=2[white];' +
  '[red][green][blue][white]concat=n=4:v=1:a=0';

const VIDEO_PATH = '/tmp/ffmpeg-kit-web-test.mp4';
const AUDIO_PATH = '/tmp/ffmpeg-kit-web-test.wav';
const TRANSCODE_PATH = '/tmp/ffmpeg-kit-web-output.avi';
const STREAM_PATH = '/tmp/ffmpeg-kit-web-stream.mkv';
const MAX_LOG_LENGTH = 50_000;

type TabId = 'ffmpeg' | 'stream' | 'ffprobe' | 'ffplay' | 'transcode';
type JobKind = 'ffmpeg' | 'stream' | 'ffprobe' | 'playback' | 'transcode';

type ActiveJob = {
  id: number;
  label: string;
  kind: JobKind;
  session: Session;
  statistics?: Statistics;
};

type RuntimeCapabilities = {
  video: boolean;
  audio: boolean;
  transcode: boolean;
  detail: string;
};

type PlaybackSnapshot = {
  playing: boolean;
  paused: boolean;
  position: number;
  duration: number;
  volume: number;
};

const TABS: Array<{id: TabId; label: string; icon: React.ReactElement}> = [
  {id: 'ffmpeg', label: 'FFmpeg', icon: <MovieCreationRounded />},
  {id: 'stream', label: 'Stream', icon: <RadioButtonCheckedRounded />},
  {id: 'ffprobe', label: 'FFprobe', icon: <InfoOutlined />},
  {id: 'ffplay', label: 'FFplay', icon: <PlayArrowRounded />},
  {id: 'transcode', label: 'Transcode', icon: <TransformRounded />},
];

const LOG_LEVELS = Object.entries(LogLevel)
  .filter((entry): entry is [string, LogLevel] => typeof entry[1] === 'number')
  .map(([name, level]) => ({name, level}))
  .sort((left, right) => left.level - right.level);

const initialPlayback: PlaybackSnapshot = {
  playing: false,
  paused: false,
  position: 0,
  duration: 0,
  volume: 1,
};

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function quoteCommandArg(value: string): string {
  return `"${value.replace(/["\\]/g, '\\$1')}"`;
}

function containsName(list: string, name: string): boolean {
  return new RegExp(`(^|[^a-z0-9_])${name}([^a-z0-9_]|$)`, 'i').test(list);
}

function formatTime(seconds: number): string {
  if (!Number.isFinite(seconds) || seconds < 0) return '0:00';
  const whole = Math.floor(seconds);
  const minutes = Math.floor(whole / 60);
  const remaining = String(whole % 60).padStart(2, '0');
  return `${minutes}:${remaining}`;
}

function formatBytes(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes <= 0) return '0 B';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function CommandRow({
  label,
  value,
  onChange,
  onRun,
  runLabel,
  disabled = false,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  onRun: () => void;
  runLabel: string;
  disabled?: boolean;
}): React.JSX.Element {
  return (
    <Box className="command-row">
      <TextField
        className="command-row-field"
        fullWidth
        size="small"
        label={label}
        value={value}
        onChange={(event) => onChange(event.target.value)}
        onKeyDown={(event) => {
          if (event.key === 'Enter' && !disabled) onRun();
        }}
        inputProps={{'aria-label': label}}
      />
      <Button
        variant="text"
        color="primary"
        startIcon={<PlayArrowRounded />}
        disabled={disabled}
        onClick={onRun}
        aria-label={runLabel}
      >
        Run
      </Button>
    </Box>
  );
}

function ActionButton({
  label,
  icon,
  onClick,
  disabled = false,
  title,
}: {
  label: string;
  icon: React.ReactNode;
  onClick: () => void;
  disabled?: boolean;
  title?: string;
}): React.JSX.Element {
  const button = (
    <Button
      variant="text"
      color="primary"
      size="small"
      startIcon={icon}
      onClick={onClick}
      disabled={disabled}
      title={title}
    >
      {label}
    </Button>
  );
  return title ? <Tooltip title={title}><span>{button}</span></Tooltip> : button;
}

export default function App(): React.JSX.Element {
  const [tab, setTab] = useState<TabId>('ffmpeg');
  const [runtimeState, setRuntimeState] = useState<'idle' | 'initializing' | 'ready' | 'error'>('idle');
  const [status, setStatus] = useState('Not initialized');
  const [runtimeError, setRuntimeError] = useState<string>();
  const [lastError, setLastError] = useState<string>();
  const [logs, setLogs] = useState('');
  const [busyActions, setBusyActions] = useState<Record<string, boolean>>({});
  const [activeJobs, setActiveJobs] = useState<ActiveJob[]>([]);
  const [capabilities, setCapabilities] = useState<RuntimeCapabilities>({
    video: false,
    audio: false,
    transcode: false,
    detail: 'Waiting for the local Web runtime.',
  });
  const [videoPath, setVideoPath] = useState<string>();
  const [audioPath, setAudioPath] = useState<string>();
  const [ffmpegCommand, setFFmpegCommand] = useState('-nostdin -version');
  const [ffprobeCommand, setFFprobeCommand] = useState('-version');
  const [ffplayCommand, setFFplayCommand] = useState(`-hide_banner -i ${VIDEO_PATH} -autoexit`);
  const [streamUrl, setStreamUrl] = useState('https://endpnt.com/hls/nasa4k/playlist.m3u8');
  const [mediaInfoText, setMediaInfoText] = useState('');
  const [transcodeStats, setTranscodeStats] = useState<Statistics>();
  const [selectedLogLevel, setSelectedLogLevel] = useState<LogLevel>(LogLevel.Info);
  const [logMenuAnchor, setLogMenuAnchor] = useState<HTMLElement | null>(null);
  const [systemMenuAnchor, setSystemMenuAnchor] = useState<HTMLElement | null>(null);
  const [player, setPlayer] = useState<FFplaySession>();
  const [playback, setPlayback] = useState<PlaybackSnapshot>(initialPlayback);
  const [fullscreenSupported, setFullscreenSupported] = useState(false);

  const initializationRef = useRef<Promise<void> | undefined>(undefined);
  const busyRef = useRef(new Set<string>());
  const jobsRef = useRef(new Map<number, ActiveJob>());
  const logScrollRef = useRef<HTMLDivElement>(null);
  const videoHostRef = useRef<HTMLDivElement>(null);
  const playerRef = useRef<FFplaySession | undefined>(undefined);
  const previousVolumeRef = useRef(1);
  const queuedLogsRef = useRef('');
  const logTimerRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const shouldAutoScrollRef = useRef(true);
  const videoGenerationRef = useRef<Promise<string> | undefined>(undefined);
  const audioGenerationRef = useRef<Promise<string> | undefined>(undefined);

  const flushLogs = useCallback(() => {
    if (logTimerRef.current) {
      clearTimeout(logTimerRef.current);
      logTimerRef.current = undefined;
    }
    const queued = queuedLogsRef.current;
    queuedLogsRef.current = '';
    if (!queued) return;
    setLogs((current) => {
      const combined = current + queued;
      return combined.length > MAX_LOG_LENGTH ? combined.slice(-MAX_LOG_LENGTH) : combined;
    });
  }, []);

  const appendLog = useCallback(
    (message: string) => {
      if (!message) return;
      queuedLogsRef.current += message.endsWith('\n') ? message : `${message}\n`;
      if (!logTimerRef.current) logTimerRef.current = setTimeout(flushLogs, 250);
    },
    [flushLogs],
  );

  useLayoutEffect(() => {
    const scroller = logScrollRef.current;
    if (scroller && shouldAutoScrollRef.current) scroller.scrollTop = scroller.scrollHeight;
  }, [logs]);

  useEffect(
    () => () => {
      if (logTimerRef.current) {
        clearTimeout(logTimerRef.current);
        logTimerRef.current = undefined;
      }
    },
    [],
  );

  const updateJob = useCallback((job: ActiveJob) => {
    jobsRef.current.set(job.id, job);
    setActiveJobs(Array.from(jobsRef.current.values()));
  }, []);

  const removeJob = useCallback((id: number) => {
    jobsRef.current.delete(id);
    setActiveJobs(Array.from(jobsRef.current.values()));
  }, []);

  const trackSession = useCallback(
    function trackSession<T extends Session>(
      session: T,
      label: string,
      kind: JobKind,
      start: () => Promise<T>,
    ): Promise<T> {
      const id = session.getSessionId();
      updateJob({id, label, kind, session});
      setStatus(`${label} running`);
      appendLog(`${label} started (session ${id}).`);

      let execution: Promise<T>;
      try {
        execution = start();
      } catch (error) {
        removeJob(id);
        const message = errorMessage(error);
        setLastError(message);
        setStatus(`${label} failed`);
        appendLog(`${label} failed: ${message}`);
        return Promise.reject(error);
      }

      return execution
        .then((completed) => {
          const returnCode = completed.getReturnCode();
          const succeeded = returnCode === ReturnCode.Success;
          setStatus(`${label} ${succeeded ? 'completed' : `ended with return code ${returnCode}`}`);
          if (!succeeded) setLastError(`${label} returned code ${returnCode}.`);
          appendLog(`${label} finished (session ${id}; return code ${returnCode}).`);
          return completed;
        })
        .catch((error: unknown) => {
          const message = errorMessage(error);
          setLastError(message);
          setStatus(`${label} failed`);
          appendLog(`${label} failed: ${message}`);
          throw error;
        })
        .finally(() => removeJob(id));
    },
    [appendLog, removeJob, updateJob],
  );

  const runFFmpeg = useCallback(
    (
      label: string,
      command: string,
      kind: JobKind = 'ffmpeg',
      onStatistics?: (statistics: Statistics) => void,
    ): Promise<FFmpegSession> => {
      const session = FFmpegKit.createSession(command);
      const id = session.getSessionId();
      let logCount = 0;
      let statisticsCount = 0;
      let lastStatsUpdate = 0;
      appendLog(`$ ffmpeg ${command}`);
      return trackSession(session, label, kind, () =>
        session.executeAsync({
          logCallback: (log) => {
            logCount += 1;
            appendLog(log.message);
          },
          statisticsCallback: (statistics) => {
            statisticsCount += 1;
            const now = Date.now();
            if (now - lastStatsUpdate >= 250) {
              lastStatsUpdate = now;
              const current = jobsRef.current.get(id);
              if (current) updateJob({...current, statistics});
              onStatistics?.(statistics);
            }
          },
        }),
      ).then((completed) => {
        appendLog(`${label} callback counts: log=${logCount}, statistics=${statisticsCount}.`);
        return completed;
      });
    },
    [appendLog, jobsRef, trackSession, updateJob],
  );

  const runFFprobe = useCallback(
    (label: string, command: string): Promise<Session> => {
      const session = FFprobeKit.createSession(command);
      appendLog(`$ ffprobe ${command}`);
      return trackSession(session, label, 'ffprobe', () =>
        session.executeAsync({logCallback: (log) => appendLog(log.message)}),
      );
    },
    [appendLog, trackSession],
  );

  const runUiAction = useCallback(
    async (key: string, action: () => Promise<unknown> | unknown): Promise<void> => {
      if (busyRef.current.has(key)) return;
      busyRef.current.add(key);
      setBusyActions((current) => ({...current, [key]: true}));
      setLastError(undefined);
      try {
        await action();
      } catch (error) {
        const message = errorMessage(error);
        setLastError(message);
        setStatus(`${key} failed`);
        appendLog(`${key} failed: ${message}`);
      } finally {
        busyRef.current.delete(key);
        setBusyActions((current) => ({...current, [key]: false}));
      }
    },
    [appendLog],
  );

  const readRuntimeCapabilities = useCallback(() => {
    try {
      const encoders = FFmpegKitExtended.getRegisteredEncoders();
      const muxers = FFmpegKitExtended.getRegisteredMuxers();
      const hasMpeg4 = containsName(encoders, 'mpeg4');
      const hasPcm = containsName(encoders, 'pcm_s16le');
      const hasMp4 = containsName(muxers, 'mp4');
      const hasWav = containsName(muxers, 'wav');
      const hasAvi = containsName(muxers, 'avi');
      const video = hasMpeg4 && hasMp4;
      const audio = hasPcm && hasWav;
      const transcode = video && hasAvi;
      const missing = [
        !hasMpeg4 && 'MPEG-4 video encoder',
        !hasPcm && 'PCM signed 16-bit audio encoder',
        !hasMp4 && 'MP4 muxer',
        !hasWav && 'WAV muxer',
        !hasAvi && 'AVI muxer',
      ].filter(Boolean);
      setCapabilities({
        video,
        audio,
        transcode,
        detail: missing.length
          ? `This Web bundle does not list: ${missing.join(', ')}.`
          : 'The configured Web bundle lists the encoders and muxers used by the generated-media flows.',
      });
    } catch (error) {
      setCapabilities({
        video: false,
        audio: false,
        transcode: false,
        detail: `Could not inspect Web bundle codecs: ${errorMessage(error)}`,
      });
    }
  }, []);

  const initializeRuntime = useCallback(async () => {
    if (FFmpegKitExtended.initialized) {
      setRuntimeState('ready');
      setRuntimeError(undefined);
      const version = FFmpegKitExtended.getVersion();
      setStatus(`Initialized ${version}`);
      return;
    }
    setRuntimeState('initializing');
    setRuntimeError(undefined);
    setLastError(undefined);
    setStatus('Initializing Web runtime…');
    appendLog('Loading the configured local Web FFmpeg runtime.');
    try {
      initializationRef.current ??= FFmpegKitExtended.initialize();
      await initializationRef.current;
      setRuntimeState('ready');
      readRuntimeCapabilities();
      const version = FFmpegKitExtended.getVersion();
      setStatus(`Initialized ${version}`);
      appendLog(`Web runtime ready: FFmpegKit Extended ${version}.`);
      setSelectedLogLevel(FFmpegKitExtended.getLogLevel() as LogLevel);
    } catch (error) {
      initializationRef.current = undefined;
      const message = errorMessage(error);
      setRuntimeState('error');
      setRuntimeError(message);
      setStatus(`Initialization failed: ${message}`);
      appendLog(`Web runtime initialization failed: ${message}`);
    }
  }, [appendLog, readRuntimeCapabilities]);

  useEffect(() => {
    void initializeRuntime();
  }, [initializeRuntime]);

  useEffect(() => {
    setFullscreenSupported(
      typeof document !== 'undefined' &&
        document.fullscreenEnabled &&
        typeof videoHostRef.current?.requestFullscreen === 'function',
    );
  }, []);

  useEffect(() => {
    playerRef.current = player;
    if (!player) {
      setPlayback(initialPlayback);
      return;
    }
    const refresh = () => {
      try {
        setPlayback({
          playing: player.isPlaying(),
          paused: player.isPaused(),
          position: Math.max(0, player.getPosition()),
          duration: Math.max(0, player.getMediaDuration()),
          volume: Math.max(0, Math.min(1, player.getVolume())),
        });
      } catch (error) {
        setLastError(`FFplay state is unavailable: ${errorMessage(error)}`);
      }
    };
    refresh();
    const timer = window.setInterval(refresh, 250);
    return () => window.clearInterval(timer);
  }, [player]);

  const ensureVideo = useCallback(async (): Promise<string> => {
    if (videoPath) return videoPath;
    if (!capabilities.video) throw new Error(capabilities.detail);
    if (!videoGenerationRef.current) {
      videoGenerationRef.current = (async () => {
        const command =
          `-hide_banner -nostdin -loglevel info -f lavfi -i ${quoteCommandArg(TEST_FRAME_SOURCE)} ` +
          `-t 8 -an -c:v mpeg4 -f mp4 -y ${quoteCommandArg(VIDEO_PATH)}`;
        const session = await runFFmpeg('Generate test video', command);
        if (session.getReturnCode() !== ReturnCode.Success) {
          throw new Error(`Video generation returned code ${session.getReturnCode()}.`);
        }
        setVideoPath(VIDEO_PATH);
        appendLog(`Generated browser-runtime video at ${VIDEO_PATH}.`);
        return VIDEO_PATH;
      })();
    }
    try {
      return await videoGenerationRef.current;
    } finally {
      videoGenerationRef.current = undefined;
    }
  }, [appendLog, capabilities, runFFmpeg, videoPath]);

  const ensureAudio = useCallback(async (): Promise<string> => {
    if (audioPath) return audioPath;
    if (!capabilities.audio) throw new Error(capabilities.detail);
    if (!audioGenerationRef.current) {
      audioGenerationRef.current = (async () => {
        const command =
          `-hide_banner -nostdin -loglevel info -f lavfi -i ` +
          `${quoteCommandArg('sine=frequency=440:sample_rate=44100:duration=8')} ` +
          `-c:a pcm_s16le -f wav -y ${quoteCommandArg(AUDIO_PATH)}`;
        const session = await runFFmpeg('Generate test audio', command);
        if (session.getReturnCode() !== ReturnCode.Success) {
          throw new Error(`Audio generation returned code ${session.getReturnCode()}.`);
        }
        setAudioPath(AUDIO_PATH);
        appendLog(`Generated browser-runtime audio at ${AUDIO_PATH}.`);
        return AUDIO_PATH;
      })();
    }
    try {
      return await audioGenerationRef.current;
    } finally {
      audioGenerationRef.current = undefined;
    }
  }, [appendLog, audioPath, capabilities, runFFmpeg]);

  const generateVideo = () =>
    runUiAction('generate-video', async () => {
      await ensureVideo();
      setStatus(`Generated video at ${VIDEO_PATH}`);
    });

  const generateAudio = () =>
    runUiAction('generate-audio', async () => {
      await ensureAudio();
      setStatus(`Generated audio at ${AUDIO_PATH}`);
    });

  const launchPlayback = useCallback(
    async (label: string, command: string) => {
      if (!FFmpegKitExtended.initialized) throw new Error('Initialize the Web runtime before starting playback.');
      if (playerRef.current) throw new Error('Stop the current FFplay session before starting another.');
      const session = FFplayKit.createSession(command);
      playerRef.current = session;
      setPlayer(session);
      setPlayback(initialPlayback);
      appendLog(`$ ffplay ${command}`);
      const completion = trackSession(session, label, 'playback', () =>
        session.executeAsync({logCallback: (log) => appendLog(log.message)}),
      );
      void completion
        .then((completed) => {
          const code = completed.getReturnCode();
          if (code !== ReturnCode.Success) setLastError(`FFplay returned code ${code}.`);
        })
        .catch(() => undefined)
        .finally(() => {
          if (playerRef.current?.sessionId === session.sessionId) {
            playerRef.current = undefined;
            setPlayer(undefined);
          }
        });
    },
    [appendLog, trackSession],
  );

  const playGeneratedVideo = () =>
    runUiAction('play-generated-video', async () => {
      const path = await ensureVideo();
      const command = `-hide_banner -loglevel info -i ${quoteCommandArg(path)} -autoexit`;
      await launchPlayback('Play generated video', command);
    });

  const playGeneratedAudio = () =>
    runUiAction('play-generated-audio', async () => {
      const path = await ensureAudio();
      const command = `-hide_banner -loglevel info -i ${quoteCommandArg(path)} -autoexit`;
      await launchPlayback('Play generated audio', command);
    });

  const runCustomPlayback = () =>
    runUiAction('run-ffplay-command', async () => {
      await launchPlayback('Custom FFplay command', ffplayCommand);
    });

  const runFFmpegCommand = () =>
    runUiAction('run-ffmpeg-command', async () => {
      const session = await runFFmpeg('Custom FFmpeg command', ffmpegCommand);
      if (session.getReturnCode() !== ReturnCode.Success) {
        throw new Error(`FFmpeg returned code ${session.getReturnCode()}.`);
      }
    });

  const runFFprobeCommand = () =>
    runUiAction('run-ffprobe-command', async () => {
      const session = await runFFprobe('Custom FFprobe command', ffprobeCommand);
      if (session.getReturnCode() !== ReturnCode.Success) {
        throw new Error(`FFprobe returned code ${session.getReturnCode()}.`);
      }
      appendLog(session.getOutput());
    });

  const getFFmpegVersion = (awaitCompletion: boolean) => {
    if (awaitCompletion) {
      return runUiAction('ffmpeg-version-awaited', async () => {
        const session = await runFFmpeg('Awaited FFmpeg version', '-version');
        if (session.getReturnCode() !== ReturnCode.Success) {
          throw new Error(`FFmpeg -version returned code ${session.getReturnCode()}.`);
        }
      });
    }
    return runUiAction('ffmpeg-version-async', () => {
      void runFFmpeg('Async FFmpeg version', '-version').catch(() => undefined);
    });
  };

  const getFFprobeVersion = (awaitCompletion: boolean) => {
    if (awaitCompletion) {
      return runUiAction('ffprobe-version-awaited', async () => {
        const session = await runFFprobe('Awaited FFprobe version', '-version');
        if (session.getReturnCode() !== ReturnCode.Success) {
          throw new Error(`FFprobe -version returned code ${session.getReturnCode()}.`);
        }
      });
    }
    return runUiAction('ffprobe-version-async', () => {
      void runFFprobe('Async FFprobe version', '-version').catch(() => undefined);
    });
  };

  const runMediaInfo = () =>
    runUiAction('get-media-info', async () => {
      const path = await ensureVideo();
      appendLog(`$ ffprobe media information ${quoteCommandArg(path)}`);
      const session = await FFprobeKit.getMediaInformation(path);
      const information = session.getMediaInformation();
      if (!information) throw new Error(session.getOutput() || 'FFprobe returned no media information.');
      const rendered = JSON.stringify(information, null, 2);
      setMediaInfoText(rendered);
      appendLog(`Media information for ${path}:\n${rendered}`);
      setStatus(`Media info: ${information.streams?.length ?? 0} stream(s)`);
    });

  const startStream = () =>
    runUiAction('record-stream', async () => {
      const url = streamUrl.trim();
      if (!/^https?:\/\//i.test(url)) throw new Error('Enter an HTTP or HTTPS stream URL.');
      if (activeJobs.some((job) => job.kind === 'stream')) {
        throw new Error('A remote stream recording is already active.');
      }
      const command =
        `-hide_banner -nostdin -loglevel info -i ${quoteCommandArg(url)} ` +
        `-c copy -y ${quoteCommandArg(STREAM_PATH)}`;
      const session = FFmpegKit.createSession(command);
      const completion = trackSession(session, 'Remote stream recording', 'stream', () =>
        session.executeAsync({
          logCallback: (log) => appendLog(log.message),
          statisticsCallback: (statistics) => {
            const current = jobsRef.current.get(session.sessionId);
            if (current) updateJob({...current, statistics});
          },
        }),
      );
      void completion.catch(() => undefined);
      setStatus(`Recording stream to Wasm path ${STREAM_PATH}`);
    });

  const refreshStreams = () => {
    const current = Array.from(jobsRef.current.values()).filter((job) => job.kind === 'stream');
    for (const job of current) {
      try {
        const state = job.session.getState();
        if (state === SessionState.Completed || state === SessionState.Failed) removeJob(job.id);
      } catch {
        removeJob(job.id);
      }
    }
    appendLog(`Refreshed active stream sessions: ${Array.from(jobsRef.current.values()).filter((job) => job.kind === 'stream').length}.`);
  };

  const cancelStream = (job: ActiveJob) =>
    runUiAction(`cancel-stream-${job.id}`, async () => {
      await job.session.cancel();
      appendLog(`Cancellation requested for stream session ${job.id}.`);
      setStatus(`Cancellation requested for stream session ${job.id}`);
    });

  const runTranscode = () =>
    runUiAction('transcode-video', async () => {
      if (!capabilities.transcode) throw new Error(capabilities.detail);
      const path = await ensureVideo();
      setTranscodeStats(undefined);
      const command =
        `-hide_banner -nostdin -loglevel info -i ${quoteCommandArg(path)} ` +
        `-an -c:v mpeg4 -y ${quoteCommandArg(TRANSCODE_PATH)}`;
      const session = await runFFmpeg('Transcode MP4 to AVI', command, 'transcode', setTranscodeStats);
      if (session.getReturnCode() !== ReturnCode.Success) {
        throw new Error(`Transcode returned code ${session.getReturnCode()}.`);
      }
      setStatus(`Transcode complete at Wasm path ${TRANSCODE_PATH}`);
      appendLog(`Transcode output remains in the browser Wasm filesystem: ${TRANSCODE_PATH}.`);
    });

  const refreshPlayback = useCallback(() => {
    const current = playerRef.current;
    if (!current) return;
    try {
      setPlayback({
        playing: current.isPlaying(),
        paused: current.isPaused(),
        position: Math.max(0, current.getPosition()),
        duration: Math.max(0, current.getMediaDuration()),
        volume: Math.max(0, Math.min(1, current.getVolume())),
      });
    } catch (error) {
      setLastError(`FFplay controls are unavailable: ${errorMessage(error)}`);
      appendLog(`FFplay state read failed: ${errorMessage(error)}`);
    }
  }, [appendLog]);

  const controlPlayback = (label: string, action: (session: FFplaySession) => Promise<void>) =>
    runUiAction(`ffplay-${label}`, async () => {
      const current = playerRef.current;
      if (!current) throw new Error('No active FFplay session.');
      await action(current);
      refreshPlayback();
      appendLog(`FFplay ${label} requested for session ${current.sessionId}.`);
    });

  const seekTo = (position: number) =>
    controlPlayback('seek', (session) => session.setPosition(position));

  const setPlayerVolume = (value: number) =>
    controlPlayback('volume', async (session) => {
      await session.setVolume(value);
      if (value > 0) previousVolumeRef.current = value;
      setPlayback((current) => ({...current, volume: value}));
    });

  const toggleMute = () => {
    if (playback.volume > 0) {
      previousVolumeRef.current = playback.volume;
      void setPlayerVolume(0);
    } else {
      void setPlayerVolume(previousVolumeRef.current || 1);
    }
  };

  const toggleFullscreen = async () => {
    const host = videoHostRef.current;
    if (!host || !fullscreenSupported) return;
    try {
      if (document.fullscreenElement === host) await document.exitFullscreen();
      else await host.requestFullscreen();
    } catch (error) {
      const message = errorMessage(error);
      setLastError(`Fullscreen failed: ${message}`);
      appendLog(`FFplay fullscreen failed: ${message}`);
    }
  };

  const setLogLevel = (level: LogLevel) => {
    setLogMenuAnchor(null);
    void runUiAction(`log-level-${LogLevel[level]}`, async () => {
      await FFmpegKitExtended.setLogLevel(level);
      setSelectedLogLevel(level);
      const name = LogLevel[level] ?? String(level);
      appendLog(`FFmpeg log level set to ${name}.`);
      setStatus(`Log level: ${name}`);
    });
  };

  const showSystemInfo = (label: string, read: () => unknown) => {
    setSystemMenuAnchor(null);
    void runUiAction(`system-info-${label.toLowerCase().replace(/[^a-z0-9]+/g, '-')}`, () => {
      const value = read();
      const body = typeof value === 'string' ? value : JSON.stringify(value, null, 2);
      appendLog(`${label}:\n${body || '(empty)'}`);
      setStatus(`System info: ${label}`);
    });
  };

  const systemInfoActions: Array<{label: string; read: () => unknown}> = [
    {
      label: 'Basic System Info',
      read: () => ({
        browser: typeof navigator === 'undefined' ? 'Unavailable' : navigator.userAgent,
        language: typeof navigator === 'undefined' ? 'Unavailable' : navigator.language,
        origin: typeof location === 'undefined' ? 'Unavailable' : location.origin,
        ffmpegVersion: FFmpegKitExtended.getFFmpegVersion(),
        architecture: FFmpegKitExtended.getFFmpegArchitecture(),
      }),
    },
    {label: 'FFmpeg Version', read: () => FFmpegKitExtended.getFFmpegVersion()},
    {label: 'FFmpeg Architecture', read: () => FFmpegKitExtended.getFFmpegArchitecture()},
    {label: 'FFmpegKit Version', read: () => FFmpegKitExtended.getVersion()},
    {label: 'Package Name', read: () => FFmpegKitExtended.getPackageName()},
    {label: 'External Libraries', read: () => FFmpegKitExtended.getExternalLibraries()},
    {label: 'Bundle Type', read: () => FFmpegKitExtended.getBundleType()},
    {label: 'GPL / Non-free', read: () => ({gpl: FFmpegKitExtended.isGpl(), nonfree: FFmpegKitExtended.isNonfree()})},
    {label: 'Registered Codecs', read: () => FFmpegKitExtended.getRegisteredCodecs()},
    {label: 'Registered Encoders', read: () => FFmpegKitExtended.getRegisteredEncoders()},
    {label: 'Registered Decoders', read: () => FFmpegKitExtended.getRegisteredDecoders()},
    {label: 'Registered Muxers', read: () => FFmpegKitExtended.getRegisteredMuxers()},
    {label: 'Registered Demuxers', read: () => FFmpegKitExtended.getRegisteredDemuxers()},
    {label: 'Registered Filters', read: () => FFmpegKitExtended.getRegisteredFilters()},
    {label: 'Registered Protocols', read: () => FFmpegKitExtended.getRegisteredProtocols()},
    {label: 'Registered Bitstream Filters', read: () => FFmpegKitExtended.getRegisteredBitstreamFilters()},
    {label: 'Build Configuration', read: () => FFmpegKitExtended.getBuildConfiguration()},
    {label: 'Build Date', read: () => FFmpegKitExtended.getBuildDate()},
  ];

  const activeStreamJobs = activeJobs.filter((job) => job.kind === 'stream');
  const transcodeJob = activeJobs.find((job) => job.kind === 'transcode');
  const transcodeProgress = transcodeJob?.statistics ?? transcodeStats;
  const selectedLogName = LogLevel[selectedLogLevel] ?? String(selectedLogLevel);

  const panel = (id: TabId, children: React.ReactNode) => (
    <Box
      key={id}
      id={`panel-${id}`}
      role="tabpanel"
      aria-labelledby={`tab-${id}`}
      aria-hidden={tab !== id}
      tabIndex={tab === id ? 0 : -1}
      className={`tab-panel ${tab === id ? 'tab-panel-active' : 'tab-panel-inactive'}`}
    >
      {runtimeError && (
        <Alert severity="error" className="alert-inline" action={
          <Button color="inherit" size="small" onClick={() => void initializeRuntime()}>
            Retry
          </Button>
        }>
          Local Web runtime failed to initialize: {runtimeError}
        </Alert>
      )}
      {lastError && !runtimeError && <Alert severity="warning" className="alert-inline">{lastError}</Alert>}
      {children}
    </Box>
  );

  return (
    <Box className="app-shell">
      <AppBar position="static" elevation={0}>
        <Toolbar className="top-toolbar">
          <Typography variant="h6" className="app-title">FFmpeg Kit Extended</Typography>
          <Box className="toolbar-spacer" />
          <Tooltip title="Set the FFmpeg log level">
            <span>
              <IconButton
                color="inherit"
                aria-label="Log level"
                disabled={runtimeState !== 'ready'}
                onClick={(event) => setLogMenuAnchor(event.currentTarget)}
              >
                <TuneRounded />
              </IconButton>
            </span>
          </Tooltip>
          <Tooltip title="System information">
            <span>
              <IconButton
                color="inherit"
                aria-label="System info"
                disabled={runtimeState !== 'ready'}
                onClick={(event) => setSystemMenuAnchor(event.currentTarget)}
              >
                <SettingsRounded />
              </IconButton>
            </span>
          </Tooltip>
          <Tooltip title="Clear the visible log. Running sessions continue.">
            <IconButton color="inherit" aria-label="Clear logs" onClick={() => {
              queuedLogsRef.current = '';
              if (logTimerRef.current) clearTimeout(logTimerRef.current);
              logTimerRef.current = undefined;
              setLogs('');
            }}>
              <DeleteOutlineRounded />
            </IconButton>
          </Tooltip>
          <Button
            color="primary"
            size="small"
            disabled={runtimeState === 'initializing'}
            onClick={() => void initializeRuntime()}
          >
            {runtimeState === 'error' ? 'Retry Initialize' : 'Initialize'}
          </Button>
          <Chip
            className="runtime-status"
            size="small"
            color={runtimeState === 'ready' ? 'success' : runtimeState === 'error' ? 'error' : 'default'}
            variant={runtimeState === 'ready' ? 'outlined' : 'filled'}
            label={status}
            data-testid="status"
            title={status}
          />
        </Toolbar>
      </AppBar>

      <Tabs
        className="top-tabs"
        value={tab}
        onChange={(_, value: TabId) => setTab(value)}
        variant="fullWidth"
        aria-label="FFmpeg tools"
      >
        {TABS.map((item) => (
          <Tab
            key={item.id}
            id={`tab-${item.id}`}
            aria-label={item.label}
            aria-controls={`panel-${item.id}`}
            data-testid={`tab.${item.id}`}
            value={item.id}
            icon={item.icon}
            iconPosition="top"
            label={<span className="tab-label">{item.label}</span>}
          />
        ))}
      </Tabs>

      <Box className="workspace">
        <Box className="content-frame">
          {panel(
            'ffmpeg',
            <Stack className="screen-stack">
              <Box className="quick-actions">
                <ActionButton label="Gen Video" icon={<MovieCreationRounded />} onClick={() => void generateVideo()} disabled={!capabilities.video || runtimeState !== 'ready' || busyActions['generate-video']} title={capabilities.video ? 'Create an eight-second four-color MP4 in the browser Wasm filesystem.' : capabilities.detail} />
                <ActionButton label="Gen Audio" icon={<MusicNoteRounded />} onClick={() => void generateAudio()} disabled={!capabilities.audio || runtimeState !== 'ready' || busyActions['generate-audio']} title={capabilities.audio ? 'Create an eight-second WAV in the browser Wasm filesystem.' : capabilities.detail} />
                <ActionButton label="Async Version" icon={<PlayArrowRounded />} onClick={() => void getFFmpegVersion(false)} disabled={runtimeState !== 'ready' || busyActions['ffmpeg-version-async']} title="Start an asynchronous FFmpeg session and keep the browser responsive." />
                <ActionButton label="Sync Version" icon={<TimerRounded />} onClick={() => void getFFmpegVersion(true)} disabled={runtimeState !== 'ready' || busyActions['ffmpeg-version-awaited']} title="Await the Web Promise; JavaScript remains responsive." />
                <ActionButton label="Help" icon={<HelpOutlineRounded />} onClick={() => void runUiAction('ffmpeg-help', async () => { await runFFmpeg('FFmpeg help', '-h'); })} disabled={runtimeState !== 'ready' || busyActions['ffmpeg-help']} />
              </Box>
              <CommandRow
                label="Custom Command:"
                value={ffmpegCommand}
                onChange={setFFmpegCommand}
                onRun={() => void runFFmpegCommand()}
                runLabel="Run FFmpeg"
                disabled={runtimeState !== 'ready' || busyActions['run-ffmpeg-command']}
              />
              {!capabilities.video && <Alert severity="info">Generated MP4 video is unavailable: {capabilities.detail}</Alert>}
              {videoPath && <Typography variant="caption" color="text.secondary">Generated video: {videoPath} (browser Wasm filesystem)</Typography>}
              {audioPath && <Typography variant="caption" color="text.secondary">Generated audio: {audioPath} (browser Wasm filesystem)</Typography>}
            </Stack>,
          )}

          {panel(
            'stream',
            <Stack className="screen-stack">
              <Card className="workflow-card" variant="outlined">
                <CardContent sx={{p: '0 !important'}}>
                  <Typography variant="subtitle1">Remote Stream Recording</Typography>
                  <Typography variant="body2" className="card-description">
                    Record an HTTP(S) stream to a virtual file in the browser runtime.
                  </Typography>
                  <TextField
                    className="stream-url-field"
                    fullWidth
                    size="small"
                    label="Remote stream URL"
                    value={streamUrl}
                    onChange={(event) => setStreamUrl(event.target.value)}
                    inputProps={{'aria-label': 'Remote stream URL'}}
                  />
                  <Alert severity="info" sx={{mt: 1, py: 0}}>
                    Browser CORS and the configured FFmpeg protocols can block remote input. Output stays in Wasm memory; no OS file is saved.
                  </Alert>
                  <Box className="stream-action-row">
                    <ActionButton
                      label="Record Stream"
                      icon={<CloudUploadRounded />}
                      onClick={() => void startStream()}
                      disabled={runtimeState !== 'ready' || !streamUrl.trim() || activeStreamJobs.length > 0 || busyActions['record-stream']}
                    />
                  </Box>
                </CardContent>
              </Card>

              <Card className="workflow-card" variant="outlined">
                <CardContent sx={{p: '0 !important'}}>
                  <Box className="card-heading-row">
                    <Box>
                      <Typography variant="subtitle1">Currently Running Sessions</Typography>
                      <Typography variant="caption" color="text.secondary">Sessions: {activeStreamJobs.length}</Typography>
                    </Box>
                    <Tooltip title="Read the current state of tracked stream sessions">
                      <IconButton aria-label="Refresh running sessions" onClick={refreshStreams}>
                        <RefreshRounded />
                      </IconButton>
                    </Tooltip>
                  </Box>
                  {activeStreamJobs.length === 0 ? (
                    <Typography variant="body2" sx={{mt: 1}}>No active streaming jobs.</Typography>
                  ) : (
                    <Box className="active-session-list">
                      {activeStreamJobs.map((job) => (
                        <Box className="active-session-row" key={job.id}>
                          <Box className="session-details">
                            <Typography variant="body2">{job.label} · session {job.id}</Typography>
                            <Typography variant="caption" color="text.secondary">
                              {job.statistics
                                ? `Frame ${job.statistics.videoFrameNumber} · ${job.statistics.speed.toFixed(2)}× · ${formatBytes(job.statistics.size)}`
                                : `State ${SessionState[job.session.getState()] ?? 'Unknown'}`}
                            </Typography>
                          </Box>
                          <Button size="small" color="error" onClick={() => void cancelStream(job)}>Cancel</Button>
                        </Box>
                      ))}
                    </Box>
                  )}
                </CardContent>
              </Card>
            </Stack>,
          )}

          {panel(
            'ffprobe',
            <Stack className="screen-stack">
              <Box className="quick-actions">
                <Tooltip title="Browser File objects are not exposed to the FFmpeg Wasm filesystem by this public SDK.">
                  <span>
                    <ActionButton label="Pick File" icon={<FileOpenRounded />} onClick={() => undefined} disabled title="Browser file import into the Wasm filesystem is not available." />
                  </span>
                </Tooltip>
                <ActionButton label="Get Media Info" icon={<InfoOutlined />} onClick={() => void runMediaInfo()} disabled={runtimeState !== 'ready' || !capabilities.video || busyActions['get-media-info']} title={capabilities.video ? 'Generate the example video if needed, then read its FFprobe metadata.' : capabilities.detail} />
                <ActionButton label="Async Version" icon={<PlayArrowRounded />} onClick={() => void getFFprobeVersion(false)} disabled={runtimeState !== 'ready' || busyActions['ffprobe-version-async']} title="Start an asynchronous FFprobe session." />
                <ActionButton label="Sync Version" icon={<TimerRounded />} onClick={() => void getFFprobeVersion(true)} disabled={runtimeState !== 'ready' || busyActions['ffprobe-version-awaited']} title="Await the Web Promise; JavaScript remains responsive." />
              </Box>
              {!capabilities.video && <Alert severity="info">Media information uses a generated video because browser file import is unavailable. {capabilities.detail}</Alert>}
              <CommandRow
                label="Custom Command:"
                value={ffprobeCommand}
                onChange={setFFprobeCommand}
                onRun={() => void runFFprobeCommand()}
                runLabel="Run FFprobe"
                disabled={runtimeState !== 'ready' || busyActions['run-ffprobe-command']}
              />
              {mediaInfoText && (
                <Paper variant="outlined" sx={{p: 1.25, bgcolor: 'background.paper'}}>
                  <Typography variant="subtitle2">Generated Media Information</Typography>
                  <pre className="metadata-output">{mediaInfoText}</pre>
                </Paper>
              )}
            </Stack>,
          )}

          {panel(
            'ffplay',
            <Stack className="screen-stack ffplay-screen">
              <Box className="ffplay-video-host" ref={videoHostRef} aria-label="FFplay video surface">
                <FFplayView style={{width: '100%', height: '100%', backgroundColor: '#000'}} />
                <Tooltip title={fullscreenSupported ? 'Fullscreen video' : 'Fullscreen is unavailable in this browser context.'}>
                  <span>
                    <IconButton className="fullscreen-button" aria-label="Fullscreen video" disabled={!fullscreenSupported} onClick={() => void toggleFullscreen()}>
                      <FullscreenRounded />
                    </IconButton>
                  </span>
                </Tooltip>
              </Box>

              <CommandRow
                label="Custom Command:"
                value={ffplayCommand}
                onChange={setFFplayCommand}
                onRun={() => void runCustomPlayback()}
                runLabel="Run FFplay"
                disabled={runtimeState !== 'ready' || Boolean(player) || busyActions['run-ffplay-command']}
              />

              <Box>
                <Typography variant="caption" fontWeight={700}>1. Generate Media:</Typography>
                <Box className="quick-actions">
                  <ActionButton label="Gen Video" icon={<MovieCreationRounded />} onClick={() => void generateVideo()} disabled={!capabilities.video || runtimeState !== 'ready' || busyActions['generate-video']} />
                  <ActionButton label="Gen Audio" icon={<MusicNoteRounded />} onClick={() => void generateAudio()} disabled={!capabilities.audio || runtimeState !== 'ready' || busyActions['generate-audio']} />
                </Box>
              </Box>

              <Box>
                <Typography variant="caption" fontWeight={700}>2. Play Generated:</Typography>
                <Box className="quick-actions">
                  <ActionButton label="Play Video" icon={<PlayCircleOutlineRounded />} onClick={() => void playGeneratedVideo()} disabled={!capabilities.video || runtimeState !== 'ready' || Boolean(player) || busyActions['play-generated-video']} />
                  <ActionButton label="Play Audio" icon={<AudioFileRounded />} onClick={() => void playGeneratedAudio()} disabled={!capabilities.audio || runtimeState !== 'ready' || Boolean(player) || busyActions['play-generated-audio']} />
                </Box>
              </Box>

              <Box>
                <Typography variant="caption" fontWeight={700}>Controls:</Typography>
                <Box className="ffplay-control-row">
                  <Tooltip title="Pause">
                    <span><IconButton aria-label="Pause" disabled={!player || !playback.playing} onClick={() => void controlPlayback('pause', (session) => session.pause())}><PauseRounded /></IconButton></span>
                  </Tooltip>
                  <Tooltip title="Resume">
                    <span><IconButton aria-label="Resume" disabled={!player || !playback.paused} onClick={() => void controlPlayback('resume', (session) => session.resume())}><PlayArrowRounded /></IconButton></span>
                  </Tooltip>
                  <Tooltip title="Stop">
                    <span><IconButton aria-label="Stop" disabled={!player} onClick={() => void controlPlayback('stop', (session) => session.stop())}><StopRounded /></IconButton></span>
                  </Tooltip>
                  <Tooltip title="Seek forward 5 seconds">
                    <span><IconButton aria-label="Seek forward 5 seconds" disabled={!player || playback.duration <= 0} onClick={() => void seekTo(Math.min(playback.duration, playback.position + 5))}><FastForwardRounded /></IconButton></span>
                  </Tooltip>
                  <Tooltip title="Seek backward 5 seconds">
                    <span><IconButton aria-label="Seek backward 5 seconds" disabled={!player || playback.duration <= 0} onClick={() => void seekTo(Math.max(0, playback.position - 5))}><FastRewindRounded /></IconButton></span>
                  </Tooltip>
                  <Typography className="ffplay-state" variant="body2">
                    State: {player ? playback.paused ? 'Paused' : playback.playing ? 'Playing' : 'Starting' : 'Idle'}
                    {' · '}{formatTime(playback.position)} / {playback.duration > 0 ? formatTime(playback.duration) : 'unknown'}
                  </Typography>
                </Box>
                <Box className="ffplay-position-row">
                  <Typography variant="caption">{formatTime(playback.position)}</Typography>
                  <Slider
                    size="small"
                    min={0}
                    max={Math.max(playback.duration, 1)}
                    value={Math.min(playback.position, Math.max(playback.duration, 1))}
                    disabled={!player || playback.duration <= 0}
                    aria-label="Playback position"
                    onChangeCommitted={(_, value) => {
                      if (typeof value === 'number') void seekTo(value);
                    }}
                  />
                  <Typography variant="caption">{playback.duration > 0 ? formatTime(playback.duration) : '--:--'}</Typography>
                </Box>
              </Box>

              <Box>
                <Typography variant="caption" fontWeight={700}>Volume:</Typography>
                <Box className="ffplay-volume-row">
                  <IconButton aria-label={playback.volume > 0 ? 'Mute' : 'Unmute'} disabled={!player} onClick={toggleMute}>
                    {playback.volume > 0 ? <VolumeUpRounded /> : <VolumeOffRounded />}
                  </IconButton>
                  <Slider
                    size="small"
                    min={0}
                    max={1}
                    step={0.01}
                    value={playback.volume}
                    disabled={!player}
                    aria-label="Playback volume"
                    onChangeCommitted={(_, value) => {
                      if (typeof value === 'number') void setPlayerVolume(value);
                    }}
                  />
                  <Typography variant="caption" sx={{minWidth: 36, textAlign: 'right'}}>{Math.round(playback.volume * 100)}%</Typography>
                </Box>
              </Box>
            </Stack>,
          )}

          {panel(
            'transcode',
            <Stack className="screen-stack">
              <Box>
                <Typography variant="h6">Video Transcode (MP4 → AVI)</Typography>
                <Typography variant="body2" color="text.secondary">
                  Convert the generated browser-runtime MP4 to AVI and show real FFmpeg progress when the bundle reports it.
                </Typography>
              </Box>
              <Box className="transcode-grid">
                <Card className="workflow-card" variant="outlined">
                  <CardContent sx={{p: '0 !important'}}>
                    <Typography variant="subtitle1">Input File</Typography>
                    <Typography variant="body2" color="text.secondary" sx={{mt: 0.5}}>
                      {videoPath ? videoPath : 'No file selected; the generated test video will be used.'}
                    </Typography>
                    <Tooltip title="A browser File object cannot be imported into the Wasm filesystem through this public API.">
                      <span>
                        <Button variant="text" size="small" startIcon={<FileOpenRounded />} disabled sx={{mt: 1}}>
                          Pick Video File
                        </Button>
                      </span>
                    </Tooltip>
                    <Typography variant="caption" display="block" color="text.secondary" sx={{mt: 0.5}}>
                      Generate an MP4 in the browser filesystem, or use the existing generated file.
                    </Typography>
                  </CardContent>
                </Card>
                <Card className="workflow-card" variant="outlined">
                  <CardContent sx={{p: '0 !important'}}>
                    <Typography variant="subtitle1">About Transcoding</Typography>
                    <ul className="about-list">
                      <li>Input: generated eight-second MP4 test video.</li>
                      <li>Output: {TRANSCODE_PATH} in Wasm memory.</li>
                      <li>Progress, elapsed time, speed and frame count come from FFmpeg statistics callbacks.</li>
                      <li>The public Web SDK does not expose a browser download for this virtual file.</li>
                    </ul>
                  </CardContent>
                </Card>
              </Box>
              <ActionButton
                label="Transcode MP4 → AVI"
                icon={<TransformRounded />}
                onClick={() => void runTranscode()}
                disabled={runtimeState !== 'ready' || !capabilities.transcode || busyActions['transcode-video']}
                title={capabilities.transcode ? 'Transcode the generated MP4 to an AVI virtual path.' : capabilities.detail}
              />
              {transcodeJob && (
                <Paper variant="outlined" sx={{p: 1.25, bgcolor: 'background.paper'}}>
                  <Box className="card-heading-row">
                    <Typography variant="subtitle2">Transcoding</Typography>
                    <Typography variant="caption" color="text.secondary">
                      {transcodeProgress ? `${transcodeProgress.speed.toFixed(2)}× · frame ${transcodeProgress.videoFrameNumber}` : 'Waiting for statistics'}
                    </Typography>
                  </Box>
                  <LinearProgress
                    variant={transcodeProgress ? 'determinate' : 'indeterminate'}
                    value={transcodeProgress ? Math.max(0, Math.min(100, (transcodeProgress.time / 8000) * 100)) : undefined}
                    sx={{mt: 1}}
                  />
                  <Typography variant="caption" color="text.secondary" sx={{mt: 0.75, display: 'block'}}>
                    {transcodeProgress
                      ? `Elapsed ${Math.max(0, transcodeProgress.timeElapsed / 1000).toFixed(1)} s · media ${formatTime(transcodeProgress.time / 1000)} · ${formatBytes(transcodeProgress.size)}`
                      : 'Progress will appear when the Web runtime emits statistics.'}
                  </Typography>
                </Paper>
              )}
              {!capabilities.transcode && <Alert severity="info">Transcoding is disabled because required runtime codecs or muxers are unavailable. {capabilities.detail}</Alert>}
              {videoPath && <Typography variant="caption" color="text.secondary">Input: {videoPath}</Typography>}
            </Stack>,
          )}
        </Box>

        <Paper className="log-pane" square elevation={0}>
          <Box className="log-toolbar">
            <Box sx={{display: 'flex', alignItems: 'center', gap: 1}}>
              <Typography variant="caption" fontWeight={700}>Logs</Typography>
              <Chip size="small" variant="outlined" label={selectedLogName} />
              {activeJobs.length > 0 && <Chip size="small" color="primary" variant="outlined" label={`${activeJobs.length} running`} />}
            </Box>
            <Typography variant="caption" color="text.secondary">Recent output · {Math.min(logs.length, MAX_LOG_LENGTH).toLocaleString()} chars</Typography>
          </Box>
          <Box
            className="log-scroll"
            ref={logScrollRef}
            onScroll={(event) => {
              const element = event.currentTarget;
              shouldAutoScrollRef.current = element.scrollHeight - element.scrollTop - element.clientHeight < 28;
            }}
            role="log"
            aria-label="FFmpeg output log"
            aria-live="polite"
          >
            <pre className={`log-output ${logs ? '' : 'log-placeholder'}`} data-testid="output">
              {logs || 'FFmpeg and FFprobe output will appear here.'}
            </pre>
          </Box>
        </Paper>
      </Box>

      <Menu anchorEl={logMenuAnchor} open={Boolean(logMenuAnchor)} onClose={() => setLogMenuAnchor(null)}>
        {LOG_LEVELS.map(({name, level}) => (
          <MenuItem key={name} selected={selectedLogLevel === level} onClick={() => setLogLevel(level)}>
            {selectedLogLevel === level ? <CheckCircleRounded fontSize="small" sx={{mr: 1}} /> : <Box sx={{width: 24}} />}
            {name}
          </MenuItem>
        ))}
      </Menu>

      <Menu
        anchorEl={systemMenuAnchor}
        open={Boolean(systemMenuAnchor)}
        onClose={() => setSystemMenuAnchor(null)}
        slotProps={{paper: {sx: {maxHeight: 'min(75vh, 620px)'}}}}
      >
        {systemInfoActions.map((action) => (
          <MenuItem key={action.label} onClick={() => showSystemInfo(action.label, action.read)}>
            {action.label}
          </MenuItem>
        ))}
      </Menu>
    </Box>
  );
}
