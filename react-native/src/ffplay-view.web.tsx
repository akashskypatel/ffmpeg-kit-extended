import React, {useEffect, useRef} from 'react';
import {View, type ViewProps} from 'react-native';
import {readLatestFrame, type WasmVideoFrame} from './platform/web/ffplay-frame-reader';
import {currentFFplayPlaybackEpoch} from './platform/web/ffplay-frame-state';

export type FFplayViewProps = ViewProps;

/** Browser FFplay surface backed by copied RGBA frames and a canvas. */
export function FFplayView(props: FFplayViewProps): React.JSX.Element {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const frameVersion = useRef<WasmVideoFrame | undefined>(undefined);
  const renderedEpoch = useRef(currentFFplayPlaybackEpoch());

  useEffect(() => {
    let active = true;
    let animationFrame = 0;
    const render = () => {
      if (!active) return;
      const canvas = canvasRef.current;
      const epoch = currentFFplayPlaybackEpoch();
      if (epoch !== renderedEpoch.current) {
        // A new playback owns the surface, even when it has not produced a
        // video frame yet (for example, audio-only playback).
        renderedEpoch.current = epoch;
        frameVersion.current = undefined;
        if (canvas) {
          const context = canvas.getContext('2d');
          context?.clearRect(0, 0, canvas.width, canvas.height);
        }
      }
      const frame = readLatestFrame(frameVersion.current);
      if (canvas && frame) {
        frameVersion.current = frame;
        canvas.width = frame.width;
        canvas.height = frame.height;
        const context = canvas.getContext('2d');
        if (context) {
          const image = new ImageData(frame.width, frame.height);
          for (let row = 0; row < frame.height; row += 1) {
            image.data.set(
              frame.bytes.subarray(row * frame.linesize, row * frame.linesize + frame.width * 4),
              row * frame.width * 4,
            );
          }
          context.putImageData(image, 0, 0);
        }
      }
      animationFrame = requestAnimationFrame(render);
    };
    animationFrame = requestAnimationFrame(render);
    return () => {
      active = false;
      cancelAnimationFrame(animationFrame);
    };
  }, []);

  const canvasStyle = {
    display: 'block',
    width: '100%',
    height: '100%',
  } as const;
  return (
    <View {...props}>
      <canvas ref={canvasRef} style={canvasStyle} />
    </View>
  );
}
