import type { Document, Mode } from '../scanner/types.ts';

export function queryDocuments(documents: Document[], query: { text: string; mode?: Mode; sort: 'name' | 'date'; descending: boolean }): Document[] {
  const needle = query.text.trim().toLocaleLowerCase();
  return documents.filter(doc => {
    const date = new Date(doc.updatedAt);
    const dateText = `${String(date.getDate()).padStart(2, '0')}-${String(date.getMonth() + 1).padStart(2, '0')}-${date.getFullYear()}`;
    const text = [doc.name, doc.updatedAt, dateText, ...doc.pages.flatMap(page => page.ocr.status === 'ready' ? page.ocr.lines.map(line => line.text) : [])].join(' ').toLocaleLowerCase();
    return (!query.mode || doc.mode === query.mode) && text.includes(needle);
  }).sort((a, b) => {
    const order = query.sort === 'name' ? a.name.localeCompare(b.name) : a.updatedAt.localeCompare(b.updatedAt);
    return (query.descending ? -order : order) || a.id.localeCompare(b.id);
  });
}
