#!/usr/bin/env node
//
// claude-video-kit — npx entry point (cvk)
//
// Thin Node shim over install.sh, so the kit installs the same way whether
// invoked via npx or a git clone.
//
//   npx @tansuasici/claude-video-kit init [--upgrade|--gitignore|--dry-run|--force]
//   npx @tansuasici/claude-video-kit skills
//   npx @tansuasici/claude-video-kit --version
//
'use strict';

const { spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const PKG_ROOT = path.resolve(__dirname, '..');
const args = process.argv.slice(2);
const cmd = args[0];
const rest = args.slice(1);

function version() {
  try {
    return fs.readFileSync(path.join(PKG_ROOT, 'VERSION'), 'utf8').split('#')[0].trim();
  } catch {
    return '0.0.0';
  }
}

function run(script, scriptArgs) {
  const r = spawnSync('bash', [path.join(PKG_ROOT, script), ...scriptArgs], {
    stdio: 'inherit',
    cwd: process.cwd(),
  });
  process.exit(r.status == null ? 1 : r.status);
}

function listSkills() {
  const candidates = [
    path.join(process.cwd(), '.claude', 'skills'),
    path.join(PKG_ROOT, '.claude', 'skills'),
  ];
  const base = candidates.find((d) => {
    try { return fs.statSync(d).isDirectory(); } catch { return false; }
  });
  if (!base) {
    console.log('No .claude/skills/ found (run `cvk init` first).');
    process.exit(0);
  }
  const names = fs.readdirSync(base).filter((n) => {
    try { return fs.statSync(path.join(base, n, 'SKILL.md')).isFile(); } catch { return false; }
  }).sort();
  console.log(`Available skills (${names.length}) — invoke with /<name>:\n`);
  for (const name of names) {
    let desc = '';
    try {
      const m = fs.readFileSync(path.join(base, name, 'SKILL.md'), 'utf8').match(/^description:\s*(.+)$/m);
      if (m) desc = m[1].trim();
    } catch { /* ignore */ }
    console.log(desc ? `  /${name}\n      ${desc}` : `  /${name}`);
  }
  process.exit(0);
}

switch (cmd) {
  case 'init':
  case 'install':
    // Install into the caller's current directory.
    run('install.sh', [process.cwd(), ...rest]);
    break;
  case 'uninstall':
    run('uninstall.sh', [process.cwd(), ...rest]);
    break;
  case 'skills':
    listSkills();
    break;
  case '--version':
  case '-v':
    console.log(version());
    break;
  case undefined:
  case '--help':
  case '-h':
  default:
    console.log(`claude-video-kit ${version()}

Usage:
  cvk init [--upgrade|--gitignore|--dry-run|--force]   Install the kit into the current dir
  cvk uninstall [--dry-run|--keep-project]              Remove the kit's files from the current dir
  cvk skills                                            List available /skills
  cvk --version                                         Print version

Docs: https://claudevideokit.tansuasici.com`);
    process.exit(cmd && !['--help', '-h'].includes(cmd) ? 2 : 0);
}
