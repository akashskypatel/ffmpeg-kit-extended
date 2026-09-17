import React, {useState} from 'react';
import {createRoot} from 'react-dom/client';
import {
  FFmpegKit,
  FFmpegKitExtended,
  FFplayKit,
  FFplayView,
  FFprobeKit,
} from 'ffmpeg-kit-extended';

function App() {
  const [status, setStatus] = useState('Not initialized');
  const [output, setOutput] = useState('');
  const [player, setPlayer] = useState<ReturnType<typeof FFplayKit.createSession>>();

  const initialize = async () => {
    try {
      await FFmpegKitExtended.initialize();
      setStatus(`Initialized ${FFmpegKitExtended.getVersion()}`);
    } catch (error) {
      setStatus(error instanceof Error ? error.message : String(error));
    }
  };

  const run = async () => {
    setStatus('Running FFmpeg');
    let logCallbacks = 0;
    let statisticsCallbacks = 0;
    const session = await FFmpegKit.executeAsync(
      '-hide_banner -loglevel info -f lavfi -i testsrc=duration=1:size=160x90:rate=4 -f null -',
      {
        logCallback: () => {
          logCallbacks += 1;
        },
        statisticsCallback: () => {
          statisticsCallbacks += 1;
        },
      },
    );
    setOutput(
      `${session.getOutput()}\nCallback counts: log=${logCallbacks}, statistics=${statisticsCallbacks}`,
    );
    setStatus(
      `FFmpeg state ${session.getState()} / return code ${session.getReturnCode()} / ` +
      `log callbacks ${logCallbacks} / statistics callbacks ${statisticsCallbacks}`,
    );
  };

  const probe = async () => {
    setStatus('Running FFprobe');
    const session = await FFprobeKit.executeAsync('-version');
    setOutput(session.getOutput());
    setStatus(`FFprobe state ${session.getState()} / return code ${session.getReturnCode()}`);
  };

  const mediaInfo = async () => {
    setStatus('Generating media for FFprobe');
    const generated = await FFmpegKit.executeAsync(
      '-loglevel fatal -f lavfi -i testsrc=duration=1:size=160x90:rate=4 -c:v mpeg4 -f matroska /tmp/ffmpeg-kit-web-test.mkv',
    );
    if (generated.getReturnCode() !== 0) {
      setStatus(`Media generation failed: ${generated.getReturnCode()}`);
      return;
    }
    const session = await FFprobeKit.getMediaInformation(
      '/tmp/ffmpeg-kit-web-test.mkv',
    );
    const information = session.getMediaInformation();
    setOutput(JSON.stringify(information, null, 2));
    setStatus(`Media info streams ${information?.streams.length ?? 0}`);
  };

  const play = async () => {
    const session = FFplayKit.createSession(
      '-loglevel fatal -f lavfi -i testsrc=duration=1:size=160x90:rate=4 -autoexit',
    );
    setPlayer(session);
    setStatus('Running FFplay');
    try {
      await session.executeAsync();
      setStatus(`FFplay state ${session.getState()} / return code ${session.getReturnCode()}`);
    } catch (error) {
      setStatus(error instanceof Error ? error.message : String(error));
    } finally {
      setPlayer(undefined);
    }
  };

  return (
    <main style={{fontFamily: 'sans-serif', maxWidth: 720, margin: '3rem auto'}}>
      <h1>FFmpegKit Extended Web</h1>
      <p data-testid="status">{status}</p>
      <button onClick={initialize}>Initialize</button>{' '}
      <button onClick={run}>Run FFmpeg</button>{' '}
      <button onClick={probe}>Run FFprobe</button>{' '}
      <button onClick={mediaInfo}>Run Media Info</button>{' '}
      <button onClick={play}>Run FFplay</button>{' '}
      <button onClick={() => player?.pause()} disabled={!player}>Pause</button>{' '}
      <button onClick={() => player?.resume()} disabled={!player}>Resume</button>{' '}
      <button onClick={() => player?.stop()} disabled={!player}>Stop</button>
      {' '}<button onClick={() => player?.cancel()} disabled={!player}>Cancel</button>
      <FFplayView
        style={{
          width: '100%',
          height: 180,
          marginTop: '1rem',
          backgroundColor: '#111',
        }}
      />
      <pre data-testid="output">{output}</pre>
    </main>
  );
}

createRoot(document.getElementById('root')!).render(<App />);
