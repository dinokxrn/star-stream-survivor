#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";

const outDir = path.resolve("godot_project/assets/sfx");
fs.mkdirSync(outDir, { recursive: true });

const SR = 22050;

function writeWav(filename, samples) {
  const n = samples.length;
  const buf = Buffer.alloc(44 + n * 2);
  buf.write("RIFF", 0);
  buf.writeUInt32LE(36 + n * 2, 4);
  buf.write("WAVE", 8);
  buf.write("fmt ", 12);
  buf.writeUInt32LE(16, 16);
  buf.writeUInt16LE(1, 20);
  buf.writeUInt16LE(1, 22);
  buf.writeUInt32LE(SR, 24);
  buf.writeUInt32LE(SR * 2, 28);
  buf.writeUInt16LE(2, 32);
  buf.writeUInt16LE(16, 34);
  buf.write("data", 36);
  buf.writeUInt32LE(n * 2, 40);
  for (let i = 0; i < n; i++) {
    const v = Math.max(-1, Math.min(1, samples[i]));
    buf.writeInt16LE(Math.round(v * 32767), 44 + i * 2);
  }
  fs.writeFileSync(path.join(outDir, filename), buf);
}

const midi = (m) => 440 * Math.pow(2, (m - 69) / 12);
const square = (ph, duty = 0.5) => ((ph % 1) < duty ? 1 : -1);
const tri = (ph) => 4 * Math.abs((ph % 1) - 0.5) - 1;

function renderTrack(bpm, bars, leadNotes, bassNotes, arpNotes, intensity = 1.0) {
  const stepDur = 60 / bpm / 4; // 16th note
  const totalSteps = bars * 16;
  const totalSamples = Math.floor(totalSteps * stepDur * SR);
  const out = new Float32Array(totalSamples);

  for (let i = 0; i < totalSamples; i++) {
    const t = i / SR;
    const step = Math.floor(t / stepDur) % totalSteps;
    const stepPos = (t / stepDur) % 1;
    const env = Math.pow(1 - stepPos, 1.3);
    let mix = 0;

    const ln = leadNotes[step % leadNotes.length];
    if (ln > 0) {
      mix += square(t * midi(ln), 0.25) * 0.16 * env * intensity;
    }
    const bn = bassNotes[step % bassNotes.length];
    if (bn > 0) {
      mix += tri(t * midi(bn)) * 0.24 * (0.4 + 0.6 * (1 - stepPos));
    }
    const an = arpNotes[step % arpNotes.length];
    if (an > 0) {
      mix += square(t * midi(an), 0.5) * 0.08 * Math.pow(1 - stepPos, 2.0);
    }
    // Kick / hat pulse
    if (step % 4 === 0 && stepPos < 0.35) {
      const kf = 110 * Math.pow(0.3, stepPos / 0.35);
      mix += Math.sin(2 * Math.PI * kf * t) * 0.22 * (1 - stepPos / 0.35);
    }
    if (intensity > 1.0 && step % 2 === 1 && stepPos < 0.12) {
      mix += (((i * 1103515245) & 0xff) / 128 - 1) * 0.06;
    }
    out[i] = Math.max(-0.85, Math.min(0.85, mix));
  }
  return out;
}

// 1. bgm_subway.wav — Tense atmospheric ORV subway minor pulse (116 BPM)
writeWav("bgm_subway.wav", renderTrack(
  116, 4,
  [64,0,0,67, 69,0,67,0, 64,0,62,0, 60,0,59,0, 64,0,0,67, 71,0,69,0, 67,0,64,0, 62,0,0,0],
  [40,40,0,40, 45,45,0,45, 43,43,0,43, 38,38,40,0],
  [52,55,59,64, 57,60,64,69, 55,59,62,67, 50,54,57,62],
  0.85
));

// 2. bgm_battle.wav — Driving action chiptune for Bridge / Station (140 BPM)
writeWav("bgm_battle.wav", renderTrack(
  140, 4,
  [69,0,72,74, 76,0,74,72, 69,0,67,69, 72,0,0,0, 74,0,76,79, 81,0,79,76, 74,72,71,69, 67,0,69,0],
  [45,45,57,45, 43,43,55,43, 41,41,53,41, 40,40,52,43],
  [57,60,64,69, 55,59,62,67, 53,57,60,65, 52,56,59,64],
  1.10
));

// 3. bgm_boss.wav — High-energy intense boss battle theme (164 BPM)
writeWav("bgm_boss.wav", renderTrack(
  164, 4,
  [76,76,0,79, 81,0,79,76, 75,75,0,76, 79,0,76,0, 81,81,0,83, 84,0,83,81, 79,76,75,76, 79,81,83,0],
  [40,52,40,52, 43,55,43,55, 39,51,39,51, 40,52,47,43],
  [64,67,71,76, 63,67,71,75, 64,69,72,76, 62,66,69,74],
  1.25
));

console.log("Generated 3 looping Chiptune BGM WAVs in", outDir);
