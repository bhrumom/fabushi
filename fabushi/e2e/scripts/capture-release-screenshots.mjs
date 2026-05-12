import { chromium } from "playwright";
import { createServer } from "node:http";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join, extname } from "node:path";
import { fileURLToPath } from "node:url";

const USAGE = `
Usage: node capture-release-screenshots.mjs --web-dir=<path> --output=<path>

Options:
  --web-dir     Path to Flutter web build directory (e.g. build/web)
  --output      Directory to write screenshots and manifest.json
  --base-url    Base URL override (default: http://127.0.0.1:<random-port>)
  --viewport    Viewport size (default: 390x844 for iPhone 14)
  --timeout     Page load timeout in ms (default: 30000)
  --help        Show this message
`;

function parseArgs() {
  const args = {
    webDir: "",
    output: "",
    baseUrl: "",
    viewport: "390x844",
    timeout: "30000",
  };

  for (const arg of process.argv.slice(2)) {
    if (arg === "--help") {
      console.log(USAGE);
      process.exit(0);
    }
    const eq = arg.indexOf("=");
    if (eq === -1) continue;
    const key = arg.slice(2, eq);
    const value = arg.slice(eq + 1);
    if (key in args) args[key] = value;
  }

  if (!args.webDir || !args.output) {
    console.error("Missing required arguments: --web-dir and --output");
    console.log(USAGE);
    process.exit(1);
  }

  return args;
}

const MIME_TYPES = {
  ".html": "text/html",
  ".js": "application/javascript",
  ".css": "text/css",
  ".json": "application/json",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".wasm": "application/wasm",
  ".woff2": "font/woff2",
  ".woff": "font/woff",
  ".ttf": "font/ttf",
};

function startServer(webDir) {
  return new Promise((resolve) => {
    const server = createServer((req, res) => {
      let pathname = new URL(req.url, "http://localhost").pathname;
      if (pathname === "/") pathname = "/index.html";

      const filePath = join(webDir, pathname);
      try {
        const data = readFileSync(filePath);
        const ext = extname(filePath).toLowerCase();
        res.writeHead(200, {
          "Content-Type": MIME_TYPES[ext] || "application/octet-stream",
          "Cross-Origin-Opener-Policy": "same-origin",
          "Cross-Origin-Embedder-Policy": "require-corp",
        });
        res.end(data);
      } catch {
        res.writeHead(200, { "Content-Type": "text/html" });
        res.end(readFileSync(join(webDir, "index.html")));
      }
    });

    server.listen(0, "127.0.0.1", () => {
      const port = server.address().port;
      resolve({ server, baseUrl: `http://127.0.0.1:${port}` });
    });
  });
}

const SCREENSHOT_TARGETS = [
  { name: "home", description: "首页地球" },
];

async function captureScreenshots(browser, baseUrl, viewport, timeout) {
  const results = {};

  for (const target of SCREENSHOT_TARGETS) {
    console.log(`Capturing: ${target.name} (${target.description})`);
    try {
      const context = await browser.newContext({
        viewport: {
          width: parseInt(viewport.split("x")[0], 10),
          height: parseInt(viewport.split("x")[1], 10),
        },
        deviceScaleFactor: 2,
      });

      const page = await context.newPage();

      await page.goto(baseUrl, {
        waitUntil: "domcontentloaded",
        timeout: parseInt(timeout, 10),
      });

      // Wait for Flutter canvas or app container to render
      try {
        await page.waitForSelector("flt-glass-pane", { timeout: 20000 });
      } catch {
        try {
          await page.waitForSelector("canvas.flt-canvas", { timeout: 10000 });
        } catch {
          await page.waitForSelector("#app-container", { timeout: 5000 });
        }
      }

      // Extra wait for 3D rendering and animations
      await page.waitForTimeout(6000);

      const filePath = join(args.output, `screenshot-${target.name}.png`);
      await page.screenshot({ path: filePath, fullPage: false });
      console.log(`  OK -> ${filePath}`);
      results[target.name] = { status: "captured" };

      await context.close();
    } catch (err) {
      console.warn(`  FAILED: ${err.message}`);
      results[target.name] = { status: "failed", error: err.message };
    }
  }

  return results;
}

const args = parseArgs();
const [viewportW, viewportH] = args.viewport.split("x").map(Number);

console.log("Starting Flutter web server...");
const { server, baseUrl } = await startServer(args.webDir);
console.log(`Server running at ${baseUrl}`);

mkdirSync(args.output, { recursive: true });

console.log("Launching Chromium...");
const browser = await chromium.launch({
  headless: true,
  args: [
    "--no-sandbox",
    "--disable-setuid-sandbox",
    "--use-gl=angle",
    "--use-angle=swiftshader",
    "--enable-webgl",
    "--ignore-gpu-blocklist",
    "--disable-gpu-sandbox",
  ],
});

let results;
try {
  results = await captureScreenshots(browser, baseUrl, args.viewport, args.timeout);
} finally {
  await browser.close();
  server.close();
}

const manifest = {
  capturedAt: new Date().toISOString(),
  baseUrl,
  viewport: { width: viewportW, height: viewportH },
  targets: results,
};

const manifestPath = join(args.output, "screenshot-manifest.json");
writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
console.log(`Manifest written to ${manifestPath}`);

const captured = Object.values(results).filter((r) => r.status === "captured").length;
const failed = Object.values(results).filter((r) => r.status === "failed").length;
console.log(`Done: ${captured} captured, ${failed} failed`);

if (failed > 0 && captured === 0) {
  console.warn("All screenshots failed, but continuing gracefully.");
}
