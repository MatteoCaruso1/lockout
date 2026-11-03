// Ship Lockout to Codemagic by pushing a tag. Codemagic builds on tags only.
//
//   npm run ship                 -> ios-dev-X.Y.Z-bN    Release build for your iPhone
//   npm run ship -- --debug      -> ios-debug-X.Y.Z-bN  Debug build (emergency release button)
//   npm run ship -- --testflight -> ios-beta-X.Y.Z-bN   TestFlight (only after Apple approves
//                                                       Family Controls distribution)
//
// X.Y.Z is "version" in package.json. bN counts ships of that version.
// Refuses to ship uncommitted or unpushed work, so the build is exactly what is on GitHub.
import { execSync } from "node:child_process";
import { readFileSync } from "node:fs";

const run = (cmd) => execSync(cmd, { encoding: "utf8" }).trim();
const fail = (msg) => {
  console.error(`\nNot shipped: ${msg}\n`);
  process.exit(1);
};

const args = process.argv.slice(2);
const kind = args.includes("--testflight") ? "beta" : args.includes("--debug") ? "debug" : "dev";
const { version } = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8"));

if (run("git status --porcelain")) fail("there are uncommitted changes. Commit them first.");
const branch = run("git rev-parse --abbrev-ref HEAD");
if (branch !== "main") fail(`you are on "${branch}". Ship from main.`);
run("git fetch --tags origin");
if (run("git rev-parse HEAD") !== run("git rev-parse origin/main")) {
  fail("main is not the same as GitHub's main. Push (or pull) first.");
}

const existing = run(`git tag --list "ios-*-${version}-b*"`).split("\n").filter(Boolean);
const next = Math.max(0, ...existing.map((t) => Number(t.match(/-b(\d+)$/)?.[1] ?? 0))) + 1;
const tag = `ios-${kind}-${version}-b${next}`;

run(`git tag -a ${tag} -m "Ship ${tag}"`);
run(`git push origin ${tag}`);
console.log(`\nShipped ${tag}. Codemagic is building it now (about 10 minutes).`);
console.log("Watch it at https://codemagic.io/apps (Lockout).");
