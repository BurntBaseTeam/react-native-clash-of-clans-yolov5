import "react-native-reanimated";
import { Dimensions, LayoutChangeEvent, StyleSheet } from "react-native";
import {
  Camera,
  useCameraDevices,
  useFrameProcessor,
} from "react-native-vision-camera";

import { Text } from "../../components/Themed";
import { scanClashBase } from "../frame-processors/Plugin";
import { useMemo, useState } from "react";
import { runOnJS } from "react-native-reanimated";
import { View } from "react-native";

export default function TabOneScreen() {
  const devices = useCameraDevices();
  const device = devices.back;
  const [coordinates, setCoordinates] = useState([]);
  const backCam = devices.back;

  const format = useMemo(() => {
    const desiredWidth = 1280;
    const desiredHeight = 720;
    let selectedCam;
    selectedCam = backCam;
    if (selectedCam) {
      for (let index = 0; index < selectedCam.formats.length; index++) {
        const format = selectedCam.formats[index];
        if (
          format.videoWidth == desiredWidth &&
          format.videoHeight == desiredHeight
        ) {
          console.log("selected format: " + format);
          return format;
        }
      }
    }
    return undefined;
  }, []);

  const frameProcessor = useFrameProcessor((frame) => {
    "worklet";
    let results = scanClashBase(frame);

    runOnJS(setCoordinates)(results);
    return;
  }, []);

  const [cameraWidth, setCameraWidth] = useState(0);
  const [cameraHeight, setCameraHeight] = useState(0);

  const handleCameraLayout = (event: LayoutChangeEvent) => {
    const { width, height } = event.nativeEvent.layout;
    setCameraWidth(width);
    setCameraHeight(height);
  };

  if (device == null)
    return (
      <>
        <Text>No camera device found</Text>
      </>
    );
  return (
    <View style={styles.container} onLayout={handleCameraLayout}>
      <Camera
        style={styles.camera}
        device={device}
        isActive={true}
        frameProcessor={frameProcessor}
        preset="medium"
        format={format}
      />
      <View style={{ position: "absolute", top: 0, left: 0 }}>
        {coordinates.map((box, index) => (
          <Box
            key={index}
            box={box}
            cameraWidth={cameraWidth}
            cameraHeight={cameraHeight}
          />
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    aspectRatio: 1,
    maxHeight: Dimensions.get("window").height * 0.5,
  },
  camera: {
    flex: 1,
  },
});

const Box = ({ box, cameraWidth, cameraHeight }: any) => {
  const x1 = (box.x - box.width / 2) * cameraWidth;
  const y1 = (box.y - box.height / 2) * cameraHeight;
  const width = box.width * cameraWidth;
  const height = box.height * cameraHeight;

  const boxStyle = {
    position: "absolute",
    borderColor: "red",
    borderWidth: 2,
    borderRadius: 3,
    left: x1,
    top: y1,
    width: width,
    height: height,
  } as any;

  return <View style={boxStyle} />;
};
