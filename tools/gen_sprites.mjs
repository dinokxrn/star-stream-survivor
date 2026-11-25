#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";

const outDir = path.resolve("godot_project/assets/sprites");
fs.mkdirSync(outDir, { recursive: true });

// Minimal PNG encoder (RGBA 8-bit)
const crcTable = new Uint32Array(256);
for (let n = 0; n < 256; n++) {
  let c = n;
  for (let k = 0; k < 8; k++) c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
  crcTable[n] = c >>> 0;
}
function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = crcTable[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const t = Buffer.from(type, "ascii");
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([t, data])), 0);
  return Buffer.concat([len, t, data, crc]);
}
function savePng(filename, w, h, pixels) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    pixels.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  }
  const idat = zlib.deflateSync(raw, { level: 9 });
  const png = Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk("IHDR", ihdr),
    chunk("IDAT", idat),
    chunk("IEND", Buffer.alloc(0)),
  ]);
  fs.writeFileSync(path.join(outDir, filename), png);
}

class Canvas {
  constructor(w, h) {
    this.w = w;
    this.h = h;
    this.buf = Buffer.alloc(w * h * 4);
  }
  set(x, y, hex, a = 255) {
    x = Math.floor(x); y = Math.floor(y);
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
    const r = (hex >> 16) & 255, g = (hex >> 8) & 255, b = hex & 255;
    const i = (y * this.w + x) * 4;
    if (a >= 255 || this.buf[i + 3] === 0) {
      this.buf[i] = r; this.buf[i + 1] = g; this.buf[i + 2] = b; this.buf[i + 3] = a;
    } else {
      const sa = a / 255;
      this.buf[i] = Math.round(r * sa + this.buf[i] * (1 - sa));
      this.buf[i + 1] = Math.round(g * sa + this.buf[i + 1] * (1 - sa));
      this.buf[i + 2] = Math.round(b * sa + this.buf[i + 2] * (1 - sa));
      this.buf[i + 3] = Math.min(255, Math.round(a + this.buf[i + 3] * (1 - sa)));
    }
  }
  rect(x, y, w, h, hex, a = 255) {
    for (let yy = y; yy < y + h; yy++)
      for (let xx = x; xx < x + w; xx++) this.set(xx, yy, hex, a);
  }
  outline(x0, y0, w, h, col = 0x0b0f19) {
    const copy = Buffer.from(this.buf);
    const has = (x, y) => {
      if (x < x0 || y < y0 || x >= x0 + w || y >= y0 + h) return false;
      return copy[(y * this.w + x) * 4 + 3] > 20;
    };
    for (let y = y0; y < y0 + h; y++) {
      for (let x = x0; x < x0 + w; x++) {
        if (!has(x, y) && (has(x - 1, y) || has(x + 1, y) || has(x, y - 1) || has(x, y + 1))) {
          this.set(x, y, col, 255);
        }
      }
    }
  }
}

function shadeHex(hex, factor) {
  const r = Math.min(255, Math.max(0, Math.round(((hex >> 16) & 255) * factor)));
  const g = Math.min(255, Math.max(0, Math.round(((hex >> 8) & 255) * factor)));
  const b = Math.min(255, Math.max(0, Math.round((hex & 255) * factor)));
  return (r << 16) | (g << 8) | b;
}

