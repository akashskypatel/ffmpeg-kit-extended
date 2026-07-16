import 'react-native';
import React from 'react';
import renderer from 'react-test-renderer';
import App from '../App.android';

jest.mock('ffmpeg-kit-extended', () => ({
  FFmpegKitExtended: {initialize: jest.fn()},
  FFmpegKitConfig: {
    getLogLevel: () => 32,
    logLevelToString: () => 'info',
    setLogLevel: jest.fn(),
  },
  FFmpegKit: {},
  FFprobeKit: {},
  FFplayKit: {},
  LogLevel: {Quiet: -8, Error: 16, Warning: 24, Info: 32, Verbose: 40, Debug: 48, Trace: 56},
  ReturnCode: {Success: 0},
  SessionState: {Running: 1},
}));

jest.mock('react-native-file-access', () => ({
  Dirs: {CacheDir: '/tmp'},
  FileSystem: {mkdir: jest.fn().mockResolvedValue('/tmp')},
  Util: {basename: (value: string) => value},
}));

jest.mock('@react-native-documents/picker', () => ({
  errorCodes: {OPERATION_CANCELED: 'OPERATION_CANCELED'},
  isErrorWithCode: () => false,
  keepLocalCopy: jest.fn(),
  pick: jest.fn(),
  types: {video: 'video/*'},
}));

jest.mock('@react-native-community/slider', () => 'Slider');

test('renders the example app', async () => {
  await renderer.act(async () => {
    renderer.create(<App />);
  });
});
