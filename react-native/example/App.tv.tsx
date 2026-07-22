import React from 'react';

import {ExampleApp} from './src/ExampleApp';
import {examplePlatform} from './src/ExamplePlatform';

export default function App(): React.JSX.Element {
  return (
    <ExampleApp
      platformName="Apple tvOS"
      platformServices={examplePlatform}
    />
  );
}
