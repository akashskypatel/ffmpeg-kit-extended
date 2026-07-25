import React from 'react';
import {Platform} from 'react-native';

import {ExampleApp, type ExamplePlatformName} from './src/ExampleApp';
import {examplePlatform} from './src/ExamplePlatform';

function getPlatformName(): ExamplePlatformName {
  const platform = Platform.OS as string;

  if (platform === 'windows') {
    return 'Windows';
  }

  if (platform === 'macos') {
    return 'macOS';
  }

  if (platform === 'ios') {
    const isTV = (Platform as typeof Platform & {isTV?: boolean}).isTV;
    return isTV ? 'Apple tvOS' : 'iOS';
  }

  return 'Android';
}

export default function App(): React.JSX.Element {
  return (
    <ExampleApp
      platformName={getPlatformName()}
      platformServices={examplePlatform}
    />
  );
}
