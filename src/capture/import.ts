import * as ImagePicker from 'expo-image-picker';
import type { Capture, Mode } from '../scanner/types';

export async function importImages(_mode: Mode): Promise<Capture> {
  const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], allowsMultipleSelection: true, orderedSelection: true, quality: 1, selectionLimit: 10, preferredAssetRepresentationMode: ImagePicker.UIImagePickerPreferredAssetRepresentationMode.Compatible });
  if (result.canceled) return { status: 'cancelled' };
  if (!result.assets.length) throw new Error('No readable images were returned. Cloud-only photos may need to be downloaded in Photos first.');
  return { status: 'captured', imageUris: result.assets.map(asset => asset.uri) };
}

export async function takePhoto(): Promise<Capture> {
  const permission = await ImagePicker.requestCameraPermissionsAsync();
  if (!permission.granted) throw new Error('Camera permission is required. Enable Camera in Settings.');
  const result = await ImagePicker.launchCameraAsync({ mediaTypes: ['images'], quality: 1 });
  return result.canceled ? { status: 'cancelled' } : { status: 'captured', imageUris: result.assets.map(asset => asset.uri) };
}
