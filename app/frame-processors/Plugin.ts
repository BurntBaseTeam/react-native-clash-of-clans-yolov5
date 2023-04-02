import type { Frame } from 'react-native-vision-camera';

// declare let _WORKLET: true | undefined;

export function scanClashBase(frame: Frame) {
  'worklet';
  //@ts-ignore
  return __scanClashBase(frame);
}


