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
  DownloadRounded,
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
import {FFmpegKitWebFiles} from 'ffmpeg-kit-extended/web-files';
import {
  advanceTranscodeProgressPercent,
  readDurationSeconds,
  shouldRetainImportedPath,
  withImportedPathReservation,
} from './runtime-helpers.mjs';

const TEST_FRAME_SOURCE =
  'color=c=red:size=512x512:rate=30:duration=2[red];' +
  'color=c=green:size=512x512:rate=30:duration=2[green];' +
  'color=c=blue:size=512x512:rate=30:duration=2[blue];' +
  'color=c=white:size=512x512:rate=30:duration=2[white];' +
  '[red][green][blue][white]concat=n=4:v=1:a=0';

const VIDEO_PATH = '/tmp/ffmpeg-kit-web-test.mp4';
const AUDIO_PATH = '/tmp/ffmpeg-kit-web-test.wav';
const TRANSCODE_PATH = '/tmp/ffmpeg-kit-web-output.avi';
const WEB_REMOTE_RECORDING_PREFIX = '/tmp/web-remote-recording-';
const MAX_LOG_LENGTH = 50_000;

type TabId = 'ffmpeg' | 'stream' | 'ffprobe' | 'ffplay' | 'transcode';
type JobKind = 'ffmpeg' | 'stream' | 'ffprobe' | 'playback' | 'transcode';

type ActiveJob = {
  id: number;
  label: string;
  kind: JobKind;
  session: Session;
  inputPath?: string;
  statistics?: Statistics;
};

type ImportedMedia = {
  name: string;
  size: number;
  path: string;
};

type CommandInputTarget = 'ffmpeg' | 'ffplay';

type RuntimeCapabilities = {
  video: boolean;
  audio: boolean;
  transcode: boolean;
  detail: string;
};

type WebRemoteState = 'idle' | 'loading' | 'playing' | 'recording' | 'completed' | 'cancelled' | 'failed';

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

/** ABI of the Phase 2 Web bundle that supports direct HTTP(S) input. */
const WEB_REMOTE_ABI_VERSION = '0.11.2';

