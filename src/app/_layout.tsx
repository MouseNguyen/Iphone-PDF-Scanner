import { Stack } from 'expo-router';
import { useColors } from '../components/ui';

export default function Layout() {
  const colors = useColors();
  return <Stack screenOptions={{ headerStyle: { backgroundColor: colors.surface }, headerTintColor: colors.text, contentStyle: { backgroundColor: colors.background } }}>
    <Stack.Screen name="index" options={{ title: 'Pocket Scanner' }} />
    <Stack.Screen name="document/[id]" options={{ title: 'Document' }} />
    <Stack.Screen name="signatures" options={{ title: 'Signatures' }} />
    <Stack.Screen name="qr" options={{ title: 'QR scanner' }} />
  </Stack>;
}