// High-detail 32x40 volumetric 3-tone shaded humanoid renderer with expressive motion
function drawHumanoid(c, fx, opts) {
  const {
    hair, skin, coat, coatHi, shirt, pants, accent,
    step = 0, crouch = 0, attack = 0, dash = false, hurt = false,
    tall = 0, hairStyle = "short", beard = false, cap = 0,
    lean = 0
  } = opts;

  const hairHi = shadeHex(hair, 1.38);
  const hairLo = shadeHex(hair, 0.68);
  const skinHi = shadeHex(skin, 1.12);
  const skinLo = shadeHex(skin, 0.80);
  const coatLo = shadeHex(coat, 0.66);
  const pantsHi = shadeHex(pants, 1.25);
  const pantsLo = shadeHex(pants, 0.70);

  const ox = fx + (dash ? 3 : 0) + lean;
  const oy = 2 + crouch - tall;

  // Ground contact shadow
  c.rect(fx + 9, 37, 14, 2, 0x050811, 130);

  // Legs with wide stride on run/attack
  const lx = step === 1 ? -5 : (step === 2 ? 4 : -1);
  const rx = step === 1 ? 4 : (step === 2 ? -5 : 1);
  const lLift = step === 1 ? -2 : 0;
  const rLift = step === 2 ? -2 : 0;
  const legH = Math.max(6, 10 + tall);
  const legY = 26 + oy;
  // Back leg (darker)
  c.rect(ox + 11 + lx, legY + lLift, 4, legH, pantsLo);
  c.rect(ox + 11 + lx, legY + lLift, 2, legH - 1, pants);
  c.rect(ox + 10 + lx, legY + lLift + legH - 2, 5, 3, 0x161b26);
  c.rect(ox + 11 + lx, legY + lLift + legH - 2, 3, 1, 0x334155);
  // Front leg (lit)
  c.rect(ox + 16 + rx, legY + rLift, 4, legH, pants);
  c.rect(ox + 16 + rx, legY + rLift, 2, legH - 1, pantsHi);
  c.rect(ox + 16 + rx, legY + rLift + legH - 2, 5, 3, 0x1e2430);
  c.rect(ox + 17 + rx, legY + rLift + legH - 2, 3, 1, 0x475569);

  // Back arm swings opposite to front leg during run!
  const backArmX = step === 1 ? 15 : (step === 2 ? 6 : 8);
  const backArmY = step === 1 ? 16 : (step === 2 ? 17 : 17);
  c.rect(ox + backArmX, backArmY + oy, 3, 8, coatLo);
  c.rect(ox + backArmX, backArmY + 7 + oy, 2, 2, skinLo);

  // Torso / Layered Coat with swaying coat tails
  const torsoH = Math.max(9, 12 + tall);
  const torsoY = 15 + oy;
  const tailShift = dash ? -4 : (step === 1 ? -3 : (step === 2 ? -2 : 0));
  c.rect(ox + 9 + tailShift, torsoY + torsoH - 3, 6, 5, coatLo);
  c.rect(ox + 10 + tailShift, torsoY + torsoH - 3, 4, 4, coat);

  // Main coat body
  c.rect(ox + 10, torsoY, 12, torsoH, coat);
  c.rect(ox + 11, torsoY, 5, torsoH - 1, coatHi); // top-left key light
  c.rect(ox + 19, torsoY + 1, 3, torsoH - 1, coatLo); // right core shadow
  // Inner shirt & collar V
  c.rect(ox + 14, torsoY, 5, Math.min(8, torsoH - 2), shirt);
  c.rect(ox + 14, torsoY, 2, Math.min(7, torsoH - 3), shadeHex(shirt, 1.08));
  if (accent) {
    c.rect(ox + 16, torsoY + 1, 2, Math.min(7, torsoH - 3), accent);
    c.set(ox + 16, torsoY + 1, shadeHex(accent, 1.35));
  }
  // Belt + metallic buckle
  c.rect(ox + 10, torsoY + torsoH - 3, 12, 2, 0x111827);
  c.rect(ox + 15, torsoY + torsoH - 3, 3, 2, 0xfacc15);

  // Neck + chin cast shadow
  c.rect(ox + 14, 13 + oy, 4, 2, skinLo);

  // Rounded sculpted Head (3-tone skin shading)
  c.rect(ox + 11, 5 + oy, 10, 9, skin);
  c.rect(ox + 12, 4 + oy, 8, 10, skin);
  c.rect(ox + 12, 5 + oy, 4, 5, skinHi); // forehead & cheek light
  c.rect(ox + 11, 11 + oy, 10, 2, skinLo); // jaw shadow
  // Ear
  c.rect(ox + 10, 9 + oy, 2, 3, skinLo);

  // Hair styles with specular highlight bands & shadow tips
  c.rect(ox + 10, 3 + oy, 12, 4, hair);
  c.rect(ox + 11, 2 + oy, 9, 3, hair);
  c.rect(ox + 12, 3 + oy, 5, 2, hairHi); // glossy hair highlight
  if (hairStyle === "long") {
    c.rect(ox + 8, 5 + oy, 4, 15, hair);
    c.rect(ox + 9, 6 + oy, 2, 11, hairHi);
    c.rect(ox + 8, 15 + oy, 3, 5, hairLo);
    c.rect(ox + 20, 6 + oy, 2, 7, hairLo);
  } else if (hairStyle === "ponytail") {
    c.rect(ox + 7, 5 + oy, 4, 10, hair);
    c.rect(ox + 5, 9 + oy, 3, 8, hairLo);
    c.rect(ox + 8, 6 + oy, 2, 6, hairHi);
    c.rect(ox + 9, 6 + oy, 2, 2, accent || 0x38bdf8); // hair tie
  } else if (hairStyle === "pigtails") {
    c.rect(ox + 7, 6 + oy, 3, 10, hair);
    c.rect(ox + 8, 7 + oy, 1, 6, hairHi);
    c.rect(ox + 21, 6 + oy, 3, 10, hairLo);
  } else if (hairStyle === "spiky") {
    c.rect(ox + 9, 0 + oy, 3, 3, hairHi);
    c.rect(ox + 14, 0 + oy, 3, 3, hair);
    c.rect(ox + 18, 1 + oy, 4, 3, hairLo);
  } else if (hairStyle === "bun") {
    c.rect(ox + 6, 3 + oy, 4, 5, hair);
    c.rect(ox + 7, 4 + oy, 2, 2, hairHi);
    c.rect(ox + 9, 6 + oy, 2, 6, hairLo);
  } else {
    c.rect(ox + 9, 5 + oy, 3, 6, hairLo);
    c.rect(ox + 19, 5 + oy, 3, 4, hairLo);
  }
  if (cap) {
    c.rect(ox + 10, 2 + oy, 12, 3, cap);
    c.rect(ox + 11, 2 + oy, 7, 1, shadeHex(cap, 1.3));
    c.rect(ox + 18, 4 + oy, 7, 2, shadeHex(cap, 0.8));
  }
  if (beard) {
    c.rect(ox + 13, 12 + oy, 8, 3, hair);
    c.rect(ox + 15, 13 + oy, 5, 2, hairHi);
  }

  // Expressive Eyes with white specular glint
  const eyeCol = hurt ? 0xef4444 : 0x0f172a;
  c.rect(ox + 17, 8 + oy, 2, 3, eyeCol);
  c.set(ox + 17, 8 + oy, 0xffffff); // eye glint
  c.rect(ox + 16, 7 + oy, 4, 1, hairLo); // eyebrow

  // Front arm & multi-frame weapon / attack poses (wind-up -> strike smear -> follow-through)
  if (attack > 0) {
    if (attack === 10) {
      // Wind-up back (sword/dagger)
      c.rect(ox + 6, 15 + oy, 5, 4, coatLo);
      c.rect(ox + 3, 9 + oy, 2, 9, 0xe2e8f0);
      c.rect(ox + 4, 8 + oy, 1, 9, 0x38bdf8);
    } else if (attack === 1) {
      // Strike 1: Upward diagonal slash smear
      c.rect(ox + 18, 13 + oy, 6, 4, coatHi);
      c.rect(ox + 23, 12 + oy, 3, 3, skinHi);
      c.rect(ox + 24, 3 + oy, 3, 12, 0xe2e8f0);
      c.rect(ox + 26, 2 + oy, 3, 13, 0x38bdf8);
      c.rect(ox + 22, 2 + oy, 5, 2, 0xffffff, 210);
    } else if (attack === 11) {
      // Follow-through high
      c.rect(ox + 17, 11 + oy, 5, 4, coatHi);
      c.rect(ox + 21, 5 + oy, 2, 8, 0x94a3b8);
    } else if (attack === 2) {
      // Strike 2: Wide horizontal cut smear
      c.rect(ox + 19, 16 + oy, 6, 4, coatHi);
      c.rect(ox + 24, 16 + oy, 3, 3, skinHi);
      c.rect(ox + 20, 15 + oy, 11, 3, 0xe2e8f0);
      c.rect(ox + 18, 14 + oy, 13, 2, 0x7dd3fc);
      c.rect(ox + 25, 13 + oy, 6, 1, 0xffffff, 220);
    } else if (attack === 12) {
      // Follow-through low
      c.rect(ox + 18, 19 + oy, 5, 4, coatLo);
      c.rect(ox + 22, 21 + oy, 6, 2, 0x94a3b8);
    } else if (attack === 13) {
      // Overhead raise wind-up
      c.rect(ox + 14, 9 + oy, 4, 7, coatHi);
      c.rect(ox + 14, 1 + oy, 3, 9, 0xe2e8f0);
      c.rect(ox + 16, 0 + oy, 2, 9, 0x38bdf8);
    } else if (attack === 3) {
      // Strike 3 Finisher: Overhead slam with bright arc
      c.rect(ox + 19, 17 + oy, 6, 4, coatHi);
      c.rect(ox + 22, 18 + oy, 8, 7, 0x38bdf8);
      c.rect(ox + 24, 16 + oy, 6, 4, 0xffffff);
      c.rect(ox + 20, 24 + oy, 10, 2, 0x7dd3fc, 220);
    } else if (attack === 14) {
      // Thrust wind-up (pull spear back)
      c.rect(ox + 8, 17 + oy, 6, 4, coatLo);
      c.rect(ox + 3, 18 + oy, 12, 2, 0xe2e8f0);
      c.rect(ox + 15, 17 + oy, 4, 3, 0x38bdf8);
    } else if (attack === 4) {
      // Thrust peak lunge
      c.rect(ox + 18, 16 + oy, 7, 4, coatHi);
      c.rect(ox + 16, 17 + oy, 14, 2, 0xe2e8f0);
      c.rect(ox + 26, 14 + oy, 6, 8, 0x38bdf8);
      c.rect(ox + 28, 16 + oy, 4, 4, 0xffffff);
    } else if (attack === 15) {
      // Heavy wind-up (lift axe/scythe high behind head)
      c.rect(ox + 10, 8 + oy, 4, 8, coatHi);
      c.rect(ox + 6, 1 + oy, 5, 11, 0xf97316);
      c.rect(ox + 4, 0 + oy, 8, 5, 0xfef08a);
    } else if (attack === 5) {
      // Heavy downward cleave smear
      c.rect(ox + 19, 15 + oy, 6, 4, coatHi);
      c.rect(ox + 22, 6 + oy, 5, 18, 0xf97316);
      c.rect(ox + 25, 8 + oy, 5, 16, 0xfef08a);
      c.rect(ox + 23, 22 + oy, 8, 4, 0xffffff, 210);
    } else if (attack === 16) {
      // Spin wind-up (twisted torso)
      c.rect(ox + 5, 16 + oy, 8, 3, 0x38bdf8);
      c.rect(ox + 19, 18 + oy, 7, 3, 0x7dd3fc);
    } else if (attack === 6) {
      // 360 Spin full blade ring
      c.rect(ox + 1, 15 + oy, 11, 4, 0x38bdf8);
      c.rect(ox + 20, 15 + oy, 11, 4, 0x7dd3fc);
      c.rect(ox + 2, 14 + oy, 28, 2, 0xffffff, 220);
      c.rect(ox + 4, 18 + oy, 24, 1, 0x38bdf8, 190);
    } else if (attack === 17) {
      // Magic gather (orb near chest)
      c.rect(ox + 15, 14 + oy, 5, 4, coatHi);
      c.rect(ox + 18, 11 + oy, 5, 5, 0x38bdf8);
      c.rect(ox + 19, 12 + oy, 3, 3, 0xffffff);
    } else if (attack === 7) {
      // Magic release burst
      c.rect(ox + 19, 13 + oy, 6, 4, coatHi);
      c.rect(ox + 23, 8 + oy, 7, 9, 0x38bdf8);
      c.rect(ox + 25, 10 + oy, 4, 5, 0xffffff);
      c.rect(ox + 21, 6 + oy, 10, 2, 0x7dd3fc, 220);
    } else if (attack === 8) {
      // Ranged shoot muzzle flash
      c.rect(ox + 18, 15 + oy, 7, 3, coatHi);
      c.rect(ox + 23, 15 + oy, 5, 3, 0x94a3b8);
      c.rect(ox + 27, 13 + oy, 5, 7, 0xfacc15);
      c.rect(ox + 28, 15 + oy, 3, 3, 0xffffff);
    } else if (attack === 9) {
      // Parry golden barrier stance
      c.rect(ox + 18, 14 + oy, 5, 4, coatHi);
      c.rect(ox + 22, 8 + oy, 3, 19, 0xfacc15);
      c.rect(ox + 25, 7 + oy, 3, 21, 0x38bdf8, 220);
    }
  } else if (dash) {
    c.rect(ox + 7, 18 + oy, 5, 3, coatHi);
    c.rect(ox + 19, 16 + oy, 5, 3, coatHi);
    c.rect(fx + 1, 12 + oy, 8, 2, 0x38bdf8, 210);
    c.rect(fx + 0, 19 + oy, 9, 2, 0x7dd3fc, 210);
    c.rect(fx + 2, 26 + oy, 7, 2, 0x38bdf8, 180);
  } else {
    // Swinging front arm on run, breathing on idle
    const armSwingX = step === 1 ? 6 : (step === 2 ? 15 : 11);
    const armSwingY = step === 1 ? 15 : (step === 2 ? 15 : 16);
    c.rect(ox + armSwingX, armSwingY + oy, 4, 8, coatHi);
    c.rect(ox + armSwingX, armSwingY + 6 + oy, 3, 2, coatLo);
    c.rect(ox + armSwingX + 1, armSwingY + 8 + oy, 3, 2, skinHi);
  }

  c.outline(fx, 0, 32, 40, 0x0b101d);
}

