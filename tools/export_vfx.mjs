#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const pixelfxDir = path.resolve("tools/pixelfx");
const outRoot = path.resolve("godot_project/assets/vfx");
fs.mkdirSync(outRoot, { recursive: true });

const EFFECTS = [
  { key: "slash", id: "melee/sword-slash", opts: null },
  { key: "wind_slash", id: "melee/double-slash", opts: { palette: ["#07243b", "#0e5a8a", "#38bdf8", "#bae6fd", "#ffffff"] } },
  { key: "hit_spark", id: "impacts/hit-spark", opts: null },
  { key: "dash_puff", id: "arcane/blink-out", opts: { palette: ["#082038", "#155e75", "#38bdf8", "#a5f3fc", "#ffffff"] } },
  { key: "mana_burst", id: "arcane/mana-burst", opts: { palette: ["#0c1d3d", "#1d4ed8", "#38bdf8", "#bae6fd", "#ffffff"] } },
  { key: "shield_aura", id: "holy/divine-shield", opts: { palette: ["#0c2848", "#0284c7", "#38bdf8", "#e0f2fe", "#ffffff"] } },
  { key: "fire_bomb", id: "explosions/plasma-explosion", opts: { palette: ["#3b0d0c", "#991b1b", "#ea580c", "#facc15", "#ffffff"] } },
  { key: "coin_sparkle", id: "pickups/coin-spin", opts: null },
  { key: "level_up", id: "ui/level-up", opts: null },
  { key: "fireball", id: "fire/fireball", opts: null },
  { key: "lightning", id: "lightning/chain-lightning", opts: null },
  { key: "frost_nova", id: "ice/frost-nova", opts: null },
  { key: "dark_orb", id: "shadow/void-orb", opts: null },
  { key: "ground_slam", id: "impacts/ground-slam", opts: null },
  { key: "parry", id: "impacts/parry", opts: null },
  { key: "impact_frame", id: "impacts/impact-frame", opts: null },
  { key: "dagger_flurry", id: "melee/dagger-flurry", opts: null },
  { key: "heavy_cleave", id: "melee/heavy-cleave", opts: null },
  { key: "spin_slash", id: "melee/spin-slash", opts: null },
  { key: "scythe_reap", id: "melee/scythe-reap", opts: null },
];

for (const fx of EFFECTS) {
  const args = ["tools/render.mjs", fx.id, "--sheet"];
  if (fx.opts) {
    args.push("--opts", JSON.stringify(fx.opts));
  }
  console.log(`Rendering ${fx.key} (${fx.id})...`);
  execFileSync("node", args, { cwd: pixelfxDir, stdio: "inherit" });

  const baseName = path.basename(fx.id);
  const srcDir = path.join(pixelfxDir, "records", fx.id);
  const dstDir = path.join(outRoot, fx.key);
  fs.mkdirSync(dstDir, { recursive: true });

  fs.copyFileSync(path.join(srcDir, `${baseName}.png`), path.join(dstDir, `${fx.key}.png`));
  fs.copyFileSync(path.join(srcDir, `${baseName}.json`), path.join(dstDir, `${fx.key}.json`));
}

console.log("All 9 pixelfx sprite sheets exported to", outRoot);
