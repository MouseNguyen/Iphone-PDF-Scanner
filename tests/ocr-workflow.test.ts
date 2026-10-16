import assert from 'node:assert/strict';
import test from 'node:test';
import * as subject from '../src/document/workflow.ts';

test('recognition is sequential, retains failed pages and stops after cancellation', async () => {
  assert.equal(typeof (subject as any).recognizeDocument, 'function', 'recognizeDocument must be implemented');
  const run = (subject as any).recognizeDocument;
  const doc = { id: 'doc', pages: [{ id: 'a', revision: 1, ocr: { status: 'pending' } }, { id: 'b', revision: 2, ocr: { status: 'pending' } }] };
  let active = 0;
  let peak = 0;
  const calls: string[] = [];
  const updates: string[] = [];
  await run({ recognizePage: async (_d: string, id: string) => {
    active++; peak = Math.max(peak, active); calls.push(id);
    await new Promise(resolve => setTimeout(resolve, 2)); active--;
    if (id === 'a') throw new Error('processing: OCR failed');
    return { id };
  } }, doc, () => false, (id: string) => updates.push(id));
  assert.equal(peak, 1);
  assert.deepEqual(calls, ['a', 'b']);
  assert.deepEqual(updates, ['a', 'b']);
  calls.length = 0;
  await run({ recognizePage: async (_d: string, id: string) => calls.push(id) }, doc, () => true, () => {});
  assert.deepEqual(calls, []);
});
