#!/usr/bin/env node

const path = require('node:path');

const programFiles = process.env.ProgramFiles ?? 'C:\\Program Files';
const systemRoot = process.env.SystemRoot ?? 'C:\\Windows';
const appData =
  process.env.APPDATA ??
  path.join(process.env.USERPROFILE ?? '', 'AppData', 'Roaming');
const existingPath = process.env.PATH ?? process.env.Path ?? '';

process.env.PATH = [
  path.dirname(process.execPath),
  path.join(programFiles, 'dotnet'),
  path.join(systemRoot, 'System32'),
  path.join(systemRoot, 'System32', 'WindowsPowerShell', 'v1.0'),
  path.join(programFiles, 'PowerShell', '7'),
  path.join(appData, 'npm'),
  existingPath,
]
  .filter(Boolean)
  .join(';');
process.env.Path = process.env.PATH;
process.env.DOTNET_ROOT = path.join(programFiles, 'dotnet');
process.env.DOTNET_ROOT_X64 = process.env.DOTNET_ROOT;
process.env.DOTNET_MULTILEVEL_LOOKUP = '1';

require.resolve('@react-native-community/cli/build/bin.js');
require('@react-native-community/cli/build/bin.js');
