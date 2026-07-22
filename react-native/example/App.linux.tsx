import React from 'react';

import {ExampleApp} from './src/ExampleApp';
import {examplePlatform} from './src/ExamplePlatform.linux';

export default function App(): React.JSX.Element {
  return (
    <ExampleApp
      platformName="Linux"
      platformServices={examplePlatform}
    />
  );
}
