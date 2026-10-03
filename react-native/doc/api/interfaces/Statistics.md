[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / Statistics

# Interface: Statistics

Progress values emitted while an FFmpeg processing session is running.

## Properties

### bitrate

> **bitrate**: `number`

Current bitrate in bits per second.

***

### dropFrames

> **dropFrames**: `number`

Number of dropped frames reported by FFmpeg.

***

### dupFrames

> **dupFrames**: `number`

Number of duplicated frames reported by FFmpeg.

***

### sessionId

> **sessionId**: `number`

ID of the FFmpeg session that produced this update.

***

### size

> **size**: `number`

Current output size in bytes.

***

### speed

> **speed**: `number`

Processing speed multiplier, where `1` is real time.

***

### time

> **time**: `number`

Current media timestamp in milliseconds.

***

### timeElapsed

> **timeElapsed**: `number`

Wall-clock processing time elapsed in milliseconds.

***

### videoFps

> **videoFps**: `number`

Current video processing rate in frames per second.

***

### videoFrameNumber

> **videoFrameNumber**: `number`

Number of video frames processed so far.

***

### videoQuality

> **videoQuality**: `number`

Current encoder quality/quantizer value reported by FFmpeg.
