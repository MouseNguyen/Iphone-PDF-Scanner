import type { ExpoConfig } from 'expo/config';

const config: ExpoConfig = {
  name: 'Pocket Scanner',
  slug: 'pocket-document-scanner',
  version: '0.1.0',
  scheme: 'pocketscanner',
  platforms: ['ios'],
  userInterfaceStyle: 'automatic',
  ios: {
    supportsTablet: false,
    bundleIdentifier: 'com.duke.pocketscanner',
    infoPlist: {
      NSCameraUsageDescription: 'Scan documents, ID cards, photos and QR codes on your iPhone.',
      ITSAppUsesNonExemptEncryption: false,
    },
  },
  plugins: ['expo-router', ['expo-camera', { cameraPermission: 'Use the camera to scan QR codes.', microphonePermission: false, recordAudioAndroid: false }], ['expo-image-picker', { photosPermission: 'Choose photos to scan into documents.', cameraPermission: 'Take photos for your documents.', microphonePermission: false }]],
  experiments: { typedRoutes: true },
};
export default config;
