import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDir, '../..');
const manifest = JSON.parse(fs.readFileSync(path.join(repoRoot, 'desktop/electron/offline-asr-engine.json'), 'utf8'));
const source = manifest.whisperCpp;
if (!source?.repository || !/^[0-9a-f]{40}$/i.test(source.commit ?? '')) {
  throw new Error('offline ASR engine manifest is invalid');
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: options.cwd ?? repoRoot,
    env: { ...process.env, ...(options.env ?? {}) },
    stdio: 'inherit',
    shell: false,
  });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} failed with exit code ${result.status}`);
}

function findFile(root, candidateNames) {
  const queue = [root];
  while (queue.length) {
    const current = queue.shift();
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const target = path.join(current, entry.name);
      if (entry.isDirectory()) queue.push(target);
      else if (candidateNames.has(entry.name.toLowerCase())) return target;
    }
  }
  return null;
}

const platform = process.platform;
const arch = process.arch;
if (!['linux', 'darwin', 'win32'].includes(platform)) throw new Error(`unsupported ASR build platform: ${platform}`);
if (!['x64', 'arm64'].includes(arch)) throw new Error(`unsupported ASR build architecture: ${arch}`);

const destination = path.join(repoRoot, 'desktop/resources/asr', `${platform}-${arch}`);
const executableName = platform === 'win32' ? 'whisper-cli.exe' : 'whisper-cli';
const destinationBinary = path.join(destination, executableName);
const stampPath = path.join(destination, 'build.json');

if (fs.existsSync(destinationBinary) && fs.existsSync(stampPath)) {
  try {
    const stamp = JSON.parse(fs.readFileSync(stampPath, 'utf8'));
    if (stamp.commit === source.commit) {
      console.log(`Offline ASR engine already built for ${platform}-${arch} at ${source.commit.slice(0, 12)}.`);
      process.exit(0);
    }
  } catch {
    // Rebuild invalid/mismatched cache.
  }
}

const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'fabushi-whisper-cpp-'));
const sourceDir = path.join(tempRoot, 'src');
const buildDir = path.join(tempRoot, 'build');
try {
  run('git', ['clone', '--filter=blob:none', '--no-checkout', source.repository, sourceDir]);
  run('git', ['checkout', '--detach', source.commit], { cwd: sourceDir });
  run('cmake', [
    '-S', sourceDir,
    '-B', buildDir,
    '-DWHISPER_BUILD_TESTS=OFF',
    '-DWHISPER_BUILD_EXAMPLES=ON',
    '-DWHISPER_BUILD_SERVER=OFF',
    '-DBUILD_SHARED_LIBS=OFF',
    '-DGGML_NATIVE=OFF',
  ]);
  run('cmake', ['--build', buildDir, '--config', 'Release', '--parallel', '2']);
  const builtBinary = findFile(buildDir, new Set([executableName.toLowerCase()]));
  if (!builtBinary) throw new Error(`whisper-cli was not produced under ${buildDir}`);
  fs.rmSync(destination, { recursive: true, force: true });
  fs.mkdirSync(destination, { recursive: true, mode: 0o755 });
  fs.copyFileSync(builtBinary, destinationBinary);
  if (platform !== 'win32') fs.chmodSync(destinationBinary, 0o755);
  const license = path.join(sourceDir, 'LICENSE');
  if (!fs.existsSync(license)) throw new Error('whisper.cpp LICENSE is missing from the pinned source');
  fs.copyFileSync(license, path.join(destination, 'LICENSE.whisper.cpp'));
  fs.writeFileSync(stampPath, `${JSON.stringify({
    repository: source.repository,
    tag: source.tag,
    commit: source.commit,
    platform,
    arch,
    builtAt: new Date().toISOString(),
  }, null, 2)}\n`, 'utf8');
  console.log(`Built offline ASR engine for ${platform}-${arch}: ${destinationBinary}`);
} finally {
  fs.rmSync(tempRoot, { recursive: true, force: true });
}