// 1. Generate 10 playable 18-frame character sprite sheets (char_0..char_9) + default player_sheet.png
const PLAYABLE_CHARS = [
  // 0: Male office worker
  { file: "char_0.png", hair: 0x181b26, skin: 0xf1c29b, coat: 0x263247, coatHi: 0x3b4d6b, shirt: 0xe2e8f0, pants: 0x161b26, accent: 0x38bdf8, hairStyle: "short", tall: 0 },
  // 1: Male punk / brawler
  { file: "char_1.png", hair: 0xb91c1c, skin: 0xe6b48a, coat: 0x1f242e, coatHi: 0x374151, shirt: 0xfef08a, pants: 0x111827, accent: 0xf97316, hairStyle: "spiky", tall: 1 },
  // 2: Male long coat (protagonist vibe)
  { file: "char_2.png", hair: 0x0f172a, skin: 0xf6cfb2, coat: 0xe2e8f0, coatHi: 0xffffff, shirt: 0x1e293b, pants: 0x0f172a, accent: 0x38bdf8, hairStyle: "short", tall: 1 },
  // 3: Female college student
  { file: "char_3.png", hair: 0x4a2c1d, skin: 0xf9d5ba, coat: 0xd97757, coatHi: 0xf09d7e, shirt: 0xf8fafc, pants: 0x1e3a5f, accent: 0x38bdf8, hairStyle: "long", tall: 0 },
  // 4: Female kendo swordswoman
  { file: "char_4.png", hair: 0x111827, skin: 0xf5ccb0, coat: 0x1e3a8a, coatHi: 0x2563eb, shirt: 0xf8fafc, pants: 0x0f172a, accent: 0x7dd3fc, hairStyle: "ponytail", tall: 0 },
  // 5: Female starlight mage
  { file: "char_5.png", hair: 0xcbd5e1, skin: 0xfbe0cc, coat: 0x4c1d95, coatHi: 0x7c3aed, shirt: 0xfef08a, pants: 0x1e1b4b, accent: 0xfacc15, hairStyle: "long", tall: 0 },
  // 6: Kid boy (shorter, red cap + yellow hoodie)
  { file: "char_6.png", hair: 0x271c15, skin: 0xf6cfb2, coat: 0xeab308, coatHi: 0xfde047, shirt: 0xffffff, pants: 0x1d4ed8, accent: 0xef4444, hairStyle: "short", tall: -3, cap: 0xdc2626 },
  // 7: Kid girl (shorter, pink pigtails + mint cardigan)
  { file: "char_7.png", hair: 0xec4899, skin: 0xfbe0cc, coat: 0x10b981, coatHi: 0x34d399, shirt: 0xffffff, pants: 0x334155, accent: 0xf472b6, hairStyle: "pigtails", tall: -3 },
  // 8: Elder man (white hair + beard + warm coat)
  { file: "char_8.png", hair: 0xe2e8f0, skin: 0xe0b596, coat: 0x5c4033, coatHi: 0x7c5947, shirt: 0xf1f5f9, pants: 0x292524, accent: 0xf59e0b, hairStyle: "short", tall: 0, beard: true },
  // 9: Elder woman (silver bun + wine cardigan)
  { file: "char_9.png", hair: 0xd1d5db, skin: 0xe8bea0, coat: 0x7f1d45, coatHi: 0x9f2b5a, shirt: 0xfef3c7, pants: 0x1f2937, accent: 0xfbbf24, hairStyle: "bun", tall: -1 },
  // 10: Male athlete (green tracksuit)
  { file: "char_10.png", hair: 0x451a03, skin: 0xebb991, coat: 0x15803d, coatHi: 0x22c55e, shirt: 0xffffff, pants: 0x14532d, accent: 0xfef08a, hairStyle: "spiky", tall: 1 },
  // 11: Male field doctor (white lab coat)
  { file: "char_11.png", hair: 0x1e293b, skin: 0xf6cfb2, coat: 0xe2e8f0, coatHi: 0xffffff, shirt: 0x0ea5e9, pants: 0x334155, accent: 0xef4444, hairStyle: "short", tall: 0 },
  // 12: Male street musician (long dark hair, purple jacket)
  { file: "char_12.png", hair: 0x09090b, skin: 0xf0c4a0, coat: 0x581c87, coatHi: 0x7e22ce, shirt: 0x18181b, pants: 0x09090b, accent: 0xe879f9, hairStyle: "long", tall: 1 },
  // 13: Female office worker (slate blazer)
  { file: "char_13.png", hair: 0x18181b, skin: 0xf8d3b8, coat: 0x475569, coatHi: 0x64748b, shirt: 0xffffff, pants: 0x1e293b, accent: 0x38bdf8, hairStyle: "short", tall: 0 },
  // 14: Female sprinter (orange ponytail, pink jacket)
  { file: "char_14.png", hair: 0xea580c, skin: 0xf5ccb0, coat: 0xdb2777, coatHi: 0xf472b6, shirt: 0xffffff, pants: 0x1e293b, accent: 0xfef08a, hairStyle: "ponytail", tall: 0 },
  // 15: Female crimson coat (long black hair, dark red coat)
  { file: "char_15.png", hair: 0x09090b, skin: 0xfbe0cc, coat: 0x7f1d1d, coatHi: 0xb91c1c, shirt: 0x18181b, pants: 0x09090b, accent: 0xfacc15, hairStyle: "long", tall: 0 },
  // 16: Kid boy student (yellow cap, blue uniform)
  { file: "char_16.png", hair: 0x1c1917, skin: 0xf6cfb2, coat: 0x1d4ed8, coatHi: 0x3b82f6, shirt: 0xffffff, pants: 0x1e293b, accent: 0xfacc15, hairStyle: "short", tall: -3, cap: 0xfacc15 },
  // 17: Kid girl hoodie (brown hair, sky-blue hoodie)
  { file: "char_17.png", hair: 0x78350f, skin: 0xfbe0cc, coat: 0x0284c7, coatHi: 0x38bdf8, shirt: 0xffffff, pants: 0x1e3a5f, accent: 0xf472b6, hairStyle: "short", tall: -3 },
  // 18: Middle-aged technician (yellow helmet, navy coveralls)
  { file: "char_18.png", hair: 0x64748b, skin: 0xdca984, coat: 0x1e3a5f, coatHi: 0x2563eb, shirt: 0xe2e8f0, pants: 0x0f172a, accent: 0xfacc15, hairStyle: "short", tall: 0, beard: true, cap: 0xeab308 },
  // 19: Middle-aged auntie (brown bun, green apron)
  { file: "char_19.png", hair: 0x57331d, skin: 0xe8bea0, coat: 0x15803d, coatHi: 0x16a34a, shirt: 0xfef08a, pants: 0x292524, accent: 0xffffff, hairStyle: "bun", tall: -1 },
];

