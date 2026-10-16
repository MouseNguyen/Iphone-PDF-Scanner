import assert from 'node:assert/strict';
import test from 'node:test';
import * as subject from '../src/document/geometry.ts';

test('fit contains portrait and landscape images without clipping or distortion', () => {
  assert.equal(typeof (subject as any).fitRect, 'function', 'fitRect must be implemented');
  const fit = (subject as any).fitRect;
  assert.deepEqual(fit(200, 100, 600, 800), { x: 0, y: 250, width: 600, height: 300 });
  assert.deepEqual(fit(100, 200, 600, 800), { x: 100, y: 0, width: 400, height: 800 });
  assert.throws(() => fit(0, 10, 600, 800));
});

test('manual crop rejects crossed, degenerate, out-of-bounds and nonfinite corners', () => {
  assert.equal(typeof (subject as any).validQuad, 'function', 'validQuad must be implemented');
  const valid = (subject as any).validQuad;
  assert.equal(valid([{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 1, y: 1 }, { x: 0, y: 1 }]), true);
  assert.equal(valid([{ x: 0, y: 0 }, { x: 1, y: 1 }, { x: 1, y: 0 }, { x: 0, y: 1 }]), false);
  assert.equal(valid(Array(4).fill({ x: 0, y: 0 })), false);
  assert.equal(valid([{ x: NaN, y: 0 }, { x: 1, y: 0 }, { x: 1, y: 1 }, { x: 0, y: 1 }]), false);
});
