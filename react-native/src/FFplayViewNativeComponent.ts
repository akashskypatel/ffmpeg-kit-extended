/**
 * React Native Codegen declaration for the native FFplay video surface.
 *
 * End users should render the exported `FFplayView` wrapper instead of
 * importing this generated component directly. The native component carries
 * standard React Native `ViewProps`; playback is controlled by `FFplaySession`.
 */
import type {
  HostComponent,
  ViewProps,
} from 'react-native';

import {
  codegenNativeComponent,
} from 'react-native';

/**
 * Native view properties accepted by the generated component.
 *
 * FFplay currently exposes no playback-specific view props. Use normal layout,
 * accessibility, test, and style props, then control playback through the
 * corresponding `FFplaySession`.
 */
export interface NativeProps extends ViewProps {}

export default codegenNativeComponent<NativeProps>(
  'FFplayView',
) as HostComponent<NativeProps>;