// 30-frame 32x40 character sheets with 3-frame animated attacks (wind-up -> strike -> follow-through)
for (const ch of PLAYABLE_CHARS) {
  const c = new Canvas(32 * 30, 40);
  // 0-1 idle (clear 2px breathing), 2-5 run (leaning forward + wide arm/leg swing), 6 jump, 7 dash, 8 hurt, 9 parry
  drawHumanoid(c, 0 * 32, { ...ch, crouch: 0 });
  drawHumanoid(c, 1 * 32, { ...ch, crouch: 2 });
  drawHumanoid(c, 2 * 32, { ...ch, step: 1, crouch: -1, lean: 1 });
  drawHumanoid(c, 3 * 32, { ...ch, step: 0, crouch: 1, lean: 1 });
  drawHumanoid(c, 4 * 32, { ...ch, step: 2, crouch: -1, lean: 1 });
  drawHumanoid(c, 5 * 32, { ...ch, step: 0, crouch: 1, lean: 1 });
  drawHumanoid(c, 6 * 32, { ...ch, step: 1, crouch: -3, lean: 1 });
  drawHumanoid(c, 7 * 32, { ...ch, dash: true, crouch: 2, lean: 2 });
  drawHumanoid(c, 8 * 32, { ...ch, hurt: true, crouch: 1, lean: -2 });
  drawHumanoid(c, 9 * 32, { ...ch, attack: 9, crouch: 2, lean: -1 });
  // 10-12: attack1 (lean back wind-up -> lunge forward slash -> follow-through)
  drawHumanoid(c, 10 * 32, { ...ch, attack: 10, crouch: 2, lean: -3 });
  drawHumanoid(c, 11 * 32, { ...ch, attack: 1, step: 1, crouch: -1, lean: 3 });
  drawHumanoid(c, 12 * 32, { ...ch, attack: 11, step: 1, lean: 1 });
  // 13-15: attack2 (crouch wind-up -> lunge horizontal cut -> low follow-through)
  drawHumanoid(c, 13 * 32, { ...ch, attack: 10, crouch: 3, lean: -3 });
  drawHumanoid(c, 14 * 32, { ...ch, attack: 2, step: 2, crouch: 0, lean: 4 });
  drawHumanoid(c, 15 * 32, { ...ch, attack: 12, crouch: 2, lean: 1 });
  // 16-18: attack3 finisher (leap raise -> slam forward -> crouched impact)
  drawHumanoid(c, 16 * 32, { ...ch, attack: 13, crouch: -3, lean: -2 });
  drawHumanoid(c, 17 * 32, { ...ch, attack: 3, step: 1, crouch: 1, lean: 4 });
  drawHumanoid(c, 18 * 32, { ...ch, attack: 12, crouch: 3, lean: 2 });
  // 19-21: attack_thrust (pull back -> deep forward lunge -> recovery)
  drawHumanoid(c, 19 * 32, { ...ch, attack: 14, crouch: 2, lean: -3 });
  drawHumanoid(c, 20 * 32, { ...ch, attack: 4, step: 2, crouch: 1, lean: 4 });
  drawHumanoid(c, 21 * 32, { ...ch, attack: 12, step: 1, lean: 1 });
  // 22-24: attack_heavy (lift high back -> heavy cleave forward -> slammed crouch)
  drawHumanoid(c, 22 * 32, { ...ch, attack: 15, crouch: -3, lean: -3 });
  drawHumanoid(c, 23 * 32, { ...ch, attack: 5, step: 1, crouch: 1, lean: 4 });
  drawHumanoid(c, 24 * 32, { ...ch, attack: 12, crouch: 4, lean: 2 });
  // 25-26: attack_spin (twist -> full 360 ring)
  drawHumanoid(c, 25 * 32, { ...ch, attack: 16, step: 1, crouch: 1, lean: -2 });
  drawHumanoid(c, 26 * 32, { ...ch, attack: 6, step: 2, crouch: -1, lean: 2 });
  // 27-28: attack_cast (gather back -> thrust forward burst)
  drawHumanoid(c, 27 * 32, { ...ch, attack: 17, crouch: 2, lean: -2 });
  drawHumanoid(c, 28 * 32, { ...ch, attack: 7, step: 1, crouch: -1, lean: 3 });
  // 29: attack_shoot (recoil kickback)
  drawHumanoid(c, 29 * 32, { ...ch, attack: 8, step: 1, crouch: 1, lean: -2 });
  savePng(ch.file, c.w, c.h, c.buf);
  if (ch.file === "char_0.png") {
    savePng("player_sheet.png", c.w, c.h, c.buf);
  }
}

