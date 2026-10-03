import 'react-native';
import React from 'react';
import renderer from 'react-test-renderer';
import App from '../App';
const mockReact = React;

let activeRenderer: ReturnType<typeof renderer.create> | undefined;

afterEach(async () => {
  if (activeRenderer) {
    await renderer.act(async () => {
      activeRenderer?.unmount();
    });
    activeRenderer = undefined;
  }
});

jest.mock('ffmpeg-kit-extended', () => ({
  FFmpegKitExtended: { initialize: jest.fn() },
  FFmpegKitConfig: {
    getLogLevel: () => 32,
    logLevelToString: () => 'info',
    setLogLevel: jest.fn(),
  },
  FFmpegKit: {},
  FFprobeKit: {},
  FFplayKit: {},
  FFplayView: (props: { testID?: string }) =>
    mockReact.createElement('FFplayView', props),
  LogLevel: {
    Quiet: -8,
    Error: 16,
    Warning: 24,
    Info: 32,
    Verbose: 40,
    Debug: 48,
    Trace: 56,
  },
  ReturnCode: { Success: 0 },
  SessionState: { Running: 1 },
}));

jest.mock('react-native-file-access', () => ({
  Dirs: { CacheDir: '/tmp' },
  FileSystem: { mkdir: jest.fn().mockResolvedValue('/tmp') },
  Util: { basename: (value: string) => value },
}));

jest.mock('@react-native-documents/picker', () => ({
  errorCodes: { OPERATION_CANCELED: 'OPERATION_CANCELED' },
  isErrorWithCode: () => false,
  keepLocalCopy: jest.fn(),
  pick: jest.fn(),
  types: { video: 'video/*' },
}));

test('renders the example app', async () => {
  await renderer.act(async () => {
    activeRenderer = renderer.create(<App />);
  });
});

test('exposes the semantic interactive selector contract', async () => {
  let app: ReturnType<typeof renderer.create>;
  await renderer.act(async () => {
    app = renderer.create(<App />);
  });
  activeRenderer = app!;

  const root = app!.root;
  const expectSelector = (testID: string) => {
    const matches = root.findAllByProps({ testID });
    if (matches.length < 1) {
      throw new Error(`Expected a ${testID} selector, found none`);
    }
  };

  for (const testID of [
    'app.root',
    'logs.output',
    'toolbar.log-level',
    'toolbar.system-info',
    'toolbar.clear-logs',
    'tab.ffmpeg',
    'tab.stream',
    'tab.ffprobe',
    'tab.ffplay',
    'tab.transcode',
    'ffmpeg.generate-video',
    'ffmpeg.generate-audio',
    'ffmpeg.version.async',
    'ffmpeg.version.awaited',
    'ffmpeg.help',
    'ffmpeg.command.input',
    'ffmpeg.command.run',
  ]) {
    expectSelector(testID);
  }

  for (const [tabID, selectors] of [
    ['tab.stream', ['stream.url.input', 'stream.record', 'stream.refresh']],
    [
      'tab.ffprobe',
      [
        'ffprobe.pick-file',
        'ffprobe.media-info',
        'ffprobe.version.async',
        'ffprobe.version.awaited',
        'ffprobe.command.input',
        'ffprobe.command.run',
      ],
    ],
    [
      'tab.ffplay',
      [
        'ffplay.video-surface',
        'ffplay.command.input',
        'ffplay.command.run',
        'ffplay.generate-video',
        'ffplay.generate-audio',
        'ffplay.play-video',
        'ffplay.play-audio',
        'ffplay.pause',
        'ffplay.resume',
        'ffplay.stop',
        'ffplay.seek-back',
        'ffplay.seek-forward',
        'ffplay.position',
        'ffplay.volume',
      ],
    ],
    ['tab.transcode', ['transcode.pick-input', 'transcode.run']],
  ] as const) {
    await renderer.act(async () => {
      root.findAllByProps({ testID: tabID })[0].props.onPress();
    });
    for (const testID of selectors) {
      expectSelector(testID);
    }
  }
});
