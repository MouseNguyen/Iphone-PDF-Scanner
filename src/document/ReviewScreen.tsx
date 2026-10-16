import { useEffect, useRef, useState } from 'react';
import { Alert, Image, ScrollView, Text, TextInput, View } from 'react-native';
import { router } from 'expo-router';
import * as Sharing from 'expo-sharing';
import { scanner } from '../scanner/native';
import type { Document, Edit, Export, Page, SignaturePlacement } from '../scanner/types';
import { Action, Message, Row, showError, styles, useColors } from '../components/ui';
import { recognizeDocument } from './workflow';
import CropEditor from './CropEditor';
import PlacementEditor from '../signatures/PlacementEditor';
import { importImages } from '../capture/import';

export default function ReviewScreen({ id }: { id: string }) {
  const c = useColors();
  const [doc, setDoc] = useState<Document>(), [name, setName] = useState(''), [pageIndex, setPageIndex] = useState(0);
  const [busy, setBusy] = useState(false), [status, setStatus] = useState(''), [crop, setCrop] = useState(false);
  const [placement, setPlacement] = useState<{ index: number; value: SignaturePlacement }>();
  const cancelled = useRef(false), mounted = useRef(true), locked = useRef(false);
  useEffect(() => {
    mounted.current = true; cancelled.current = false;
    void scanner.loadDocument(id).then(value => { if (mounted.current) {
      setDoc(value); setName(value.name);
      if (value.pages.some(page => page.ocr.status === 'pending')) void run('Recognizing text…', recognize);
    } }).catch(showError);
    return () => { mounted.current = false; cancelled.current = true; void scanner.cancelProcessing(id).catch(() => {}); };
  }, [id]);
  const page = doc?.pages[Math.min(pageIndex, doc.pages.length-1)];

  async function run(label: string, operation: () => Promise<void>) {
    if (locked.current) return;
    locked.current = true; setBusy(true); setStatus(label); cancelled.current = false;
    try { await operation(); } catch (e) { if (mounted.current && !cancelled.current) showError(e); }
    finally { locked.current = false; if (mounted.current) { setBusy(false); setStatus(''); } }
  }
  async function reload() { const value = await scanner.loadDocument(id); if (mounted.current) setDoc(value); return value; }
  async function recognize() {
    const current = await reload();
    let count = 0;
    await recognizeDocument(scanner, current, () => cancelled.current, () => { count++; if (mounted.current) setStatus(`Processed ${count} of ${current.pages.length} pages`); });
    await reload();
  }
  function edit(value: Edit) {
    if (!doc || !page) return;
    void run('Applying adjustment…', async () => { const result = await scanner.editPage(id, page.id, doc.revision, value); setDoc(result); setCrop(false); setPlacement(undefined); });
  }
  async function exportPDF(allowImageOnly: boolean, preview: boolean) {
    const current = await reload();
    const file: Export = await scanner.exportPDF(id, current.revision, allowImageOnly);
    if (preview) await scanner.previewPDF(file.uri);
    else {
      if (!await Sharing.isAvailableAsync()) throw new Error('Sharing is unavailable on this device.');
      await Sharing.shareAsync(file.uri, { mimeType: 'application/pdf', UTI: 'com.adobe.pdf', dialogTitle: current.name });
    }
  }
  function requestExport(preview: boolean) {
    if (!doc) return;
    const missing = doc.pages.filter(p => p.ocr.status !== 'ready' || p.ocr.revision !== p.revision).length;
    if (missing) Alert.alert('Some pages are not searchable', `${missing} page(s) need recognition. You can recognize them first or export their images without searchable text.`, [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Recognize text', onPress: () => { void run('Recognizing text…', recognize); } },
      { text: 'Export with image-only pages', onPress: () => { void run('Creating PDF…', () => exportPDF(true, preview)); } },
    ]);
    else void run('Creating searchable PDF…', () => exportPDF(false, preview));
  }
  async function append(gallery: boolean, replace = false) {
    if (!doc) return;
    const result = gallery ? await importImages(doc.mode) : await scanner.scanDocument();
    if (result.status === 'captured') setDoc(await scanner.appendPages(id, doc.revision, result.imageUris, replace ? page?.id : undefined));
  }
  async function chooseSignature() {
    if (!page) return;
    const values = await scanner.listSignatures();
    if (!values.length) { Alert.alert('No saved signatures', 'Create a signature first, then return to this document.', [{ text: 'Cancel' }, { text: 'Create signature', onPress: () => router.push('/signatures') }]); return; }
    Alert.alert('Choose signature', undefined, [...values.map(s => ({ text: s.name, onPress: () => setPlacement({ index: page.edit.signatures.length, value: { assetId: s.id, imageUri: s.imageUri, x: 0.3, y: 0.7, width: 0.4, height: 0.16, radians: 0, mirrored: false } }) })), { text: 'Cancel', style: 'cancel' }]);
  }
  if (!doc || !page) return <View style={styles.content}><Message text="Opening document…" busy /></View>;
  const ready = doc.pages.filter(p => p.ocr.status === 'ready').length;
  return <ScrollView style={{ backgroundColor: c.background }} contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
    <TextInput accessibilityLabel="Document name" value={name} onChangeText={setName} editable={!busy} style={[styles.input, { color: c.text, borderColor: c.border, backgroundColor: c.surface }]} />
    <Row><Action title={doc.saved ? 'Save name' : 'Save document'} disabled={busy || !name.trim()} onPress={() => { void run('Saving…', async () => { setDoc(await scanner.saveDocument(id, doc.revision, name)); }); }} /><Action title="Recognize text" disabled={busy} onPress={() => { void run('Recognizing text…', recognize); }} /></Row>
    <Message text={busy ? status : `${doc.saved ? 'Saved' : 'Recoverable draft'} · ${ready}/${doc.pages.length} pages recognized`} busy={busy} />
    {busy && <Action title="Cancel processing" onPress={() => { cancelled.current = true; void scanner.cancelProcessing(id); }} />}
    <Row>{doc.pages.map((p, i) => <Action key={p.id} title={`Page ${i+1}`} selected={page.id === p.id} disabled={busy} onPress={() => { setPageIndex(i); setCrop(false); setPlacement(undefined); }} />)}</Row>
    {crop ? <CropEditor uri={page.baseUri} {...(page.edit.corners ? { initial: page.edit.corners } : {})} onCancel={() => setCrop(false)} onApply={corners => edit({ ...page.edit, corners })} /> : <Image accessibilityLabel={`Page ${pageIndex+1} preview`} source={{ uri: page.imageUri }} style={{ width: '100%', height: 430, backgroundColor: c.surface }} resizeMode="contain" />}
    {!busy && !crop && <>
      <Row>{(['auto', 'color', 'grayscale', 'bw'] as const).map(filter => <Action key={filter} title={filter === 'bw' ? 'Black & white' : filter === 'auto' ? 'Auto' : filter === 'color' ? 'Color' : 'Grayscale'} selected={page.edit.filter === filter} onPress={() => edit({ ...page.edit, filter })} />)}</Row>
      <Row><Action title="Rotate" onPress={() => edit({ ...page.edit, quarterTurns: ((page.edit.quarterTurns+1)%4) as Edit['quarterTurns'] })} /><Action title="Adjust corners" onPress={() => setCrop(true)} /><Action title="Reset page" onPress={() => edit({ filter: doc.mode === 'photo' ? 'color' : 'auto', quarterTurns: 0, signatures: [] })} /></Row>
      <Row><Action title="Add signature" onPress={() => { void chooseSignature().catch(showError); }} />{page.edit.signatures.map((s, i) => <Action key={i} title={`Edit signature ${i+1}`} onPress={() => setPlacement({ index: i, value: s })} />)}</Row>
      {placement && <PlacementEditor initial={placement.value} onCancel={() => setPlacement(undefined)} onApply={value => {
        const signatures = [...page.edit.signatures];
        if (value) signatures[placement.index] = value; else signatures.splice(placement.index, 1);
        edit({ ...page.edit, signatures });
      }} />}
      <Row><Action title="Scan more" onPress={() => { void run('Adding pages…', () => append(false)); }} /><Action title="Import more" onPress={() => { void run('Importing…', () => append(true)); }} /><Action title="Retake page" onPress={() => { void run('Retaking…', () => append(false, true)); }} /></Row>
      <Row><Action title="Move earlier" disabled={pageIndex === 0} onPress={() => { void run('Reordering…', async () => { const ids = [...doc.pageIds]; [ids[pageIndex-1], ids[pageIndex]] = [ids[pageIndex]!, ids[pageIndex-1]!]; setDoc(await scanner.reorderPages(id, doc.revision, ids)); setPageIndex(pageIndex-1); }); }} /><Action title="Move later" disabled={pageIndex >= doc.pages.length-1} onPress={() => { void run('Reordering…', async () => { const ids = [...doc.pageIds]; [ids[pageIndex], ids[pageIndex+1]] = [ids[pageIndex+1]!, ids[pageIndex]!]; setDoc(await scanner.reorderPages(id, doc.revision, ids)); setPageIndex(pageIndex+1); }); }} /><Action title="Remove page" danger disabled={doc.pages.length === 1} onPress={() => Alert.alert('Remove this page?', 'The other pages are kept.', [{ text: 'Cancel', style: 'cancel' }, { text: 'Remove', style: 'destructive', onPress: () => { void run('Removing…', async () => { setDoc(await scanner.removePage(id, doc.revision, page.id)); setPageIndex(Math.max(0,pageIndex-1)); }); } }])} /></Row>
      {doc.mode === 'id' && doc.pages.length === 2 && <Action title="Compose front and back on one page" onPress={() => { void run('Composing ID…', async () => { setDoc(await scanner.composeIDDocument(id, doc.revision)); setPageIndex(0); }); }} />}
      {doc.idSourcePages && <Action title="Return to editable ID sides" onPress={() => { void run('Restoring ID sides…', async () => { setDoc(await scanner.restoreIDSides(id, doc.revision)); setPageIndex(0); }); }} />}
    </>}
    <Text style={{ color: c.text, fontSize: 20, fontWeight: '600' }}>Recognized text</Text>
    <Text selectable style={{ color: c.text, fontSize: 17 }}>{page.ocr.status === 'ready' ? page.ocr.lines.map(line => line.text).join('\n') || 'No text detected on this page.' : page.ocr.status === 'failed' ? 'Recognition failed. Your page is safe; retry recognition.' : 'Not recognized for this page revision.'}</Text>
    <Row><Action title="Preview PDF" disabled={busy} onPress={() => requestExport(true)} /><Action title="Share PDF" disabled={busy} onPress={() => requestExport(false)} /><Action title="Share page image" disabled={busy} onPress={() => { void run('Sharing page…', async () => { await Sharing.shareAsync(page.imageUri, { mimeType: 'image/jpeg' }); }); }} /></Row>
    {!doc.saved && <Action title="Discard draft" danger disabled={busy} onPress={() => Alert.alert('Discard this draft?', 'Captured pages in this draft will be deleted.', [{ text: 'Keep', style: 'cancel' }, { text: 'Discard', style: 'destructive', onPress: () => { void run('Discarding…', async () => { await scanner.discardDraft(id); router.back(); }); } }])} />}
  </ScrollView>;
}
