import assert from 'node:assert/strict';
import test from 'node:test';
import * as subject from '../src/library/query.ts';

test('query searches recognized text and preserves explicit category and stable ordering', () => {
  assert.equal(typeof (subject as any).queryDocuments, 'function', 'queryDocuments must be implemented');
  const documents = [
    { id: 'b', name: 'Receipt', mode: 'document', updatedAt: '2026-10-16T10:00:00Z', pages: [{ ocr: { status: 'ready', lines: [{ text: 'Coffee beans' }] } }] },
    { id: 'a', name: 'Receipt', mode: 'photo', updatedAt: '2026-10-16T10:00:00Z', pages: [] },
    { id: 'c', name: 'Invoice', mode: 'document', updatedAt: '2026-10-15T10:00:00Z', pages: [] },
  ];
  const query = (subject as any).queryDocuments;
  assert.deepEqual(query(documents, { text: 'COFFEE', sort: 'date', descending: true }).map((d: any) => d.id), ['b']);
  assert.deepEqual(query(documents, { text: '', mode: 'document', sort: 'name', descending: false }).map((d: any) => d.id), ['c', 'b']);
  assert.deepEqual(query(documents, { text: 'receipt', sort: 'name', descending: false }).map((d: any) => d.id), ['a', 'b']);
  assert.deepEqual(documents.map(d => d.id), ['b', 'a', 'c']);
});
