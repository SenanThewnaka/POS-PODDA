import { pathToFileURL } from 'node:url';

export function assertProtection(environment, policies, branch, expectedSha) {
  if (environment?.name !== 'production' || !Array.isArray(environment.protection_rules) ||
      environment.protection_rules.length !== 1 ||
      environment.protection_rules[0]?.type !== 'required_reviewers' ||
      !Array.isArray(policies?.branch_policies) || !Number.isInteger(policies.total_count)) {
    throw new Error('Unexpected production protection metadata; owner review required');
  }
  const reviewers = environment.protection_rules[0];
  if (!reviewers?.reviewers?.length || reviewers.prevent_self_review !== true) {
    throw new Error('production must require reviewers and prevent self-review');
  }
  if (environment.can_admins_bypass !== false) {
    throw new Error('production must disable administrator bypass');
  }
  if (environment.deployment_branch_policy?.custom_branch_policies !== true ||
      environment.deployment_branch_policy?.protected_branches !== false ||
      policies.branch_policies?.length !== 1 ||
      policies.branch_policies[0].name !== 'main' || policies.branch_policies[0].type !== 'branch') {
    throw new Error('production must allow only the selected main branch, with no tag rules');
  }
  if (branch.protected !== true || branch.commit?.sha !== expectedSha) {
    throw new Error('release SHA must still be the head of protected main; rerun for the new head');
  }
}

export async function preflight(env = process.env, request = fetch) {
  if (env.GITHUB_REPOSITORY !== 'SenanThewnaka/POS-PODDA' ||
      env.GITHUB_EVENT_NAME !== 'workflow_dispatch' || env.GITHUB_REF !== 'refs/heads/main' ||
      !/^[a-f0-9]{40}$/.test(env.RELEASE_SHA || '') || env.RELEASE_SHA !== env.GITHUB_SHA) {
    throw new Error('only an explicitly confirmed full SHA dispatched from main may release');
  }
  if (!env.GH_TOKEN) throw new Error('GitHub read token required for protection verification');
  const get = async path => {
    const response = await request(`https://api.github.com/repos/${env.GITHUB_REPOSITORY}/${path}`, {
      headers: { Authorization: `Bearer ${env.GH_TOKEN}`, Accept: 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28' },
    });
    if (!response.ok) throw new Error(`Cannot verify ${path}: HTTP ${response.status}; refusing release`);
    return response.json();
  };
  const [environment, policies, branch] = await Promise.all([
    get('environments/production'),
    get('environments/production/deployment-branch-policies?per_page=100'),
    get('branches/main'),
  ]);
  // Count also catches unexpected rules beyond the page returned above.
  if (policies.total_count !== 1) throw new Error('production must have exactly one branch policy');
  assertProtection(environment, policies, branch, env.RELEASE_SHA);
  console.log(`Production protection verified for ${env.RELEASE_SHA}; no cloud credentials requested.`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  preflight().catch(error => { console.error(error.message); process.exitCode = 1; });
}
