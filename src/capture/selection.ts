import type { Mode } from '../scanner/types.ts';

export function validateSelection(mode: Mode, imageUris: string[]): string[] {
  if (!imageUris.length || imageUris.some(uri => !uri.startsWith('file:///'))) throw new Error('One or more selected images are unavailable. Download cloud-only photos in Photos, then retry.');
  if (mode === 'id' && imageUris.length !== 2) throw new Error('ID card mode needs exactly two images: front first, then back.');
  return [...imageUris];
}