/** Returns a finite validation message, or undefined for a direct URL. */
function validateWebRemoteUrl(raw: string): string | undefined {
  const url = raw.trim();
  const match = /^([a-z][a-z0-9+.-]*):\/\/([^/?#\s]+)/i.exec(url);
  if (!match) return 'Enter a direct http:// or https:// URL.';
  const scheme = match[1].toLowerCase();
  if (scheme !== 'http' && scheme !== 'https') {
    return 'Only direct http:// and https:// URLs run on Web. RTMP, RTSP, file and chained schemes such as hls+https:// are not supported.';
  }
  if (/[\s"]/.test(url)) return 'The URL must not contain spaces or double quotes.';
  return undefined;
}

/** Maps captured FFmpeg output to a short, honest failure reason. */
function diagnoseWebRemoteFailure(output: string): string {
  const text = output.toLowerCase();
  if (text.includes('eperm') || text.includes('operation not permitted') || text.includes('pthread')) {
    return 'The Web runtime could not open this network input (EPERM). Check that the URL is a direct media URL. Remote segments listed in a local playlist fail the same way.';
  }
  if (text.includes('403')) return 'The server refused the request (HTTP 403).';
  if (text.includes('404')) return 'The media was not found (HTTP 404).';
  if (text.includes('cors') || text.includes('failed to fetch') || text.includes('cross-origin')) {
    return "The browser blocked the request (CORS). The server must allow this page's origin and expose Content-Range.";
  }
  return 'The command failed. See the output below.';
}

function readRuntimeAbiVersion(): string | undefined {
  try {
    return FFmpegKitExtended.getVersion();
  } catch {
    return undefined;
  }
}

function withInputFile(command: string, path: string): string {
  const inputPattern = /(^|\s)-i(?=\s|$)(?:\s+(?:"(?:\\.|[^"])*"|'(?:\\.|[^'])*'|[^\s]+))?/;
  const match = inputPattern.exec(command);
  const inputArgument = `-i ${quoteCommandArg(path)}`;
  if (match) {
    return `${command.slice(0, match.index)}${match[1]}${inputArgument}${command.slice(match.index + match[0].length)}`;
  }

  const appendBase = command.replace(/(^|\s)-version(?=\s|$)/, '$1').trim();
  return `${appendBase}${appendBase ? ' ' : ''}${inputArgument}`;
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
  onPickFile,
  pickFileLabel,
  pickDisabled = false,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  onRun: () => void;
  runLabel: string;
  disabled?: boolean;
  onPickFile?: () => void;
  pickFileLabel?: string;
  pickDisabled?: boolean;
}): React.JSX.Element {
  return (
    <Box className={`command-row${onPickFile ? ' command-row-with-picker' : ''}`}>
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
      {onPickFile && (
        <Button
          variant="text"
          color="primary"
          startIcon={<FileOpenRounded />}
          disabled={pickDisabled}
          onClick={onPickFile}
          aria-label={pickFileLabel ?? 'Pick input file'}
        >
          Pick File
        </Button>
      )}
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
  const [fileApiReady, setFileApiReady] = useState(false);
  const [fileApiError, setFileApiError] = useState<string>();
  const [videoPath, setVideoPath] = useState<string>();
  const [audioPath, setAudioPath] = useState<string>();
  const [selectedMedia, setSelectedMedia] = useState<ImportedMedia>();
  const [transcodeReady, setTranscodeReady] = useState(false);
  const [webRemoteState, setWebRemoteState] = useState<WebRemoteState>('idle');
  const [webRemoteDetail, setWebRemoteDetail] = useState('');
  const [webRemoteRecordingPath, setWebRemoteRecordingPath] = useState<string | undefined>(undefined);
  const webRemoteCancelRef = useRef<(() => void) | undefined>(undefined);
  const webRemoteCancelRequestedRef = useRef(false);
  const webRemoteRecordingCounterRef = useRef(0);
  const [ffmpegCommand, setFFmpegCommand] = useState('-nostdin -version');
  const [ffprobeCommand, setFFprobeCommand] = useState('-version');
  const [ffplayCommand, setFFplayCommand] = useState(`-hide_banner -i ${VIDEO_PATH} -autoexit`);
  const [streamUrl, setStreamUrl] = useState('https://endpnt.com/hls/nasa4k/playlist.m3u8');
  const [mediaInfoText, setMediaInfoText] = useState('');
  const [transcodeStats, setTranscodeStats] = useState<Statistics>();
  const [transcodeDurationSeconds, setTranscodeDurationSeconds] = useState<number>();
  const [transcodeProgressPercent, setTranscodeProgressPercent] = useState<number>();
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
  const fileInputRef = useRef<HTMLInputElement>(null);
  const pendingCommandInputRef = useRef<CommandInputTarget | undefined>(undefined);
  const playerRef = useRef<FFplaySession | undefined>(undefined);
  const selectedMediaRef = useRef<ImportedMedia | undefined>(undefined);
  const importedPathsRef = useRef(new Set<string>());
  const mediaInfoPathCountsRef = useRef(new Map<string, number>());
  const previousVolumeRef = useRef(1);
  const queuedLogsRef = useRef('');
  const logTimerRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const shouldAutoScrollRef = useRef(true);
  const videoGenerationRef = useRef<Promise<string> | undefined>(undefined);
  const audioGenerationRef = useRef<Promise<string> | undefined>(undefined);
  const transcodeProgressRunRef = useRef(0);

  const openMediaPicker = (target?: CommandInputTarget) => {
    pendingCommandInputRef.current = target;
    fileInputRef.current?.click();
  };

  const retainMediaInfoPath = (path: string) => {
    const current = mediaInfoPathCountsRef.current.get(path) ?? 0;
    mediaInfoPathCountsRef.current.set(path, current + 1);
  };

  const releaseMediaInfoPath = (path: string) => {
    const current = mediaInfoPathCountsRef.current.get(path) ?? 0;
    if (current <= 1) mediaInfoPathCountsRef.current.delete(path);
    else mediaInfoPathCountsRef.current.set(path, current - 1);
  };

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

  const cleanupImportedFile = useCallback((path: string) => {
    if (shouldRetainImportedPath(path, {
      selectedPath: selectedMediaRef.current?.path,
      hasMediaInfoRead: mediaInfoPathCountsRef.current.has(path),
      hasActiveJobs: jobsRef.current.size > 0,
    })) {
      return;
    }
    if (!importedPathsRef.current.has(path)) return;
    try {
      if (FFmpegKitWebFiles.exists(path)) FFmpegKitWebFiles.deleteFile(path);
      importedPathsRef.current.delete(path);
      appendLog(`Removed unused imported media from the Wasm filesystem: ${path}.`);
    } catch (error) {
      appendLog(`Could not remove unused imported media ${path}: ${errorMessage(error)}`);
    }
  }, [appendLog]);

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
    for (const path of importedPathsRef.current) cleanupImportedFile(path);
  }, [cleanupImportedFile]);

  const trackSession = useCallback(
    function trackSession<T extends Session>(
      session: T,
      label: string,
      kind: JobKind,
      start: () => Promise<T>,
      inputPath?: string,
    ): Promise<T> {
      const id = session.getSessionId();
      updateJob({id, label, kind, session, inputPath});
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
      inputPath?: string,
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
        inputPath,
      ).then((completed) => {
        appendLog(`${label} callback counts: log=${logCount}, statistics=${statisticsCount}.`);
        return completed;
      });
    },
    [appendLog, jobsRef, trackSession, updateJob],
  );

  const runFFprobe = useCallback(
    (label: string, command: string, inputPath?: string): Promise<Session> => {
      const session = FFprobeKit.createSession(command);
      appendLog(`$ ffprobe ${command}`);
      return trackSession(session, label, 'ffprobe', () =>
        session.executeAsync({logCallback: (log) => appendLog(log.message)}),
        inputPath,
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

  const importMedia = (file: File, commandTarget?: CommandInputTarget) =>
    runUiAction('import-media', async () => {
      if (!fileApiReady) {
        throw new Error(fileApiError ?? 'The initialized Web runtime does not have a usable exported FS API.');
      }
      const random = new Uint32Array(4);
      if (typeof globalThis.crypto?.getRandomValues !== 'function') {
        throw new Error('This browser cannot create a collision-resistant temporary media path.');
      }
      globalThis.crypto.getRandomValues(random);
      const token = Array.from(random, (value) => value.toString(16).padStart(8, '0')).join('');
      const dot = file.name.lastIndexOf('.');
      const candidateExtension = dot >= 0 ? file.name.slice(dot + 1) : '';
      const extension = /^[a-z0-9]{1,12}$/i.test(candidateExtension)
        ? `.${candidateExtension.toLowerCase()}`
        : '';
      const path = `/tmp/ffmpeg-kit-web-import-${token}${extension}`;
      const bytes = new Uint8Array(await file.arrayBuffer());
      FFmpegKitWebFiles.writeFile(path, bytes);
      const imported = {name: file.name, size: bytes.byteLength, path};
      const previous = selectedMediaRef.current;
      importedPathsRef.current.add(path);
      selectedMediaRef.current = imported;
      setSelectedMedia(imported);
      if (commandTarget === 'ffmpeg') {
        setFFmpegCommand((command) => withInputFile(command, path));
      } else if (commandTarget === 'ffplay') {
        setFFplayCommand((command) => withInputFile(command, path));
      }
      if (previous) cleanupImportedFile(previous.path);
      appendLog(`Imported ${file.name} (${formatBytes(bytes.byteLength)}) to ${path}.`);
      setStatus(`Imported ${file.name} to the Wasm filesystem`);
    });

  const downloadFile = (label: string, path: string, filename: string, mimeType: string) =>
    runUiAction(`download-${label}`, () => {
      if (!fileApiReady) {
        throw new Error(fileApiError ?? 'The initialized Web runtime does not have a usable exported FS API.');
      }
      if (!FFmpegKitWebFiles.exists(path)) throw new Error(`The Wasm file is missing: ${path}`);
      const bytes = FFmpegKitWebFiles.readFile(path);
      if (typeof document === 'undefined' || typeof URL.createObjectURL !== 'function') {
        throw new Error('This browser does not support downloading local Wasm files.');
      }
      const blob = new Blob([bytes.slice().buffer as ArrayBuffer], {type: mimeType});
      const objectUrl = URL.createObjectURL(blob);
      const anchor = document.createElement('a');
      anchor.href = objectUrl;
      anchor.download = filename;
      let dispatched = false;
      try {
        document.body.appendChild(anchor);
        anchor.click();
        dispatched = true;
        window.setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);
        appendLog(`Browser download started for ${filename} (${formatBytes(bytes.byteLength)}).`);
        setStatus(`Download started: ${filename}`);
      } finally {
        anchor.remove();
        if (!dispatched) URL.revokeObjectURL(objectUrl);
      }
    });

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

  const checkFileApi = useCallback((): boolean => {
    try {
      // `exists` validates the complete exported FS surface without writing a file.
      FFmpegKitWebFiles.exists(VIDEO_PATH);
      setFileApiReady(true);
      setFileApiError(undefined);
      return true;
    } catch (error) {
      const message = errorMessage(error);
      setFileApiReady(false);
      setFileApiError(message);
      appendLog(`Local Web file operations are unavailable: ${message}`);
      return false;
    }
  }, [appendLog]);

  const initializeRuntime = useCallback(async () => {
    if (FFmpegKitExtended.initialized) {
      setRuntimeState('ready');
      setRuntimeError(undefined);
      readRuntimeCapabilities();
      checkFileApi();
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
      readRuntimeCapabilities();
      checkFileApi();
      setRuntimeState('ready');
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
  }, [appendLog, checkFileApi, readRuntimeCapabilities]);

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
    if (!fileApiReady) {
      throw new Error(fileApiError ?? 'The initialized Web runtime does not have a usable exported FS API.');
    }
    if (videoPath) return videoPath;
    if (!capabilities.video) throw new Error(capabilities.detail);
    if (!videoGenerationRef.current) {
      videoGenerationRef.current = (async () => {
        const command =
          `-hide_banner -nostdin -loglevel info -f lavfi -i ${quoteCommandArg(TEST_FRAME_SOURCE)} ` +
          `-f lavfi -i ${quoteCommandArg('sine=frequency=440:sample_rate=44100:duration=8')} ` +
          `-t 8 -map 0:v:0 -map 1:a:0 -c:v mpeg4 -c:a aac -b:a 128k -shortest -f mp4 -y ${quoteCommandArg(VIDEO_PATH)}`;
        const session = await runFFmpeg('Generate test video', command);
        if (session.getReturnCode() !== ReturnCode.Success) {
          throw new Error(`Video generation returned code ${session.getReturnCode()}.`);
        }
        if (!FFmpegKitWebFiles.exists(VIDEO_PATH)) throw new Error('FFmpeg completed without creating the MP4 file.');
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
  }, [appendLog, capabilities, fileApiError, fileApiReady, runFFmpeg, videoPath]);

  const ensureAudio = useCallback(async (): Promise<string> => {
    if (!fileApiReady) {
      throw new Error(fileApiError ?? 'The initialized Web runtime does not have a usable exported FS API.');
    }
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
        if (!FFmpegKitWebFiles.exists(AUDIO_PATH)) throw new Error('FFmpeg completed without creating the WAV file.');
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
  }, [appendLog, audioPath, capabilities, fileApiError, fileApiReady, runFFmpeg]);

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
    async (
      label: string,
      command: string,
      inputPath?: string,
      onTerminal?: (completed: Session | undefined, error?: unknown) => void,
    ) => {
      if (!FFmpegKitExtended.initialized) throw new Error('Initialize the Web runtime before starting playback.');
      if (playerRef.current) throw new Error('Stop the current FFplay session before starting another.');
      const session = FFplayKit.createSession(command);
      playerRef.current = session;
      setPlayer(session);
      setPlayback(initialPlayback);
      appendLog(`$ ffplay ${command}`);
      const completion = trackSession(session, label, 'playback', () =>
        session.executeAsync({logCallback: (log) => appendLog(log.message)}),
        inputPath,
      );
      void completion
        .then((completed) => {
          const code = completed.getReturnCode();
          if (code !== ReturnCode.Success) setLastError(`FFplay returned code ${code}.`);
          onTerminal?.(completed);
        })
        .catch((error: unknown) => {
          onTerminal?.(undefined, error);
        })
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

  const playImportedMedia = () =>
    runUiAction('play-imported-media', async () => {
      if (!fileApiReady) {
        throw new Error(fileApiError ?? 'The initialized Web runtime does not have a usable exported FS API.');
      }
      const imported = selectedMediaRef.current;
      if (!imported) throw new Error('Pick a media file before starting imported playback.');
      if (!FFmpegKitWebFiles.exists(imported.path)) throw new Error(`The imported file is missing: ${imported.path}`);
      const command = `-hide_banner -loglevel info -i ${quoteCommandArg(imported.path)} -autoexit`;
      await launchPlayback(`Play ${imported.name}`, command, imported.path);
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
      if (!fileApiReady) {
        throw new Error(fileApiError ?? 'The initialized Web runtime does not have a usable exported FS API.');
      }
      const imported = selectedMediaRef.current;
      const path = imported?.path ?? await ensureVideo();
      if (imported) retainMediaInfoPath(path);
      appendLog(`$ ffprobe media information ${quoteCommandArg(path)}`);
      try {
        const session = await FFprobeKit.getMediaInformation(path);
        if (session.getReturnCode() !== ReturnCode.Success) {
          throw new Error(session.getOutput() || `FFprobe returned code ${session.getReturnCode()}.`);
        }
        const information = session.getMediaInformation();
        if (!information) throw new Error(session.getOutput() || 'FFprobe returned no media information.');
        const rendered = JSON.stringify(information, null, 2);
        setMediaInfoText(rendered);
        appendLog(`Media information for ${path}:\n${rendered}`);
        setStatus(`Media info: ${information.streams?.length ?? 0} stream(s)`);
      } finally {
        if (imported) releaseMediaInfoPath(path);
        cleanupImportedFile(path);
      }
    });

  // --- Web remote URL: direct HTTP(S) input through the async APIs only ---

  const webRemoteValidation = validateWebRemoteUrl(streamUrl);
  const webRemoteBusy =
    webRemoteState === 'loading' || webRemoteState === 'playing' || webRemoteState === 'recording';
  const webRemoteAbi = runtimeState === 'ready' ? readRuntimeAbiVersion() : undefined;
  const webRemoteSupported = webRemoteAbi === WEB_REMOTE_ABI_VERSION;
  const canStartWebRemote =
    runtimeState === 'ready' && webRemoteSupported && !webRemoteBusy && !webRemoteValidation;

  const setWebRemote = (state: WebRemoteState, detail = '') => {
    setWebRemoteState(state);
    setWebRemoteDetail(detail);
  };

  const runWebRemoteFFprobe = (label: string, command: string) => {
    webRemoteCancelRequestedRef.current = false;
    setWebRemote('loading', label);
    // The cancel action is registered before waiting, so Stop works during the probe.
    const session = FFprobeKit.createSession(command);
    appendLog(`$ ffprobe ${command}`);
    webRemoteCancelRef.current = () => void session.cancel();
    void trackSession(session, label, 'ffprobe', () =>
      session.executeAsync({logCallback: (log) => appendLog(log.message)}),
    )
      .then((completed) => {
        webRemoteCancelRef.current = undefined;
        const output = completed.getOutput();
        if (webRemoteCancelRequestedRef.current) setWebRemote('cancelled', 'Probe cancelled.');
        else if (completed.getReturnCode() === ReturnCode.Success) setWebRemote('completed', output);
        else setWebRemote('failed', `${diagnoseWebRemoteFailure(output)}\n\n${output}`);
      })
      .catch((error: unknown) => {
        webRemoteCancelRef.current = undefined;
        setWebRemote('failed', errorMessage(error));
      });
  };

  const runWebRemoteProbe = () => {
    const url = streamUrl.trim();
    if (webRemoteValidation) {
      setWebRemote('failed', webRemoteValidation);
      return;
    }
    runWebRemoteFFprobe(
      `Probing ${url}`,
      `-hide_banner -v error -show_format -show_streams -of json ${quoteCommandArg(url)}`,
    );
  };

  const runWebRemoteProbeRecording = () => {
    const path = webRemoteRecordingPath;
    if (!path) return;
    runWebRemoteFFprobe(
      `Probing ${path}`,
      `-hide_banner -v error -show_format -show_streams -of json ${quoteCommandArg(path)}`,
    );
  };

  const runWebRemotePlay = async () => {
    const url = streamUrl.trim();
    if (webRemoteValidation) {
      setWebRemote('failed', webRemoteValidation);
      return;
    }
    webRemoteCancelRequestedRef.current = false;
    setWebRemote('loading', `Starting playback of ${url}`);
    // The player reference is set synchronously by launchPlayback before its
    // first await, so Stop can request cancellation during startup too.
    webRemoteCancelRef.current = () => void playerRef.current?.stop();
    // Playback can finish before the handoff returns, so the terminal state is
    // recorded first and "playing" is only set when playback is still running.
    const terminal = {done: false};
    try {
      await launchPlayback(
        'Web remote playback',
        `-hide_banner -loglevel info -autoexit -i ${quoteCommandArg(url)}`,
        undefined,
        (completed, error) => {
          terminal.done = true;
          webRemoteCancelRef.current = undefined;
          if (webRemoteCancelRequestedRef.current) setWebRemote('cancelled', 'Playback stopped.');
          else if (error !== undefined) setWebRemote('failed', errorMessage(error));
          else if (completed && completed.getReturnCode() === ReturnCode.Success) {
            setWebRemote('completed', 'Playback reached the end of the media.');
          } else {
            const output = completed?.getOutput() ?? '';
            setWebRemote('failed', `${diagnoseWebRemoteFailure(output)}\n\n${output}`);
          }
        },
      );
      if (!terminal.done && !webRemoteCancelRequestedRef.current) {
        setWebRemote('playing', `Playing ${url}. Video renders in the FFplay tab.`);
      }
    } catch (error) {
      webRemoteCancelRef.current = undefined;
      setWebRemote('failed', errorMessage(error));
    }
  };

  const runWebRemoteRecord = () => {
    const url = streamUrl.trim();
    if (webRemoteValidation) {
      setWebRemote('failed', webRemoteValidation);
      return;
    }
    webRemoteRecordingCounterRef.current += 1;
    if (webRemoteRecordingPath && FFmpegKitWebFiles.exists(webRemoteRecordingPath)) {
      FFmpegKitWebFiles.deleteFile(webRemoteRecordingPath);
    }
    // Recordings live in the Wasm filesystem until the user downloads them.
    const outputPath = `${WEB_REMOTE_RECORDING_PREFIX}${webRemoteRecordingCounterRef.current}.mkv`;
    if (FFmpegKitWebFiles.exists(outputPath)) FFmpegKitWebFiles.deleteFile(outputPath);
    setWebRemoteRecordingPath(undefined);
    webRemoteCancelRequestedRef.current = false;
    setWebRemote('recording', `Recording 15 seconds to ${outputPath}`);
    const command =
      `-hide_banner -nostdin -y -t 15 -i ${quoteCommandArg(url)} ` +
      `-map 0:v:0 -map 0:a:0? -c copy -f matroska ${quoteCommandArg(outputPath)}`;
    const session = FFmpegKit.createSession(command);
    appendLog(`$ ffmpeg ${command}`);
    webRemoteCancelRef.current = () => void session.cancel();
    void trackSession(session, 'Web remote recording', 'stream', () =>
      session.executeAsync({
        logCallback: (log) => appendLog(log.message),
        statisticsCallback: (statistics) => {
          if (webRemoteCancelRequestedRef.current) return;
          const elapsed = Math.max(0, Math.min(15, statistics.time / 1000));
          const percent = Math.floor(elapsed / 15 * 100);
          setWebRemoteDetail(
            `Recording: ${percent}% · ${formatBytes(statistics.size)} · ${elapsed.toFixed(1)} / 15 s media`,
          );
        },
      }),
    )
      .then((completed) => {
        webRemoteCancelRef.current = undefined;
        const output = completed.getOutput();
        const bytes = FFmpegKitWebFiles.exists(outputPath)
          ? FFmpegKitWebFiles.readFile(outputPath).byteLength
          : 0;
        if (webRemoteCancelRequestedRef.current) {
          if (FFmpegKitWebFiles.exists(outputPath)) FFmpegKitWebFiles.deleteFile(outputPath);
          setWebRemote('cancelled', 'Recording cancelled.');
        } else if (completed.getReturnCode() === ReturnCode.Success && bytes > 0) {
          setWebRemoteRecordingPath(outputPath);
          setWebRemote('completed', `Recorded ${bytes} bytes to ${outputPath}. Probe or download it.`);
        } else {
          if (FFmpegKitWebFiles.exists(outputPath)) FFmpegKitWebFiles.deleteFile(outputPath);
          setWebRemote('failed', `${diagnoseWebRemoteFailure(output)}\n\n${output}`);
        }
      })
      .catch((error: unknown) => {
        webRemoteCancelRef.current = undefined;
        if (FFmpegKitWebFiles.exists(outputPath)) FFmpegKitWebFiles.deleteFile(outputPath);
        setWebRemote('failed', errorMessage(error));
      });
  };

  /** Cancels the running Web remote operation once. */
  const cancelWebRemote = () => {
    if (webRemoteCancelRequestedRef.current) return;
    const cancel = webRemoteCancelRef.current;
    if (!cancel) return;
    webRemoteCancelRef.current = undefined;
    webRemoteCancelRequestedRef.current = true;
    cancel();
    // Completion owns the terminal state; another operation cannot start yet.
    setWebRemoteDetail('Cancellation requested; waiting for completion.');
  };

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

  const readTranscodeInputDuration = useCallback(async (path: string): Promise<number | undefined> => {
    retainMediaInfoPath(path);
    try {
      const session = await FFprobeKit.getMediaInformation(path);
      if (session.getReturnCode() !== ReturnCode.Success) {
        appendLog(`Could not probe input duration (return code ${session.getReturnCode()}); progress will be indeterminate.`);
        return undefined;
      }
      const duration = readDurationSeconds(session.getMediaInformation()?.duration);
      if (duration === undefined) {
        appendLog('FFprobe did not report a valid input duration; progress will be indeterminate.');
      } else {
        appendLog(`FFprobe input duration: ${duration} seconds.`);
      }
      return duration;
    } catch (error) {
      appendLog(`Could not probe input duration: ${errorMessage(error)}; progress will be indeterminate.`);
      return undefined;
    } finally {
      releaseMediaInfoPath(path);
      cleanupImportedFile(path);
    }
  }, [appendLog, cleanupImportedFile]);

  const runTranscode = () =>
    runUiAction('transcode-video', async () => {
      const progressRun = ++transcodeProgressRunRef.current;
      setTranscodeReady(false);
      setTranscodeStats(undefined);
      setTranscodeDurationSeconds(undefined);
      setTranscodeProgressPercent(undefined);
      try {
        if (!fileApiReady) {
          throw new Error(fileApiError ?? 'The initialized Web runtime does not have a usable exported FS API.');
        }
        if (!capabilities.transcode) throw new Error(capabilities.detail);
        if (FFmpegKitWebFiles.exists(TRANSCODE_PATH)) FFmpegKitWebFiles.deleteFile(TRANSCODE_PATH);
        const imported = selectedMediaRef.current;
        const path = imported?.path ?? await ensureVideo();
        const transcode = async () => {
          const durationSeconds = imported ? await readTranscodeInputDuration(path) : 8;
          setTranscodeDurationSeconds(durationSeconds);
          setTranscodeProgressPercent(durationSeconds === undefined ? undefined : 0);
          const command =
            `-hide_banner -nostdin -loglevel info -i ${quoteCommandArg(path)} ` +
            `-an -c:v mpeg4 -y ${quoteCommandArg(TRANSCODE_PATH)}`;
          const session = await runFFmpeg(
            'Transcode media to AVI',
            command,
            'transcode',
            (statistics) => {
              if (transcodeProgressRunRef.current !== progressRun) return;
              setTranscodeStats(statistics);
              if (durationSeconds !== undefined) {
                setTranscodeProgressPercent((previous) =>
                  advanceTranscodeProgressPercent(
                    statistics.time,
                    durationSeconds,
                    previous,
                  ) ?? previous,
                );
              }
            },
            path,
          );
          if (session.getReturnCode() !== ReturnCode.Success) {
            throw new Error(`Transcode returned code ${session.getReturnCode()}.`);
          }
          if (!FFmpegKitWebFiles.exists(TRANSCODE_PATH)) throw new Error('FFmpeg completed without creating the AVI file.');
          transcodeProgressRunRef.current += 1;
          setTranscodeReady(true);
          setTranscodeProgressPercent(100);
          setStatus(`Transcode complete at Wasm path ${TRANSCODE_PATH}`);
          appendLog(`Transcode output is ready to download from the browser Wasm filesystem: ${TRANSCODE_PATH}.`);
        };
        if (imported) {
          await withImportedPathReservation(path, {
            retainPath: retainMediaInfoPath,
            releasePath: releaseMediaInfoPath,
            cleanupPath: cleanupImportedFile,
          }, transcode);
        } else {
          await transcode();
        }
      } catch (error) {
        if (transcodeProgressRunRef.current === progressRun) {
          transcodeProgressRunRef.current += 1;
          setTranscodeDurationSeconds(undefined);
          setTranscodeProgressPercent(undefined);
        }
        throw error;
      }
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
      {runtimeState === 'ready' && fileApiError && (
        <Alert severity="error" className="alert-inline">
          Browser file operations are unavailable: {fileApiError} File import, generated media, playback, download and file transcoding are disabled. Runtime version and introspection actions remain available.
        </Alert>
      )}
      {lastError && !runtimeError && <Alert severity="warning" className="alert-inline">{lastError}</Alert>}
      {children}
    </Box>
  );

  return (
    <Box className="app-shell">
      <input
        ref={fileInputRef}
        type="file"
        accept="video/*,audio/*,application/octet-stream"
        aria-label="Import media file"
        data-testid="import-media-input"
        hidden
        disabled={!fileApiReady || runtimeState !== 'ready'}
        onChange={(event) => {
          const file = event.currentTarget.files?.[0];
          const commandTarget = pendingCommandInputRef.current;
          pendingCommandInputRef.current = undefined;
          event.currentTarget.value = '';
          if (file) void importMedia(file, commandTarget);
        }}
      />
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
                <ActionButton label="Gen Video" icon={<MovieCreationRounded />} onClick={() => void generateVideo()} disabled={!fileApiReady || !capabilities.video || runtimeState !== 'ready' || busyActions['generate-video']} title={fileApiReady && capabilities.video ? 'Create an eight-second four-color MP4 with a generated 440 Hz audio tone in the browser Wasm filesystem.' : fileApiError ?? capabilities.detail} />
                <ActionButton label="Gen Audio" icon={<MusicNoteRounded />} onClick={() => void generateAudio()} disabled={!fileApiReady || !capabilities.audio || runtimeState !== 'ready' || busyActions['generate-audio']} title={fileApiReady && capabilities.audio ? 'Create an eight-second WAV in the browser Wasm filesystem.' : fileApiError ?? capabilities.detail} />
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
                onPickFile={() => openMediaPicker('ffmpeg')}
                pickFileLabel="Pick input file for FFmpeg"
                pickDisabled={!fileApiReady || runtimeState !== 'ready' || busyActions['import-media']}
              />
              <Box className="quick-actions">
                {videoPath && <ActionButton label="Download MP4" icon={<DownloadRounded />} onClick={() => void downloadFile('mp4', VIDEO_PATH, 'ffmpeg-kit-web-test.mp4', 'video/mp4')} disabled={!fileApiReady} />}
                {audioPath && <ActionButton label="Download WAV" icon={<DownloadRounded />} onClick={() => void downloadFile('wav', AUDIO_PATH, 'ffmpeg-kit-web-test.wav', 'audio/wav')} disabled={!fileApiReady} />}
              </Box>
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
                  <Typography variant="subtitle1">Remote URL (Web)</Typography>
                  <Typography variant="body2" className="card-description">
                    Direct http:// and https:// URLs run through the async APIs. Recordings stay in browser memory until you download them. Video renders in the FFplay tab.
                  </Typography>
                  <TextField
                    className="stream-url-field"
                    fullWidth
                    size="small"
                    label="Direct media URL"
                    value={streamUrl}
                    onChange={(event) => setStreamUrl(event.target.value)}
                    disabled={webRemoteBusy}
                    error={Boolean(webRemoteValidation)}
                    helperText={webRemoteValidation}
                    inputProps={{'aria-label': 'Direct media URL'}}
                  />
                  {!webRemoteSupported && (
                    <Alert severity="warning" sx={{mt: 1, py: 0}}>
                      This Web runtime reports ABI {webRemoteAbi ?? 'none'}. Remote URL input needs the Phase 2 bundle (ABI {WEB_REMOTE_ABI_VERSION}).
                    </Alert>
                  )}
                  <Box className="stream-action-row">
                    <ActionButton label="Probe" icon={<InfoOutlined />} onClick={() => runWebRemoteProbe()} disabled={!canStartWebRemote} />
                    <ActionButton label="Play" icon={<PlayArrowRounded />} onClick={() => void runWebRemotePlay()} disabled={!canStartWebRemote} />
                    <ActionButton label="Record 15 s" icon={<CloudUploadRounded />} onClick={() => runWebRemoteRecord()} disabled={!canStartWebRemote} />
                    <ActionButton label="Stop" icon={<StopRounded />} onClick={() => cancelWebRemote()} disabled={!webRemoteBusy} />
                    <ActionButton label="Probe Recording" icon={<InfoOutlined />} onClick={() => runWebRemoteProbeRecording()} disabled={webRemoteBusy || !webRemoteRecordingPath} />
                    <ActionButton
                      label="Download Recording"
                      icon={<DownloadRounded />}
                      onClick={() => {
                        if (webRemoteRecordingPath) void downloadFile('Web remote recording', webRemoteRecordingPath, 'web-remote-recording.mkv', 'video/x-matroska');
                      }}
                      disabled={webRemoteBusy || !webRemoteRecordingPath}
                    />
                  </Box>
                  <Typography variant="subtitle2" sx={{mt: 1}}>State: {webRemoteState}</Typography>
                  {webRemoteDetail && (
                    <Typography variant="body2" component="pre" sx={{whiteSpace: 'pre-wrap', fontSize: 12}}>{webRemoteDetail}</Typography>
                  )}
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
                <ActionButton label="Pick File" icon={<FileOpenRounded />} onClick={() => openMediaPicker()} disabled={!fileApiReady || runtimeState !== 'ready' || busyActions['import-media']} title={fileApiError ?? 'Copy a local media file into the browser Wasm filesystem.'} />
                <ActionButton label="Get Media Info" icon={<InfoOutlined />} onClick={() => void runMediaInfo()} disabled={!fileApiReady || runtimeState !== 'ready' || (!selectedMedia && !capabilities.video) || busyActions['get-media-info']} title={selectedMedia ? `Read FFprobe metadata from ${selectedMedia.name}.` : 'Generate the example video if needed, then read its FFprobe metadata.'} />
                <ActionButton label="Async Version" icon={<PlayArrowRounded />} onClick={() => void getFFprobeVersion(false)} disabled={runtimeState !== 'ready' || busyActions['ffprobe-version-async']} title="Start an asynchronous FFprobe session." />
                <ActionButton label="Sync Version" icon={<TimerRounded />} onClick={() => void getFFprobeVersion(true)} disabled={runtimeState !== 'ready' || busyActions['ffprobe-version-awaited']} title="Await the Web Promise; JavaScript remains responsive." />
              </Box>
              {selectedMedia && <Alert severity="info">Selected {selectedMedia.name} ({formatBytes(selectedMedia.size)}). Wasm path: {selectedMedia.path}</Alert>}
              {!selectedMedia && !capabilities.video && <Alert severity="info">Media information uses a generated video when the bundle supports it. {capabilities.detail}</Alert>}
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
                  <Typography variant="subtitle2">Media Information</Typography>
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
                onPickFile={() => openMediaPicker('ffplay')}
                pickFileLabel="Pick input file for FFplay"
                pickDisabled={!fileApiReady || runtimeState !== 'ready' || busyActions['import-media']}
              />

              <Box>
                <Typography variant="caption" fontWeight={700}>1. Generate Media:</Typography>
                <Box className="quick-actions">
                  <ActionButton label="Gen Video" icon={<MovieCreationRounded />} onClick={() => void generateVideo()} disabled={!fileApiReady || !capabilities.video || runtimeState !== 'ready' || busyActions['generate-video']} />
                  <ActionButton label="Gen Audio" icon={<MusicNoteRounded />} onClick={() => void generateAudio()} disabled={!fileApiReady || !capabilities.audio || runtimeState !== 'ready' || busyActions['generate-audio']} />
                </Box>
              </Box>

              <Box>
                <Typography variant="caption" fontWeight={700}>2. Play Media:</Typography>
                <Box className="quick-actions">
                  <ActionButton label="Play Video" icon={<PlayCircleOutlineRounded />} onClick={() => void playGeneratedVideo()} disabled={!fileApiReady || !capabilities.video || runtimeState !== 'ready' || Boolean(player) || busyActions['play-generated-video']} />
                  <ActionButton label="Play Audio" icon={<AudioFileRounded />} onClick={() => void playGeneratedAudio()} disabled={!fileApiReady || !capabilities.audio || runtimeState !== 'ready' || Boolean(player) || busyActions['play-generated-audio']} />
                  <ActionButton label="Play Imported File" icon={<PlayCircleOutlineRounded />} onClick={() => void playImportedMedia()} disabled={!fileApiReady || !selectedMedia || runtimeState !== 'ready' || Boolean(player) || busyActions['play-imported-media']} title={selectedMedia ? `Play ${selectedMedia.name} through the FFplay view.` : 'Pick a media file in FFprobe or Transcode first.'} />
                </Box>
                {selectedMedia && <Typography variant="caption" color="text.secondary">Imported file: {selectedMedia.name} ({formatBytes(selectedMedia.size)})</Typography>}
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
                <Typography variant="h6">Video Transcode (to AVI)</Typography>
                <Typography variant="body2" color="text.secondary">
                  Convert the selected media file, or the generated MP4, to AVI and show FFmpeg progress when the bundle reports it.
                </Typography>
              </Box>
              <Box className="transcode-grid">
                <Card className="workflow-card" variant="outlined">
                  <CardContent sx={{p: '0 !important'}}>
                    <Typography variant="subtitle1">Input File</Typography>
                    <Typography variant="body2" color="text.secondary" sx={{mt: 0.5}}>
                      {selectedMedia ? `${selectedMedia.name} (${formatBytes(selectedMedia.size)}) · ${selectedMedia.path}` : videoPath ? videoPath : 'No file selected; the generated test video will be used.'}
                    </Typography>
                    <Button variant="text" size="small" startIcon={<FileOpenRounded />} disabled={!fileApiReady || runtimeState !== 'ready' || busyActions['import-media']} onClick={() => openMediaPicker()} sx={{mt: 1}}>
                      Pick Video File
                    </Button>
                    <Typography variant="caption" display="block" color="text.secondary" sx={{mt: 0.5}}>
                      The selected file is shared with FFprobe and FFplay and stays in temporary Wasm memory.
                    </Typography>
                  </CardContent>
                </Card>
                <Card className="workflow-card" variant="outlined">
                  <CardContent sx={{p: '0 !important'}}>
                    <Typography variant="subtitle1">About Transcoding</Typography>
                    <ul className="about-list">
                      <li>Input: selected media file, or generated eight-second MP4.</li>
                      <li>Output: {TRANSCODE_PATH} in Wasm memory.</li>
                      <li>Progress, elapsed time, speed and frame count come from FFmpeg statistics callbacks.</li>
                      <li>The completed AVI can be downloaded to the browser.</li>
                    </ul>
                  </CardContent>
                </Card>
              </Box>
              <ActionButton
                label="Transcode to AVI"
                icon={<TransformRounded />}
                onClick={() => void runTranscode()}
                disabled={!fileApiReady || runtimeState !== 'ready' || !capabilities.transcode || busyActions['transcode-video']}
                title={!fileApiReady ? fileApiError : capabilities.transcode ? 'Transcode the selected media file or generated MP4 to an AVI file.' : capabilities.detail}
              />
              {transcodeReady && <ActionButton label="Download AVI" icon={<DownloadRounded />} onClick={() => void downloadFile('transcode-avi', TRANSCODE_PATH, 'ffmpeg-kit-web-output.avi', 'video/x-msvideo')} disabled={!fileApiReady} />}
              {(transcodeJob || busyActions['transcode-video'] || transcodeReady) && (
                <Paper variant="outlined" sx={{p: 1.25, bgcolor: 'background.paper'}}>
                  <Box className="card-heading-row">
                    <Typography variant="subtitle2">{transcodeReady ? 'Transcode complete' : 'Transcoding'}</Typography>
                    <Typography variant="caption" color="text.secondary">
                      {transcodeProgress ? `${transcodeProgress.speed.toFixed(2)}× · frame ${transcodeProgress.videoFrameNumber}` : 'Waiting for statistics'}
                    </Typography>
                  </Box>
                  <LinearProgress
                    variant={transcodeProgress && transcodeDurationSeconds !== undefined ? 'determinate' : 'indeterminate'}
                    value={transcodeProgress && transcodeDurationSeconds !== undefined ? transcodeProgressPercent : undefined}
                    sx={{mt: 1}}
                  />
                  <Typography variant="caption" color="text.secondary" sx={{mt: 0.75, display: 'block'}}>
                    {transcodeProgress
                      ? `Elapsed ${Math.max(0, transcodeProgress.timeElapsed / 1000).toFixed(1)} s · media ${formatTime(transcodeProgress.time / 1000)}${transcodeDurationSeconds === undefined ? ' · duration unknown' : ` / ${formatTime(transcodeDurationSeconds)}`} · ${formatBytes(transcodeProgress.size)}${transcodeProgressPercent === undefined ? '' : ` · ${Math.floor(transcodeProgressPercent)}%`}`
                      : transcodeDurationSeconds === undefined
                        ? 'Progress is indeterminate because the input duration is unavailable.'
                        : 'Waiting for statistics from FFmpeg.'}
                  </Typography>
                </Paper>
              )}
              {!capabilities.transcode && <Alert severity="info">Transcoding is disabled because required runtime codecs or muxers are unavailable. {capabilities.detail}</Alert>}
              {selectedMedia && <Typography variant="caption" color="text.secondary">Imported input: {selectedMedia.path}</Typography>}
              {videoPath && !selectedMedia && <Typography variant="caption" color="text.secondary">Generated input: {videoPath}</Typography>}
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
