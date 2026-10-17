import test from 'node:test';
import assert from 'node:assert/strict';
import { assertProtection, preflight } from '../../scripts/production-preflight.mjs';

const sha = 'a'.repeat(40);
const environment = () => ({
  name: 'production',
  can_admins_bypass: false,
  protection_rules: [{ type: 'required_reviewers', prevent_self_review: true, reviewers: [{ reviewer: { login: 'reviewer' } }] }],
  deployment_branch_policy: { custom_branch_policies: true, protected_branches: false },
});
const policies = () => ({ total_count: 1, branch_policies: [{ name: 'main', type: 'branch' }] });
const branch = () => ({ protected: true, commit: { sha } });
const env = () => ({ GITHUB_REPOSITORY: 'SenanThewnaka/POS-PODDA', GITHUB_EVENT_NAME: 'workflow_dispatch',
  GITHUB_REF: 'refs/heads/main', GITHUB_SHA: sha, RELEASE_SHA: sha, GH_TOKEN: 'offline-test-placeholder' });

test('accepts only fully protected production and current main', () => assertProtection(environment(), policies(), branch(), sha));
for (const [name, change] of [
  ['missing reviewer', e => { e.protection_rules = []; }],
  ['self-review', e => { e.protection_rules[0].prevent_self_review = false; }],
  ['administrator bypass', e => { e.can_admins_bypass = true; }],
  ['missing bypass metadata', e => { delete e.can_admins_bypass; }],
  ['unrestricted branches', e => { e.deployment_branch_policy = null; }],
]) test(`rejects ${name}`, () => { const e = environment(); change(e); assert.throws(() => assertProtection(e, policies(), branch(), sha)); });
test('rejects tags and extra branches', () => {
  for (const policy of [{ name: 'main', type: 'tag' }, { name: '*', type: 'branch' }]) {
    assert.throws(() => assertProtection(environment(), { branch_policies: [policy] }, branch(), sha));
  }
  assert.throws(() => assertProtection(environment(), { branch_policies: [...policies().branch_policies, { name: 'other', type: 'branch' }] }, branch(), sha));
});
test('rejects unprotected main and stale SHA', () => {
  assert.throws(() => assertProtection(environment(), policies(), { ...branch(), protected: false }, sha));
  assert.throws(() => assertProtection(environment(), policies(), branch(), 'b'.repeat(40)));
});
for (const [key, value] of Object.entries({ GITHUB_REPOSITORY: 'fork/repo', GITHUB_EVENT_NAME: 'pull_request', GITHUB_REF: 'refs/heads/feature', RELEASE_SHA: 'main', GH_TOKEN: '' })) {
  test(`rejects invalid ${key} without API calls`, async () => {
    await assert.rejects(preflight({ ...env(), [key]: value }, () => { throw new Error('must not call'); }), /only|token required/);
  });
}
test('fails closed on inaccessible or absent settings', async () => {
  for (const status of [403, 404, 500]) await assert.rejects(preflight(env(), async () => ({ ok: false, status })), /refusing release/);
});
test('verifies all three metadata endpoints', async () => {
  const seen = [];
  await preflight(env(), async url => {
    seen.push(url);
    return { ok: true, json: async () => url.endsWith('/branches/main') ? branch() : url.includes('deployment-branch-policies') ? policies() : environment() };
  });
  assert.equal(seen.length, 3);
});
test('rejects paginated extra policy count', async () => {
  await assert.rejects(preflight(env(), async url => ({ ok: true, json: async () => url.endsWith('/branches/main') ? branch() : url.includes('deployment-branch-policies') ? { ...policies(), total_count: 101 } : environment() })), /exactly one/);
});

test('rejects wrong environment, duplicate or unknown protections, and malformed metadata', () => {
  for (const change of [
    e => { e.name = 'staging'; },
    e => { e.protection_rules.push(e.protection_rules[0]); },
    e => { e.protection_rules.push({ type: 'unexpected' }); },
    e => { e.protection_rules = {}; },
  ]) { const e = environment(); change(e); assert.throws(() => assertProtection(e, policies(), branch(), sha)); }
  assert.throws(() => assertProtection(environment(), { total_count: 1, branch_policies: {} }, branch(), sha));
});

test('workflow preserves release safety invariants', async () => {
  const { readFile } = await import('node:fs/promises');
  const workflow = await readFile(new URL('../../.github/workflows/deploy.yml', import.meta.url), 'utf8');
  const validation = workflow.split('  validate:')[1].split('  release-preflight:')[0];
  const release = workflow.split('  deploy-production:')[1].split('\n').filter(line => !line.trimStart().startsWith('#')).join('\n');
  assert.ok(!validation.includes('id-token:') && !validation.includes('secrets.') && !validation.includes('environment:'));
  assert.match(release, /needs: \[validate, release-preflight\]/);
  assert.match(release, /github\.event_name == 'workflow_dispatch' && github\.ref == 'refs\/heads\/main'/);
  assert.match(release, /environment:\n      name: production/);
  assert.match(release, /cancel-in-progress: false/);
  assert.ok(release.indexOf('npm audit --prefix tests/firestore') < release.indexOf('uses: google-github-actions/auth@'));
  assert.ok(!/run-id:|github-token:/.test(release));
  assert.ok(!/--force|functions:call|functions:shell/.test(release));
  for (const target of ['firestore:rules', 'functions', 'hosting']) assert.ok(release.includes(`--only ${target} --non-interactive`));
  assert.equal((workflow.match(/id-token: write/g) || []).length, 1);
  assert.ok(!workflow.includes('credentials_json:') && !workflow.includes('FIREBASE_TOKEN'));
});
