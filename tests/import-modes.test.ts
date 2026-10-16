import assert from 'node:assert/strict';
import test from 'node:test';
import * as subject from '../src/capture/selection.ts';

test('two documents never silently select ID mode; invalid assets fail before creating a draft', () => {
  assert.equal(typeof (subject as any).validateSelection, 'function', 'validateSelection must be implemented');
  const validate = (subject as any).validateSelection;
  assert.deepEqual(validate('document', ['file:///a.jpg','file:///b.jpg']), ['file:///a.jpg','file:///b.jpg']);
  assert.deepEqual(validate('id', ['file:///front.jpg','file:///back.jpg']), ['file:///front.jpg','file:///back.jpg']);
  assert.throws(() => validate('id', ['file:///front.jpg']));
  assert.throws(() => validate('photo', ['file:///good.jpg','']));
  assert.throws(() => validate('document', ['https://example.com/image.jpg']));
  assert.throws(() => validate('document', []));
});