// 2. Enemies (all 6 archetypes on 32x40 volumetric frames!)
const ENEMY_DEFS = [
  { file: "enemy_frenzy.png", hair: 0x2b1d1d, skin: 0xd9a88f, coat: 0x4a2525, coatHi: 0x6b3232, shirt: 0x9ca3af, pants: 0x1f2937, accent: 0xef4444, hairStyle: "spiky" },
  { file: "enemy_charger.png", hair: 0x111827, skin: 0xd1a188, coat: 0x3b1d4a, coatHi: 0x5b2c6f, shirt: 0x4b5563, pants: 0x111827, accent: 0xf59e0b, hairStyle: "short" },
  { file: "enemy_boss.png", hair: 0x09090b, skin: 0xdeb092, coat: 0x1f1423, coatHi: 0x4c1d2e, shirt: 0x18181b, pants: 0x09090b, accent: 0xf43f5e, tall: 2, hairStyle: "long" },
  { file: "enemy_thrower.png", hair: 0x991b1b, skin: 0xe3b899, coat: 0x1e3a2f, coatHi: 0x2f5e4b, shirt: 0xd1d5db, pants: 0x1e293b, accent: 0xf97316, cap: 0x991b1b },
  { file: "enemy_mage.png", hair: 0x1e1b4b, skin: 0xd8c8dc, coat: 0x2e1065, coatHi: 0x5b21b6, shirt: 0x1e1b4b, pants: 0x170f2e, accent: 0xc084fc, hairStyle: "long" },
  { file: "enemy_brute.png", hair: 0x18181b, skin: 0xc9967a, coat: 0x3f2e21, coatHi: 0x6b4c35, shirt: 0x27272a, pants: 0x18181b, accent: 0xef4444, tall: 2, beard: true },
];
for (const en of ENEMY_DEFS) {
  const c = new Canvas(32 * 6, 40);
  drawHumanoid(c, 0 * 32, { ...en });
  drawHumanoid(c, 1 * 32, { ...en, crouch: 1 });
  drawHumanoid(c, 2 * 32, { ...en, step: 1 });
  drawHumanoid(c, 3 * 32, { ...en, step: 2 });
  drawHumanoid(c, 4 * 32, { ...en, attack: en.file === "enemy_mage.png" ? 7 : 3 });
  drawHumanoid(c, 5 * 32, { ...en, hurt: true });
  savePng(en.file, c.w, c.h, c.buf);
}

