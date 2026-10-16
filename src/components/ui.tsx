import { ActivityIndicator, Alert, Linking, Pressable, StyleSheet, Text, useColorScheme, View } from 'react-native';
import type { ReactNode } from 'react';

export function useColors() {
  return useColorScheme() === 'dark'
    ? { background: '#111111', surface: '#202020', text: '#FFFFFF', secondary: '#C5C5C5', accent: '#8EB8FF', border: '#929292', danger: '#FFAAAA' }
    : { background: '#F5F5F2', surface: '#FFFFFF', text: '#171717', secondary: '#505050', accent: '#1546A0', border: '#727272', danger: '#A01919' };
}

export function Action({ title, onPress, disabled = false, danger = false, selected = false }: { title: string; onPress: () => void; disabled?: boolean; danger?: boolean; selected?: boolean }) {
  const c = useColors();
  return <Pressable accessibilityRole="button" accessibilityLabel={title} accessibilityState={{ disabled, selected }} disabled={disabled} onPress={onPress} style={({ pressed }) => [styles.action, { borderColor: selected ? c.accent : c.border, backgroundColor: c.surface, opacity: disabled ? 0.5 : pressed ? 0.65 : 1 }]}><Text style={{ color: danger ? c.danger : c.accent, fontSize: 16, fontWeight: selected ? '700' : '500' }}>{title}</Text></Pressable>;
}

export function Message({ text, busy = false }: { text: string; busy?: boolean }) {
  const c = useColors();
  return <View accessibilityLiveRegion="polite" style={styles.message}>{busy && <ActivityIndicator color={c.accent} />}<Text selectable style={{ color: c.text, fontSize: 16, flexShrink: 1 }}>{text}</Text></View>;
}

export function Row({ children }: { children: ReactNode }) { return <View style={styles.row}>{children}</View>; }

export function showError(error: unknown) {
  const message = error instanceof Error ? error.message : String(error);
  Alert.alert('Could not finish', message, [{ text: 'OK' }, ...(message.toLowerCase().includes('permission') || message.includes('Settings') ? [{ text: 'Open Settings', onPress: () => { void Linking.openSettings(); } }] : [])]);
}

export const styles = StyleSheet.create({
  screen: { flex: 1 }, content: { padding: 16, gap: 16, paddingBottom: 40 }, row: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, alignItems: 'center' },
  action: { minHeight: 44, paddingHorizontal: 14, paddingVertical: 11, borderRadius: 9, borderWidth: 1, justifyContent: 'center' },
  message: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingVertical: 8 }, title: { fontSize: 26, fontWeight: '700' },
  input: { borderWidth: 1, borderRadius: 8, padding: 12, fontSize: 17, minHeight: 48 },
});
