// Shrinks every picture before upload so storage fills slowly while photos
// still look sharp on a phone: longest side at most 1280 px (logos 800 px),
// JPEG quality 0.8 — usually 120–350 KB instead of several MB. Pictures with
// transparency (logos) stay PNG. Already-small files are sent unchanged.
const MAX_SIDE = 1280;
const LOGO_SIDE = 800;
const SMALL = 250_000;

export async function compressImage(file, {logo = false} = {}) {
  if (!(file instanceof Blob) || !/^image\/(jpeg|png|webp|gif|bmp)$/.test(file.type)) return file;
  try {
    const bmp = await createImageBitmap(file);
    const limit = logo ? LOGO_SIDE : MAX_SIDE;
    const big = Math.max(bmp.width, bmp.height);
    if (file.size <= SMALL && big <= limit && file.type !== 'image/bmp') { bmp.close?.(); return file; }
    const k = Math.min(1, limit / big);
    const c = document.createElement('canvas');
    c.width = Math.max(1, Math.round(bmp.width * k));
    c.height = Math.max(1, Math.round(bmp.height * k));
    const g = c.getContext('2d');
    g.imageSmoothingQuality = 'high';
    g.drawImage(bmp, 0, 0, c.width, c.height);
    bmp.close?.();
    let alpha = false;
    if (file.type === 'image/png' || file.type === 'image/webp' || file.type === 'image/gif') {
      const px = g.getImageData(0, 0, c.width, c.height).data;
      for (let i = 3; i < px.length; i += 4 * 61) if (px[i] < 250) { alpha = true; break; }
    }
    const type = alpha ? 'image/png' : 'image/jpeg';
    if (!alpha) { // JPEG has no transparency: paint white behind.
      const bg = document.createElement('canvas'); bg.width = c.width; bg.height = c.height;
      const b = bg.getContext('2d'); b.fillStyle = '#fff'; b.fillRect(0, 0, bg.width, bg.height); b.drawImage(c, 0, 0);
      const blob = await new Promise((r) => bg.toBlob(r, type, 0.8));
      if (!blob || blob.size >= file.size) return file.type === 'image/bmp' && blob ? asFile(blob, file, '.jpg', type) : file;
      return asFile(blob, file, '.jpg', type);
    }
    const blob = await new Promise((r) => c.toBlob(r, type));
    if (!blob || blob.size >= file.size) return file;
    return asFile(blob, file, '.png', type);
  } catch { return file; }
}

function asFile(blob, original, ext, type) {
  const name = (original.name || 'image').replace(/\.\w+$/, '') + ext;
  return new File([blob], name, {type});
}
