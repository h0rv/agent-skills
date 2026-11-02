import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import test from 'node:test';

const root = fileURLToPath(new URL('../', import.meta.url));
const manifest = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8'));
const skillDirs = readdirSync(root, { withFileTypes: true })
  .filter(entry => entry.isDirectory() && existsSync(join(root, entry.name, 'SKILL.md')))
  .map(entry => entry.name)
  .sort();

test('Pi manifest lists every source skill exactly once', () => {
  assert.deepEqual(manifest.pi.skills.map(path => path.replace(/^\.\//, '')).sort(), skillDirs);
});

for (const skill of skillDirs) {
  test(`${skill} has portable local Markdown links`, () => {
    const base = join(root, skill);
    const docs = readdirSync(base, { recursive: true }).filter(path => path.endsWith('.md'));
    for (const doc of docs) {
      const file = join(base, doc);
      const text = readFileSync(file, 'utf8')
        .replace(/^```[^\n]*\n[\s\S]*?^```[^\n]*$/gm, '')
        .replace(/`[^`\n]*`/g, '');
      for (const [, href] of text.matchAll(/\]\(([^\s)]+)\)/g)) {
        if (/^[a-z][a-z\d+.-]*:|^#/i.test(href)) continue;
        assert.ok(!href.startsWith('/'), `${skill}/${doc}: absolute link ${href}`);
        const target = decodeURIComponent(href.split(/[?#]/)[0]);
        assert.ok(existsSync(resolve(dirname(file), target)), `${skill}/${doc}: missing ${href}`);
      }
    }
  });
}

// Point this at an unpacked or installed Pi package to use its actual skill parser.
const piDir = process.env.PI_TEST_PACKAGE_DIR;
test('Pi loads every declared skill without diagnostics', { skip: !piDir }, async () => {
  const { loadSkillsFromDir } = await import(pathToFileURL(join(piDir, 'dist/core/skills.js')).href);
  for (const path of manifest.pi.skills) {
    const { skills, diagnostics } = loadSkillsFromDir({ dir: resolve(root, path), source: 'test' });
    assert.deepEqual(diagnostics, [], path);
    assert.equal(skills.length, 1, path);
    assert.equal(skills[0].name, path.replace(/^\.\//, ''));
  }
});
