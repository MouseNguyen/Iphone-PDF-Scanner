import type { Document, ScannerAPI } from '../scanner/types.ts';

export async function recognizeDocument(api: Pick<ScannerAPI, 'recognizePage'>, document: Document, cancelled: () => boolean, onPage: (pageId: string, error?: unknown) => void): Promise<void> {
  for (const page of document.pages) {
    if (cancelled()) return;
    if (page.ocr.status === 'ready' && page.ocr.revision === page.revision) continue;
    try {
      await api.recognizePage(document.id, page.id, page.revision);
      if (!cancelled()) onPage(page.id);
    } catch (error) {
      if (!cancelled()) onPage(page.id, error);
    }
  }
}