// 5. NPC Survivor (32x40 volumetric single frame)
{
  const c = new Canvas(32, 40);
  drawHumanoid(c, 0, {
    hair: 0x3b271c, skin: 0xf6cfb2, coat: 0x1e4d5c, coatHi: 0x2c6e82,
    shirt: 0xf8fafc, pants: 0x1e293b, accent: 0x34d399, hairStyle: "ponytail"
  });
  savePng("npc_survivor.png", c.w, c.h, c.buf);
}

// 6. Dokkaebi (24x24 floating horned sprite, 2 frames)
{
  const c = new Canvas(48, 24);
  for (let f = 0; f < 2; f++) {
    const ox = f * 24, oy = f;
    // White fur head & body
    c.rect(ox + 7, 6 + oy, 10, 9, 0xf1f5f9);
    c.rect(ox + 8, 7 + oy, 4, 5, 0xffffff);
    // Tiny horns
    c.rect(ox + 8, 3 + oy, 2, 3, 0x94a3b8);
    c.rect(ox + 14, 3 + oy, 2, 3, 0x94a3b8);
    // Glowing blue-cyan eyes
    c.rect(ox + 9, 9 + oy, 2, 2, 0x38bdf8);
    c.rect(ox + 13, 9 + oy, 2, 2, 0x38bdf8);
    // Dark coat & floating wisp
    c.rect(ox + 8, 15 + oy, 8, 5, 0x1e293b);
    c.rect(ox + 10, 16 + oy, 4, 4, 0x334155);
    c.rect(ox + 10, 20 + oy, 4, 2, 0x38bdf8, 180);
    c.outline(ox, 0, 24, 24);
  }
  savePng("dokkaebi.png", c.w, c.h, c.buf);
}

