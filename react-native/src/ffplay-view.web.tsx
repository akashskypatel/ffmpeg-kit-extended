import React, {useEffect, useRef} from 'react';
import {View, type ViewProps} from 'react-native';
import {readLatestFrame} from './platform/web/ffplay-frame-reader';

export type FFplayViewProps = ViewProps;

/** Browser FFplay surface backed by copied RGBA frames and a canvas. */
export function FFplayView(props: FFplayViewProps): React.JSX.Element {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const frameGeneration = useRef(0);

  useEffect(() => {
    let active = true;
    let animationFrame = 0;
    const render = () => {
      if (!active) return;
      const canvas = canvasRef.current;
      const frame = readLatestFrame();
      if (canvas && frame && frame.generation !== frameGeneration.current) {
        frameGeneration.current = frame.generation;
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
