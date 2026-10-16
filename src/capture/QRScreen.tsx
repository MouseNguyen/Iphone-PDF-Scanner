import { useState } from 'react';
import { CameraView, useCameraPermissions } from 'expo-camera';
import * as Clipboard from 'expo-clipboard';
import { Linking, Text, View } from 'react-native';
import { Action, Message, showError, styles, useColors } from '../components/ui';

export default function QRScreen() {
  const c = useColors();
  const [permission, request] = useCameraPermissions(), [result, setResult] = useState(''), [copied, setCopied] = useState(false);
  if (!permission?.granted) return <View style={styles.content}><Message text="Camera access is needed to read QR codes." /><Action title={permission?.canAskAgain === false ? 'Open Settings' : 'Allow camera'} onPress={() => { if (permission?.canAskAgain === false) void Linking.openSettings(); else void request(); }} /></View>;
  return <View style={[styles.screen, { backgroundColor: c.background }]}>
    {!result ? <CameraView style={{ flex: 1 }} barcodeScannerSettings={{ barcodeTypes: ['qr'] }} onBarcodeScanned={({ data }) => { setResult(data); setCopied(false); }} /> : <View style={styles.content}><Text selectable style={{ color: c.text, fontSize: 20 }}>{result}</Text><Action title={copied ? 'Copied' : 'Copy result'} onPress={() => { void Clipboard.setStringAsync(result).then(() => setCopied(true)).catch(showError); }} /><Action title="Scan another" onPress={() => setResult('')} /></View>}
  </View>;
}