// 7. Props sheet (3 tiles of 24x24: 0=iron pipe pickup, 1=kid's backpack/bug box, 2=luggage crate)
{
  const c = new Canvas(72, 24);
  // 0: Iron pipe glowing pickup
  c.rect(4, 15, 16, 3, 0x94a3b8);
  c.rect(4, 15, 16, 1, 0xe2e8f0);
  c.rect(6, 10, 12, 2, 0x38bdf8, 160);
  c.outline(0, 0, 24, 24);
  // 1: Kid's backpack + green bug cage
  c.rect(24 + 5, 9, 14, 12, 0x2563eb);
  c.rect(24 + 6, 10, 5, 8, 0x3b82f6);
  c.rect(24 + 8, 14, 8, 5, 0x22c55e); // green bug cage peeking out
  c.rect(24 + 10, 15, 4, 3, 0x86efac);
  c.outline(24, 0, 24, 24);
  // 2: Hard-shell subway suitcase (jumpable obstacle)
  c.rect(48 + 3, 8, 18, 15, 0x475569);
  c.rect(48 + 4, 9, 16, 4, 0x64748b);
  c.rect(48 + 9, 5, 6, 3, 0x94a3b8);
  c.rect(48 + 5, 13, 14, 2, 0x334155);
  c.outline(48, 0, 24, 24);
  savePng("props.png", c.w, c.h, c.buf);
}

// 8. Subway car background tile (540x270 — tiled 3x for 3 connected subway cars!)
{
  const W = 540, H = 270;
  const c = new Canvas(W, H);
  // Ceiling & upper wall
  c.rect(0, 0, W, 54, 0x161c28);
  c.rect(0, 48, W, 6, 0x273142);
  // Main metallic wall
  c.rect(0, 54, W, 158, 0x202938);
  c.rect(0, 168, W, 44, 0x18202c);
  // Floor (y = 212..270)
  c.rect(0, 212, W, 4, 0x475569);
  c.rect(0, 216, W, 54, 0x1c222e);
  for (let x = 0; x < W; x += 18) {
    c.rect(x, 216, 1, 54, 0x141923);
  }
  // Overhead fluorescent light fixtures
  for (let x = 40; x < W; x += 110) {
    c.rect(x, 36, 56, 7, 0x334155);
    c.rect(x + 4, 38, 48, 4, 0xbae6fd);
    c.rect(x + 8, 39, 40, 2, 0xffffff);
  }
  // Overhead grab rail & hanging straps
  c.rect(0, 62, W, 3, 0x64748b);
  c.rect(0, 62, W, 1, 0x94a3b8);
  for (let x = 32; x < W; x += 48) {
    c.rect(x, 65, 2, 16, 0x475569);
    c.rect(x - 3, 81, 8, 2, 0x94a3b8);
    c.rect(x - 3, 83, 2, 6, 0x94a3b8);
    c.rect(x + 3, 83, 2, 6, 0x94a3b8);
    c.rect(x - 3, 89, 8, 2, 0x94a3b8);
  }
  // Subway windows (dark tunnel with passing lights) & sliding doors
  for (let i = 0; i < 3; i++) {
    const bx = 24 + i * 172;
    // Wide window
    c.rect(bx, 78, 92, 62, 0x334155);
    c.rect(bx + 3, 81, 86, 56, 0x070b14);
    // Subtle reflection & tunnel cable
    c.rect(bx + 3, 108, 86, 2, 0x111a2e);
    c.rect(bx + 12, 85, 2, 48, 0x1e293b, 90);
    c.rect(bx + 20, 85, 1, 48, 0x38bdf8, 50);
    // Bench seats below window
    c.rect(bx + 2, 174, 88, 12, 0x25406b);
    c.rect(bx + 2, 174, 88, 3, 0x3b63a3);
    c.rect(bx + 2, 186, 88, 26, 0x182538);
    // Sliding door next to window
    const dx = bx + 104;
    c.rect(dx, 68, 54, 144, 0x2c374b);
    c.rect(dx + 26, 68, 2, 144, 0x0f172a);
    c.rect(dx + 6, 82, 16, 54, 0x090e1a);
    c.rect(dx + 32, 82, 16, 54, 0x090e1a);
    // Yellow safety strip on door floor
    c.rect(dx + 2, 212, 50, 3, 0xeab308);
    // Vertical steel pole
    c.rect(bx - 10, 54, 4, 158, 0x64748b);
    c.rect(bx - 9, 54, 1, 158, 0xcbd5e1);
  }
  // Car connector bulkhead on right edge
  c.rect(W - 14, 54, 14, 158, 0x111827);
  c.rect(W - 12, 74, 10, 138, 0x1e293b);
  c.rect(0, 54, 10, 158, 0x111827);

  savePng("subway_bg.png", W, H, c.buf);
}

