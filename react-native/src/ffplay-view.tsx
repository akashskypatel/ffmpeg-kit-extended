/**
 * Cross-platform React component used as FFplay's video output surface.
 *
 * Mount this view before executing a video `FFplaySession`. Audio-only playback
 * does not require it. The current native implementations expose one active
 * FFplay video target per process, so the most recently mounted/active view is
 * the destination for decoded frames.
 */
import React from 'react';
import {
  Platform,
  View,
  type ViewProps,
} from 'react-native';

import NativeFFplayView from './FFplayViewNativeComponent';

/**
 * Standard React Native view props for `FFplayView`.
 *
 * Use `style` to provide an explicit size. An `aspectRatio` is commonly used to
 * preserve a video-shaped viewport, while the native renderer letterboxes the
 * decoded image as needed.
 */
export type FFplayViewProps = ViewProps;

/**
 * Renders the platform-native FFplay video surface.
 *
 * @example
 * ```tsx
 * <FFplayView style={{width: '100%', aspectRatio: 16 / 9}} />
 * ```
 *
 * On unsupported React Native hosts this renders a normal `View`, allowing
 * shared layouts to remain valid even though no native video frames are shown.
 */
export function FFplayView(
  props: FFplayViewProps,
): React.JSX.Element {
  if (
    Platform.OS === 'android' ||
    Platform.OS === 'ios' ||
    Platform.OS === 'macos' ||
    Platform.OS === 'windows'
  ) {
    return <NativeFFplayView {...props} />;
  }

  return <View {...props} />;
}