import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import path from 'node:path';

const root = '/Users/gloriachan/Documents/fabushi';
const html = path.join(root, 'output/copyright_registration/发布软件V1.0_操作说明书.html');
const pdf = path.join(root, 'output/copyright_registration/发布软件V1.0_操作说明书.pdf');
const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const args = [
  '--headless=new',
  '--disable-gpu',
  '--allow-file-access-from-files',
  '--no-pdf-header-footer',
  `--print-to-pdf=${pdf}`,
  pathToFileURL(html).href,
];
const result = spawnSync(chrome, args, { stdio: 'inherit' });
if (result.status !== 0) process.exit(result.status ?? 1);
console.log(pdf);