// 9. Stage 2: Dongho Bridge at Night (540x270 tiled x3)
{
  const W = 540, H = 270;
  const c = new Canvas(W, H);
  // Crimson-violet apocalypse night sky
  c.rect(0, 0, W, 130, 0x120c24);
  c.rect(0, 80, W, 60, 0x1f1233);
  c.rect(0, 125, W, 35, 0x2b1738);
  // Distant stars / constellations
  for (let i = 0; i < 42; i++) {
    const sx = (i * 73 + 19) % W;
    const sy = (i * 29 + 11) % 100;
    c.set(sx, sy, i % 4 === 0 ? 0x38bdf8 : 0xe2e8f0);
  }
  // Distant dark Han River water
  c.rect(0, 160, W, 52, 0x091322);
  for (let x = 0; x < W; x += 26) {
    c.rect(x, 172 + (x % 7), 12, 1, 0x1e3a5f);
    c.rect(x + 8, 190 + (x % 5), 14, 1, 0x38bdf8, 80);
  }
  // Steel truss bridge arches & girders
  c.rect(0, 52, W, 6, 0x334155);
  c.rect(0, 52, W, 2, 0x64748b);
  for (let x = 0; x < W; x += 90) {
    c.rect(x, 58, 7, 154, 0x273244);
    c.rect(x + 1, 58, 2, 154, 0x475569);
    // Diagonal truss struts
    for (let k = 0; k < 84; k += 2) {
      c.rect(x + 7 + k, 58 + Math.floor(k * 1.45), 3, 2, 0x1e293b);
      c.rect(x + 88 - k, 58 + Math.floor(k * 1.45), 3, 2, 0x1e293b);
    }
  }
  // Guardrail & broken subway tracks floor (y=212)
  c.rect(0, 192, W, 3, 0x475569);
  c.rect(0, 212, W, 6, 0x64748b);
  c.rect(0, 218, W, 52, 0x1e2430);
  for (let x = 0; x < W; x += 20) {
    c.rect(x, 215, 10, 3, 0x334155);
  }
  savePng("stage2_bridge.png", W, H, c.buf);
}

// 10. Stage 3: Dark Oksu/Geumho Station (540x270 tiled x3)
{
  const W = 540, H = 270;
  const c = new Canvas(W, H);
  // Dark concrete station ceiling & back wall
  c.rect(0, 0, W, 50, 0x0b0f18);
  c.rect(0, 50, W, 162, 0x121926);
  // Tile grid on station wall
  for (let y = 60; y < 206; y += 18) c.rect(0, y, W, 1, 0x1b2436);
  for (let x = 0; x < W; x += 36) c.rect(x, 50, 1, 162, 0x1b2436);
  // Concrete pillars & red emergency lamps
  for (let x = 40; x < W; x += 180) {
    c.rect(x, 44, 24, 168, 0x1f2937);
    c.rect(x + 2, 44, 5, 168, 0x334155);
    c.rect(x + 8, 56, 8, 4, 0xef4444);
    c.rect(x + 6, 54, 12, 8, 0xef4444, 55);
  }
  // Station platform signboards
  for (let x = 110; x < W; x += 180) {
    c.rect(x, 78, 72, 20, 0x0f172a);
    c.rect(x + 2, 80, 68, 16, 0x15803d);
    c.rect(x + 8, 86, 56, 4, 0xe2e8f0);
  }
  // Platform floor + yellow hazard line
  c.rect(0, 212, W, 4, 0xeab308);
  c.rect(0, 216, W, 54, 0x171d28);
  savePng("stage3_station.png", W, H, c.buf);
}

// 11. Stage 4: King's Flag Fortress Hall (540x270 tiled x3)
{
  const W = 540, H = 270;
  const c = new Canvas(W, H);
  // Grand dark marble hall with golden constellation banners
  c.rect(0, 0, W, 46, 0x0f0b1e);
  c.rect(0, 46, W, 166, 0x17112b);
  for (let x = 24; x < W; x += 135) {
    // Tall stone arch column
    c.rect(x, 46, 22, 166, 0x261f3f);
    c.rect(x + 2, 46, 5, 166, 0x3b3161);
    // Hanging royal star banner
    c.rect(x + 48, 58, 36, 92, 0x1e3a8a);
    c.rect(x + 50, 60, 32, 86, 0x1d4ed8);
    c.rect(x + 62, 76, 8, 28, 0xfacc15);
    c.rect(x + 56, 86, 20, 8, 0xfacc15);
  }
  // Floating starlight specks
  for (let i = 0; i < 36; i++) {
    c.set((i * 59 + 13) % W, 52 + ((i * 37) % 130), i % 2 === 0 ? 0xfacc15 : 0x38bdf8);
  }
  // Cracked royal stone floor
  c.rect(0, 212, W, 5, 0x94a3b8);
  c.rect(0, 217, W, 53, 0x1c1730);
  for (let x = 0; x < W; x += 32) c.rect(x, 217, 2, 53, 0x120e21);
  savePng("stage4_throne.png", W, H, c.buf);
}

// 12. Campaign props (4 tiles of 24x24: 0=Gas Mask Crate, 1=Station Exit Gate, 2=Green Zone Beacon, 3=King Flag)
{
  const c = new Canvas(96, 24);
  // 0: Gas Mask Crate
  c.rect(3, 8, 18, 14, 0x15803d);
  c.rect(4, 9, 16, 4, 0x22c55e);
  c.rect(10, 12, 4, 6, 0xfef08a);
  c.outline(0, 0, 24, 24);
  // 1: Station Exit Gate
  c.rect(24 + 4, 2, 16, 21, 0x0284c7);
  c.rect(24 + 6, 4, 12, 18, 0x38bdf8);
  c.rect(24 + 9, 7, 6, 14, 0xe0f2fe);
  c.outline(24, 0, 24, 24);
  // 2: Green Zone Beacon
  c.rect(48 + 9, 4, 6, 18, 0x14532d);
  c.rect(48 + 7, 3, 10, 8, 0x22c55e);
  c.rect(48 + 9, 5, 6, 4, 0xbbf7d0);
  c.outline(48, 0, 24, 24);
  // 3: Capturable Flag
  c.rect(72 + 5, 2, 2, 21, 0xe2e8f0);
  c.rect(72 + 7, 3, 13, 9, 0xf59e0b);
  c.rect(72 + 9, 5, 8, 5, 0xfef08a);
  c.outline(72, 0, 24, 24);
  savePng("props_campaign.png", c.w, c.h, c.buf);
}

console.log("Generated shaded pixel-art sprites in", outDir);
