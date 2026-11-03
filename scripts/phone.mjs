// Talk to the iPhone over USB from Windows, using pymobiledevice3 (free,
// open source, from PyPI) and Apple's own Mobile Device driver (installed
// with iCloud / iTunes / Apple Devices).
//
//   npm run phone:udid                    -> print the phone's UDID (to register it with Apple)
//   npm run phone:devmode                 -> show the Developer Mode switch in Settings
//   npm run phone:install -- <file.ipa>   -> install a development build
//
// The phone must be plugged in, unlocked, and have tapped "Trust This Computer".
import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

const root = new URL("..", import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1");
const venv = join(root, ".venv-device");
const tool = join(venv, process.platform === "win32" ? "Scripts/pymobiledevice3.exe" : "bin/pymobiledevice3");

function ensureTool() {
  if (existsSync(tool)) return;
  console.log("Installing pymobiledevice3 (one time)...");
  execFileSync("python", ["-m", "venv", venv], { stdio: "inherit" });
  const pip = join(venv, process.platform === "win32" ? "Scripts/python.exe" : "bin/python");
  execFileSync(pip, ["-m", "pip", "install", "-q", "pymobiledevice3"], { stdio: "inherit" });
}

function pmd(args) {
  const r = spawnSync(tool, args, { stdio: "inherit" });
  if (r.status !== 0) process.exit(r.status ?? 1);
}

/** The newest Lockout .ipa in Downloads, if no path was given. */
function newestIpa() {
  const dir = join(homedir(), "Downloads");
  const ipas = readdirSync(dir)
    .filter((f) => f.toLowerCase().endsWith(".ipa"))
    .map((f) => join(dir, f))
    .sort((a, b) => statSync(b).mtimeMs - statSync(a).mtimeMs);
  return ipas[0];
}

ensureTool();
const [command, file] = process.argv.slice(2);
switch (command) {
  case "udid":
    pmd(["usbmux", "list"]);
    break;
  case "devmode":
    pmd(["amfi", "reveal-developer-mode"]);
    console.log("Now on the phone: Settings > Privacy & Security > Developer Mode > On, then restart when asked.");
    break;
  case "install": {
    const ipa = file ?? newestIpa();
    if (!ipa || !existsSync(ipa)) {
      console.error("No .ipa found. Download it from the Codemagic build page, or pass its path.");
      process.exit(1);
    }
    console.log(`Installing ${ipa} ...`);
    pmd(["apps", "install", ipa]);
    console.log("Installed. Open Lockout on the phone.");
    break;
  }
  default:
    console.error("Use: udid | devmode | install [file.ipa]");
    process.exit(1);
}
