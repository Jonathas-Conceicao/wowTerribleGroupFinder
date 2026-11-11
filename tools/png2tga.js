// Converts a PNG to an uncompressed 32-bit TGA (the in-game addon icon).
//
// Usage: node tools/png2tga.js <in.png> <out.tga>
//
// Supported input: 8-bit, non-interlaced PNG, colour type 3 (palette, with
// optional tRNS alpha), 2 (RGB) or 6 (RGBA). Output: 18-byte header
// (image type 2, 32 bpp, descriptor 0x28 = top-left origin, 8 alpha bits),
// then BGRA pixels, rows top to bottom, straight alpha.
// Node built-ins only; dev tool, never shipped.

'use strict';

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

function decodePng(buf) {
  if (buf.length < 8 || !buf.subarray(0, 8).equals(SIGNATURE)) {
    throw new Error('not a PNG file (bad signature)');
  }
  let pos = 8;
  let ihdr = null;
  let plte = null;
  let trns = null;
  const idat = [];
  let sawEnd = false;
  while (pos + 8 <= buf.length) {
    const len = buf.readUInt32BE(pos);
    const type = buf.toString('latin1', pos + 4, pos + 8);
    const start = pos + 8;
    if (start + len + 4 > buf.length) throw new Error('truncated PNG chunk ' + type);
    const data = buf.subarray(start, start + len);
    pos = start + len + 4;
    if (type === 'IHDR') ihdr = data;
    else if (type === 'PLTE') plte = data;
    else if (type === 'tRNS') trns = data;
    else if (type === 'IDAT') idat.push(data);
    else if (type === 'IEND') { sawEnd = true; break; }
  }
  if (!ihdr || ihdr.length < 13) throw new Error('missing IHDR');
  if (!sawEnd) throw new Error('missing IEND');
  const w = ihdr.readUInt32BE(0);
  const h = ihdr.readUInt32BE(4);
  const depth = ihdr[8];
  const ctype = ihdr[9];
  const interlace = ihdr[12];
  if (depth !== 8) throw new Error('unsupported bit depth ' + depth);
  if (interlace !== 0) throw new Error('unsupported interlace method ' + interlace);
  if (ctype !== 2 && ctype !== 3 && ctype !== 6) throw new Error('unsupported colour type ' + ctype);
  if (ctype === 3 && !plte) throw new Error('palette PNG without PLTE');
  if (w === 0 || h === 0 || w > 4096 || h > 4096) throw new Error('unsupported size ' + w + 'x' + h);
  if (idat.length === 0) throw new Error('missing IDAT');

  const bpp = ctype === 3 ? 1 : ctype === 2 ? 3 : 4;
  const stride = w * bpp;
  const raw = zlib.inflateSync(Buffer.concat(idat));
  if (raw.length !== (stride + 1) * h) throw new Error('unexpected decoded data size ' + raw.length);

  const px = Buffer.alloc(stride * h);
  for (let y = 0; y < h; y++) {
    const filter = raw[y * (stride + 1)];
    const src = y * (stride + 1) + 1;
    const dst = y * stride;
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? px[dst + x - bpp] : 0;
      const b = y > 0 ? px[dst - stride + x] : 0;
      const c = x >= bpp && y > 0 ? px[dst - stride + x - bpp] : 0;
      let v = raw[src + x];
      switch (filter) {
        case 0: break;
        case 1: v += a; break;
        case 2: v += b; break;
        case 3: v += (a + b) >> 1; break;
        case 4: {
          const p = a + b - c;
          const pa = Math.abs(p - a);
          const pb = Math.abs(p - b);
          const pc = Math.abs(p - c);
          v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
          break;
        }
        default: throw new Error('unsupported filter type ' + filter);
      }
      px[dst + x] = v & 0xff;
    }
  }

  const rgba = Buffer.alloc(w * h * 4);
  for (let i = 0; i < w * h; i++) {
    let r, g, b, a;
    if (ctype === 3) {
      const idx = px[i];
      if (idx * 3 + 2 >= plte.length) throw new Error('palette index ' + idx + ' out of range');
      r = plte[idx * 3]; g = plte[idx * 3 + 1]; b = plte[idx * 3 + 2];
      a = trns && idx < trns.length ? trns[idx] : 255;
    } else if (ctype === 2) {
      r = px[i * 3]; g = px[i * 3 + 1]; b = px[i * 3 + 2]; a = 255;
    } else {
      r = px[i * 4]; g = px[i * 4 + 1]; b = px[i * 4 + 2]; a = px[i * 4 + 3];
    }
    rgba[i * 4] = r; rgba[i * 4 + 1] = g; rgba[i * 4 + 2] = b; rgba[i * 4 + 3] = a;
  }
  return { width: w, height: h, rgba };
}

function writeTga(w, h, rgba) {
  const out = Buffer.alloc(18 + w * h * 4);
  out[2] = 2;
  out.writeUInt16LE(w, 12);
  out.writeUInt16LE(h, 14);
  out[16] = 32;
  out[17] = 0x28;
  for (let i = 0; i < w * h; i++) {
    out[18 + i * 4] = rgba[i * 4 + 2];
    out[18 + i * 4 + 1] = rgba[i * 4 + 1];
    out[18 + i * 4 + 2] = rgba[i * 4];
    out[18 + i * 4 + 3] = rgba[i * 4 + 3];
  }
  return out;
}

module.exports = { decodePng, writeTga };

if (require.main === module) {
  try {
    const [inPath, outPath] = process.argv.slice(2);
    if (!inPath || !outPath) throw new Error('usage: node tools/png2tga.js <in.png> <out.tga>');
    const img = decodePng(fs.readFileSync(inPath));
    const tga = writeTga(img.width, img.height, img.rgba);
    fs.mkdirSync(path.dirname(path.resolve(outPath)), { recursive: true });
    fs.writeFileSync(outPath, tga);
    console.log('wrote ' + outPath + ' ' + img.width + 'x' + img.height + ' ' + tga.length + ' bytes');
  } catch (err) {
    console.error('png2tga: ' + err.message);
    process.exit(1);
  }
}
