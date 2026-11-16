// Dev-only converter: the author's flag PNGs (Media/Source/flags/flag_<cc>.png,
// from flagpedia.net) -> Media/Textures/flag_<cc>.tga, 32-bit uncompressed,
// top-left origin, a 64x32 canvas with the flag copied 1:1 at the top-left and
// the rest transparent. It converts pixels only and draws nothing.
// Run from the repo root: node Media/Source/png2tga.js
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const W = 64;
const H = 32;
const SRC = path.join(__dirname, "flags");
const DST = path.join(__dirname, "..", "Textures");

function decode(buf) {
  const sig = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  for (let i = 0; i < 8; i++) if (buf[i] !== sig[i]) throw new Error("not a PNG");
  let o = 8;
  let ih, plte, trns;
  const idat = [];
  while (o < buf.length) {
    const len = buf.readUInt32BE(o);
    const type = buf.toString("latin1", o + 4, o + 8);
    const d = buf.subarray(o + 8, o + 8 + len);
    if (type === "IHDR") {
      ih = { w: d.readUInt32BE(0), h: d.readUInt32BE(4), bd: d[8], ct: d[9], cm: d[10], fm: d[11], il: d[12] };
    } else if (type === "PLTE") plte = d;
    else if (type === "tRNS") trns = d;
    else if (type === "IDAT") idat.push(d);
    else if (type === "IEND") break;
    o += 12 + len;
  }
  if (!ih || !plte) throw new Error("missing IHDR or PLTE");
  if (ih.ct !== 3) throw new Error("only palette PNGs (colour type 3)");
  if (![1, 2, 4, 8].includes(ih.bd)) throw new Error("bad bit depth " + ih.bd);
  if (ih.cm !== 0 || ih.fm !== 0 || ih.il !== 0) throw new Error("only non-interlaced, standard PNGs");
  if (ih.w > W || ih.h > H) throw new Error("larger than " + W + "x" + H);

  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = Math.ceil((ih.w * ih.bd) / 8);
  if (raw.length !== ih.h * (1 + stride)) throw new Error("unexpected inflated length");

  const rgba = Buffer.alloc(ih.w * ih.h * 4);
  let prev = Buffer.alloc(stride);
  for (let y = 0; y < ih.h; y++) {
    const f = raw[y * (stride + 1)];
    const line = Buffer.from(raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1)));
    for (let i = 0; i < stride; i++) {
      const a = i >= 1 ? line[i - 1] : 0; // bpp is 1 for palette data
      const b = prev[i];
      const c = i >= 1 ? prev[i - 1] : 0;
      let p;
      switch (f) {
        case 0: p = 0; break;
        case 1: p = a; break;
        case 2: p = b; break;
        case 3: p = (a + b) >> 1; break;
        case 4: {
          const q = a + b - c;
          const pa = Math.abs(q - a);
          const pb = Math.abs(q - b);
          const pc = Math.abs(q - c);
          p = pa <= pb && pa <= pc ? a : pb <= pc ? b : c; // Paeth, ties a, b, c
          break;
        }
        default: throw new Error("bad filter " + f);
      }
      line[i] = (line[i] + p) & 255;
    }
    for (let x = 0; x < ih.w; x++) {
      const bit = x * ih.bd;
      const byte = line[bit >> 3];
      const idx = ih.bd === 8 ? byte : (byte >> (8 - ih.bd - (bit & 7))) & ((1 << ih.bd) - 1);
      if (idx * 3 + 2 >= plte.length) throw new Error("palette index out of range");
      const j = (y * ih.w + x) * 4;
      rgba[j] = plte[idx * 3];
      rgba[j + 1] = plte[idx * 3 + 1];
      rgba[j + 2] = plte[idx * 3 + 2];
      rgba[j + 3] = trns && idx < trns.length ? trns[idx] : 255; // tRNS alpha
    }
    prev = line;
  }
  return { w: ih.w, h: ih.h, rgba };
}

function toTga(img) {
  const head = Buffer.alloc(18);
  head[2] = 2;
  head.writeUInt16LE(W, 12);
  head.writeUInt16LE(H, 14);
  head[16] = 32;
  head[17] = 0x28;
  const px = Buffer.alloc(W * H * 4);
  for (let y = 0; y < img.h; y++) {
    for (let x = 0; x < img.w; x++) {
      const s = (y * img.w + x) * 4;
      const d = (y * W + x) * 4;
      px[d] = img.rgba[s + 2];
      px[d + 1] = img.rgba[s + 1];
      px[d + 2] = img.rgba[s];
      px[d + 3] = img.rgba[s + 3];
    }
  }
  return Buffer.concat([head, px]);
}

const files = fs.readdirSync(SRC).filter((n) => /^flag_.+\.png$/.test(n)).sort();
const out = [];
for (const name of files) {
  const img = decode(fs.readFileSync(path.join(SRC, name)));
  out.push([name.replace(/\.png$/, ".tga"), toTga(img), name.slice(5, -4), img]);
}
for (const [tga, data, cc, img] of out) {
  fs.writeFileSync(path.join(DST, tga), data);
  console.log(cc, img.w + "x" + img.h, "-> Media/Textures/" + tga);
}
