import { useCallback, useEffect, useState } from 'react';
import { Alert, FlatList, Image, Pressable, Text, TextInput, View } from 'react-native';
import { router, useFocusEffect } from 'expo-router';
import { scanner } from '../scanner/native';
import type { Document, Mode } from '../scanner/types';
import { Action, Message, Row, showError, styles, useColors } from '../components/ui';
import { queryDocuments } from './query';
import ModeChooser from '../capture/ModeChooser';
import { importImages, takePhoto } from '../capture/import';
import { validateSelection } from '../capture/selection';

export default function LibraryScreen() {
  const c = useColors();
  const [documents, setDocuments] = useState<Document[]>([]), [drafts, setDrafts] = useState<Document[]>([]);
  const [unavailable, setUnavailable] = useState<{ id: string; reason: string }[]>([]);
  const [query, setQuery] = useState(''), [mode, setMode] = useState<Mode>('document');
  const [category, setCategory] = useState<Mode | undefined>(), [sort, setSort] = useState<'date' | 'name'>('date');
  const [grid, setGrid] = useState(false), [selected, setSelected] = useState<string[]>([]);
  const [busy, setBusy] = useState(false), [error, setError] = useState('');
  const [preferencesLoaded, setPreferencesLoaded] = useState(false);
  useEffect(() => { void scanner.libraryPreferences().then(p => { setGrid(p.grid); setSort(p.sort); setCategory(p.category === 'all' ? undefined : p.category); setPreferencesLoaded(true); }).catch(showError); }, []);
  useEffect(() => { if (preferencesLoaded) void scanner.setLibraryPreferences({ grid, sort, category: category ?? 'all' }).catch(showError); }, [grid, sort, category, preferencesLoaded]);
  const reload = useCallback(async () => {
    try { const snapshot = await scanner.librarySnapshot(); setDocuments(snapshot.documents); setDrafts(snapshot.drafts); setUnavailable(snapshot.unavailable); setError(''); }
    catch (e) { setError(e instanceof Error ? e.message : String(e)); }
  }, []);
  useFocusEffect(useCallback(() => { void reload(); }, [reload]));

  async function capture(fromGallery: boolean) {
    if (busy) return; setBusy(true);
    try {
      const result = fromGallery ? await importImages(mode) : mode === 'photo' ? await takePhoto() : await scanner.scanDocument();
      if (result.status === 'cancelled') return;
      const doc = await scanner.createDraft(mode, validateSelection(mode, result.imageUris));
      router.push({ pathname: '/document/[id]', params: { id: doc.id } });
    } catch (e) { showError(e); } finally { setBusy(false); }
  }

  function confirmDelete() {
    Alert.alert('Delete selected documents?', 'This removes their app-owned pages and exports. Your Photos originals are kept.', [{ text: 'Cancel', style: 'cancel' }, { text: 'Delete', style: 'destructive', onPress: () => {
      setBusy(true); void scanner.deleteDocuments(selected).then(() => setSelected([])).catch(showError).finally(() => { setBusy(false); void reload(); });
    } }]);
  }

  const filtered = queryDocuments(documents, { text: query, ...(category ? { mode: category } : {}), sort, descending: sort === 'date' });
  return <View style={[styles.screen, { backgroundColor: c.background }]}>
    <FlatList key={grid ? 'grid' : 'list'} numColumns={grid ? 2 : 1} data={filtered} keyExtractor={doc => doc.id} contentContainerStyle={styles.content}
      ListHeaderComponent={<View style={{ gap: 12 }}>
        <Text style={[styles.title, { color: c.text }]}>Your documents</Text>
        <Text style={{ color: c.secondary, fontSize: 16 }}>Scan, recognize and save on your iPhone.</Text>
        <ModeChooser mode={mode} onChange={setMode} />
        <Row><Action title="Scan" disabled={busy} onPress={() => { void capture(false); }} /><Action title="Import photos" disabled={busy} onPress={() => { void capture(true); }} /><Action title="QR" disabled={busy} onPress={() => router.push('/qr')} /></Row>
        <Row><Action title="Signatures" onPress={() => router.push('/signatures')} /><Action title="Help" onPress={() => Alert.alert('Pocket Scanner', 'Choose a mode, scan or import, review the pages, recognize text, then save and share.\n\nID card: capture front then back. Auto uses the native corrected scan; Reset returns to that retained scan. A bad initial crop may require retaking.\n\nVisual signatures are not cryptographic signatures. Processing stays on this phone. OS backup and your chosen share destination follow their own settings.')} /></Row>
        <TextInput accessibilityLabel="Search documents by name, date or recognized text" placeholder="Search name, date or text" placeholderTextColor={c.secondary} value={query} onChangeText={setQuery} style={[styles.input, { color: c.text, borderColor: c.border, backgroundColor: c.surface }]} />
        <Row>{(['all', 'document', 'id', 'photo'] as const).map(value => <Action key={value} title={value === 'all' ? 'All' : value === 'id' ? 'ID cards' : value === 'photo' ? 'Photos' : 'Documents'} selected={value === (category ?? 'all')} onPress={() => setCategory(value === 'all' ? undefined : value)} />)}</Row>
        <Row><Action title={sort === 'date' ? 'Sort: newest' : 'Sort: name'} onPress={() => setSort(sort === 'date' ? 'name' : 'date')} /><Action title={grid ? 'List view' : 'Grid view'} onPress={() => setGrid(!grid)} />{selected.length > 0 && <><Action title="Share selected images" disabled={busy} onPress={() => { void scanner.shareImages(documents.filter(d => selected.includes(d.id)).flatMap(d => d.pages.map(p => p.imageUri))).catch(showError); }} /><Action title={`Delete ${selected.length}`} danger disabled={busy} onPress={confirmDelete} /></>}</Row>
        {busy && <Message busy text="Preparing your document…" />}
        {!!error && <><Message text={error} /><Action title="Retry" onPress={() => { void reload(); }} /></>}
        {unavailable.map(item => <View key={item.id} style={{ gap:8 }}><Message text={item.reason} /><Action title="Delete unreadable document files" danger onPress={() => Alert.alert('Delete these retained files?', 'This cannot recover a damaged document. Deletion permanently removes only this document’s app-owned files.', [{ text:'Keep files',style:'cancel' },{ text:'Delete files',style:'destructive',onPress:() => { void scanner.deleteDocuments([item.id]).then(reload).catch(showError); } }])} /></View>)}
        {drafts.length > 0 && <><Text style={{ color: c.text, fontSize: 20, fontWeight: '600' }}>Continue a draft</Text>{drafts.map(d => <Action key={d.id} title={`${d.name} · ${d.pages.length} pages`} onPress={() => router.push({ pathname: '/document/[id]', params: { id: d.id } })} />)}</>}
      </View>}
      ListEmptyComponent={!error ? <Message text={query ? 'No matching documents.' : 'No saved documents yet. Scan a page to begin.'} /> : <View />}
      renderItem={({ item }) => <View style={{ flex: 1, padding: 8, marginTop: 12, gap: 8, backgroundColor: c.surface, borderRadius: 10 }}>
        <Pressable accessibilityRole="button" accessibilityLabel={`Open ${item.name}, ${item.pages.length} pages`} onPress={() => router.push({ pathname: '/document/[id]', params: { id: item.id } })} style={{ minHeight: 72, gap: 8 }}>
          {grid && item.pages[0] && <Image source={{ uri: item.pages[0].imageUri }} style={{ height: 150, width: '100%' }} resizeMode="contain" />}
          <Text style={{ color: c.text, fontSize: 18, fontWeight: '600' }}>{item.name}</Text><Text style={{ color: c.secondary }}>{item.pages.length} pages · {new Date(item.updatedAt).toLocaleDateString()}</Text>
        </Pressable>
        <Action title={selected.includes(item.id) ? 'Selected' : 'Select'} selected={selected.includes(item.id)} onPress={() => setSelected(current => current.includes(item.id) ? current.filter(id => id !== item.id) : [...current, item.id])} />
      </View>} />
  </View>;
}
