[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / FFplayView

# Function: FFplayView()

> **FFplayView**(`props`): `Element`

Renders the platform-native FFplay video surface. The Web resolver selects
`ffplay-view.web.tsx`, which renders the same API with a canvas.

## Parameters

### props

`ViewProps`

## Returns

`Element`

## Example

```tsx
<FFplayView style={{width: '100%', aspectRatio: 16 / 9}} />
```

On unsupported React Native hosts this renders a normal `View`, allowing
shared layouts to remain valid even though no native video frames are shown.
