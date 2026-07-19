import React from 'react';
import {
  Platform,
  View,
  type ViewProps,
} from 'react-native';

import NativeFFplayView from './FFplayViewNativeComponent';

export type FFplayViewProps = ViewProps;

export function FFplayView(
  props: FFplayViewProps,
): React.JSX.Element {
  if (Platform.OS === 'android') {
    return <NativeFFplayView {...props} />;
  }

  return <View {...props} />;
}