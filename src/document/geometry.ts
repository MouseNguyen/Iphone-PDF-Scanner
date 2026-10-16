import type { Point } from '../scanner/types.ts';

export function fitRect(width: number, height: number, pageWidth: number, pageHeight: number) {
  if (![width, height, pageWidth, pageHeight].every(n => Number.isFinite(n) && n > 0)) throw new Error('Invalid image dimensions');
  const scale = Math.min(pageWidth / width, pageHeight / height);
  return { x: (pageWidth - width * scale) / 2, y: (pageHeight - height * scale) / 2, width: width * scale, height: height * scale };
}

export function validQuad(points: Point[]): boolean {
  if (points.length !== 4 || points.some(p => !Number.isFinite(p.x) || !Number.isFinite(p.y) || p.x < 0 || p.x > 1 || p.y < 0 || p.y > 1)) return false;
  return points.every((a, i) => {
    const b = points[(i + 1) % 4]!;
    const c = points[(i + 2) % 4]!;
    return (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x) > 0.0001;
  });
}
