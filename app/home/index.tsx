import "react-native-reanimated";
import { LayoutChangeEvent, StyleSheet } from "react-native";
import {
  Camera,
  useCameraDevices,
  useFrameProcessor,
} from "react-native-vision-camera";

import { Text } from "../../components/Themed";
import { scanClashBase } from "../frame-processors/Plugin";
import { useState } from "react";
import { runOnJS } from "react-native-reanimated";
import { View } from "react-native";

export default function TabOneScreen() {
  const devices = useCameraDevices();
  const device = devices.back;
  const [coordinates, setCoordinates] = useState([]);

  const frameProcessor = useFrameProcessor(
    (frame) => {
      "worklet";
      let results = scanClashBase(frame)
      console.log("frameProcessor", results)

      runOnJS(setCoordinates)(results)
      return
    },
    []
  );

  const [cameraWidth, setCameraWidth] = useState(0);
  const [cameraHeight, setCameraHeight] = useState(0);

  const handleCameraLayout = (event: LayoutChangeEvent) => {
    const { width, height } = event.nativeEvent.layout;
    console.log("handleCameraLayout", width, height)
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
    <View style={styles.container}>
      <Camera
        onLayout={handleCameraLayout}
        style={styles.camera}
        device={device}
        isActive={true}
        frameProcessor={frameProcessor}
        preset="medium"
      />
      {coordinates.map((box, index) => (
        <Box
          key={index}
          box={box}
          cameraWidth={cameraWidth}
          cameraHeight={cameraHeight}
        />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  camera: {
    flex: 1,
  },
});

const Box = ({ box, cameraWidth, cameraHeight }: any) => {
  const boxStyle = {
    position: "absolute",
    borderColor: "red",
    borderWidth: 2,
    borderRadius: 3,
    width: box.width * cameraWidth,
    height: box.height * cameraHeight,
    left: box.x * cameraWidth,
    top: box.y * cameraHeight,
  } as any;

  return <View style={boxStyle} />;
};
