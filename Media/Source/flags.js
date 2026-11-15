// Draws the region flags (Media/Textures/flag_us.tga, flag_au.tga): 64x64 canvas, the flag
// 64x40 in rows 12-51 (the rest transparent), shown at 16x10. Run: node Media/Source/flags.js
const fs = require('fs');
const path = require('path');

const W = 64, H = 64, TOP = 12, FH = 40;

function canvas() {
  return Buffer.alloc(W * H * 4); // BGRA, transparent
}

function put(buf, x, y, [r, g, b, a = 255]) {
  if (x < 0 || x >= W || y < 0 || y >= FH) return;
  const i = ((y + TOP) * W + x) * 4;
  buf[i] = b; buf[i + 1] = g; buf[i + 2] = r; buf[i + 3] = a;
}

function dot(buf, cx, cy, rad, color) {
  for (let y = Math.floor(cy - rad); y <= Math.ceil(cy + rad); y++)
    for (let x = Math.floor(cx - rad); x <= Math.ceil(cx + rad); x++)
      if ((x - cx) ** 2 + (y - cy) ** 2 <= rad * rad) put(buf, x, y, color);
}

function border(buf) {
  const c = [20, 20, 20, 255];
  for (let x = 0; x < W; x++) { put(buf, x, 0, c); put(buf, x, FH - 1, c); }
  for (let y = 0; y < FH; y++) { put(buf, 0, y, c); put(buf, W - 1, y, c); }
}

function tga(buf, file) {
  const head = Buffer.alloc(18);
  head[2] = 2; // uncompressed true colour
  head.writeUInt16LE(W, 12);
  head.writeUInt16LE(H, 14);
  head[16] = 32;
  head[17] = 0x28; // top-left origin, 8 alpha bits
  fs.writeFileSync(file, Buffer.concat([head, buf]));
}

const RED = [178, 34, 52], WHITE = [255, 255, 255], US_BLUE = [60, 59, 110];
const AU_BLUE = [1, 33, 105], UJ_RED = [200, 16, 46];

function us() {
  const buf = canvas();
  for (let i = 0; i < 13; i++) {
    const y0 = Math.floor(i * FH / 13), y1 = Math.floor((i + 1) * FH / 13);
    for (let y = y0; y < y1; y++) for (let x = 0; x < W; x++) put(buf, x, y, i % 2 ? WHITE : RED);
  }
  const cw = 28, ch = Math.floor(7 * FH / 13);
  for (let y = 0; y < ch; y++) for (let x = 0; x < cw; x++) put(buf, x, y, US_BLUE);
  for (let r = 0; r < 5; r++)
    for (let c = 0; c < 6; c++) {
      const x = 3 + c * 4.4 + (r % 2 ? 2.2 : 0), y = 2.5 + r * 4;
      if (x < cw - 2) dot(buf, x, y, 1.1, WHITE);
    }
  border(buf);
  return buf;
}

function au() {
  const buf = canvas();
  for (let y = 0; y < FH; y++) for (let x = 0; x < W; x++) put(buf, x, y, AU_BLUE);
  // Union Jack in the canton (32x20).
  const cw = 32, ch = 20, len = Math.hypot(cw, ch);
  for (let y = 0; y < ch; y++)
    for (let x = 0; x < cw; x++) {
      const d1 = Math.abs(ch * x - cw * y) / len, d2 = Math.abs(ch * x + cw * y - cw * ch) / len;
      const d = Math.min(d1, d2);
      if (d < 3) put(buf, x, y, WHITE);
      if (d < 1.2) put(buf, x, y, UJ_RED);
      if (Math.abs(x - 15.5) < 4 || Math.abs(y - 9.5) < 4) put(buf, x, y, WHITE);
      if (Math.abs(x - 15.5) < 2 || Math.abs(y - 9.5) < 2) put(buf, x, y, UJ_RED);
    }
  // Commonwealth star under the canton, Southern Cross on the fly.
  dot(buf, 16, 30, 4, WHITE);
  for (const [x, y, r] of [[48, 33, 2.6], [39, 19, 2.4], [48, 7, 2.4], [56, 16, 2.2], [52, 24, 1.4]])
    dot(buf, x, y, r, WHITE);
  border(buf);
  return buf;
}

const out = path.join(__dirname, '..', 'Textures');
tga(us(), path.join(out, 'flag_us.tga'));
tga(au(), path.join(out, 'flag_au.tga'));
console.log('wrote flag_us.tga, flag_au.tga');
