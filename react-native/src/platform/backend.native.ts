import NativeFFmpegKitExtended from '../NativeFFmpegKitExtended';
import type {FFmpegKitBackend} from './backend';

const nativeBackend: FFmpegKitBackend = {
  ...NativeFFmpegKitExtended,
  initialize: async () => {
    NativeFFmpegKitExtended.initialize();
  },
  getFrameBufferSize: () => 0,
  copyFrame: () => ({width: 0, height: 0, linesize: 0, generation: 0}),
  getMediaInformationData: sessionId => {
    const json = NativeFFmpegKitExtended.getMediaInformationJson(sessionId);
    return json ? (JSON.parse(json) as ReturnType<FFmpegKitBackend['getMediaInformationData']>) : undefined;
  },
};

export function getBackend(): FFmpegKitBackend {
  return nativeBackend;
}
