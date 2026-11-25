#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";

const outDir = path.resolve("godot_project/assets/sfx");
fs.mkdirSync(outDir, { recursive: true });

const SAMPLE_RATE = 22050;

function writeWav(filename, samples) {
  const numSamples = samples.length;
  const buffer = Buffer.alloc(44 + numSamples * 2);
  buffer.write("RIFF", 0);
  buffer.writeUInt32LE(36 + numSamples * 2, 4);
  buffer.write("WAVE", 8);
  buffer.write("fmt ", 12);
  buffer.writeUInt32LE(16, 16);
  buffer.writeUInt16LE(1, 20);
  buffer.writeUInt16LE(1, 22);
  buffer.writeUInt32LE(SAMPLE_RATE, 24);
  buffer.writeUInt32LE(SAMPLE_RATE * 2, 28);
  buffer.writeUInt16LE(2, 32);
  buffer.writeUInt16LE(16, 34);
  buffer.write("data", 36);
  buffer.writeUInt32LE(numSamples * 2, 40);
  for (let i = 0; i < numSamples; i++) {
    const v = Math.max(-1, Math.min(1, samples[i]));
    buffer.writeInt16LE(Math.round(v * 32767), 44 + i * 2);
  }
  fs.writeFileSync(path.join(outDir, filename), buffer);
}

function synth(duration, fn) {
  const n = Math.floor(SAMPLE_RATE * duration);
  const arr = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const t = i / SAMPLE_RATE;
    arr[i] = fn(t, t / duration);
  }
  return arr;
}

let seed = 1337;
function rand() {
  seed = (seed * 1664525 + 1013904223) >>> 0;
  return (seed / 0xffffffff) * 2 - 1;
}

// Slash swoosh
writeWav("slash.wav", synth(0.14, (t, p) => {
  const freq = 520 - 380 * p;
  const env = Math.pow(1 - p, 1.5);
  return (Math.sin(2 * Math.PI * freq * t) * 0.4 + rand() * 0.45) * env * 0.55;
}));

// Hit impact
writeWav("hit.wav", synth(0.12, (t, p) => {
  const freq = 180 * Math.pow(0.25, p);
  const env = Math.pow(1 - p, 2.0);
  return (Math.sin(2 * Math.PI * freq * t) * 0.7 + rand() * 0.35) * env * 0.7;
}));

// Dash whoosh
writeWav("dash.wav", synth(0.16, (t, p) => {
  const env = Math.sin(Math.PI * p) * (1 - p * 0.4);
  return (rand() * 0.5 + Math.sin(2 * Math.PI * (300 + 250 * (1 - p)) * t) * 0.25) * env * 0.45;
}));

// Jump
writeWav("jump.wav", synth(0.12, (t, p) => {
  const freq = 220 + 280 * p;
  const env = 1 - p;
  return Math.sign(Math.sin(2 * Math.PI * freq * t)) * env * 0.22;
}));

// Coin chime
writeWav("coin.wav", synth(0.24, (t, p) => {
  const freq = p < 0.35 ? 987.77 : 1318.51;
  const env = Math.pow(1 - p, 1.2);
  return Math.sin(2 * Math.PI * freq * t) * env * 0.38;
}));

// Star Stream system window chime
writeWav("system.wav", synth(0.38, (t, p) => {
  const f1 = p < 0.33 ? 587.33 : (p < 0.66 ? 880.0 : 1174.66);
  const env = Math.pow(1 - (p % 0.33) / 0.33, 1.2) * (1 - p * 0.3);
  return (Math.sin(2 * Math.PI * f1 * t) * 0.6 + Math.sin(2 * Math.PI * f1 * 2 * t) * 0.2) * env * 0.35;
}));

// Skill burst
writeWav("skill.wav", synth(0.28, (t, p) => {
  const freq = 320 + 480 * Math.pow(1 - p, 2);
  const env = Math.pow(1 - p, 1.3);
  return (Math.sin(2 * Math.PI * freq * t) * 0.5 + Math.sign(Math.sin(2 * Math.PI * freq * 0.5 * t)) * 0.25 + rand() * 0.2) * env * 0.45;
}));

// Level up / Stat up
writeWav("levelup.wav", synth(0.42, (t, p) => {
  const notes = [523.25, 659.25, 783.99, 1046.5];
  const idx = Math.min(notes.length - 1, Math.floor(p * notes.length));
  const env = Math.pow(1 - p, 0.9);
  return Math.sin(2 * Math.PI * notes[idx] * t) * env * 0.38;
}));

// Hurt
writeWav("hurt.wav", synth(0.18, (t, p) => {
  const freq = 140 - 80 * p;
  const env = Math.pow(1 - p, 1.5);
  return (Math.sign(Math.sin(2 * Math.PI * freq * t)) * 0.45 + rand() * 0.35) * env * 0.5;
}));

console.log("Generated retro SFX WAVs in", outDir);
