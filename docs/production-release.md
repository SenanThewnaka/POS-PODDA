# Controlled production release

This PR prepares a release path; it does not authorize or perform a release. Nothing automatically deploys on merge or push. The one-time legacy employee-password cleanup is **not** part of this workflow and still requires separate authorization. Deploying its existing callable is not invoking it.

## What the workflow does

PRs and pushes run the existing complete validation: Flutter analysis, tests and release Web build; Functions unit tests and production-dependency audit; Firestore emulator rules tests. New offline release-guard tests run too. No production environment, Google identity, production secrets, or OIDC permission is attached to validation.

An owner-authorized manual dispatch from `main`, with its full current SHA as `release_sha`, reruns all validation. Only then does a read-only preflight verify protection settings. The deploy job waits for the protected `production` environment, verifies settings/current main again after approval and concurrency waiting, restores the Web build from the **same run**, installs locked dependencies, audits deployment tooling, and only then exchanges GitHub OIDC for short-lived Google ADC credentials. Deployments are serialized and never cancelled mid-release.

Release order is Firestore **rules only**, Functions, then Hosting. Indexes, Firestore data, and cleanup invocation are excluded. There is no `--force`, automatic function deletion, automatic retry, or rollback. A failed step stops later steps. Multi-service deployment is not atomic.

## Current blockers

The preflight found no production environment and an unprotected `main`. Google trust, deployer/runtime IAM, live Functions inventory, enabled APIs, payment-secret provisioning, and runtime behavior have **not** been verified. No secret values were requested or read.

The pinned latest Firebase CLI (`firebase-tools` 15.34.0) and rules-test dependency graph currently report **12 npm audit findings: 8 high, 4 moderate**. The Functions production graph reports zero. Examples include transitive `@grpc/grpc-js`, `braces`, `@opentelemetry/core`, and `uuid` advisories. These are tooling/test dependencies, not evidence of application exploitation, but that tooling would execute with production credentials. The deploy job deliberately blocks on its dependency audit **before authentication**. Resolve the affected graph in a separately reviewed lockfile change, or design a narrowly scoped, documented security exception in a reviewed PR after assessing exact advisory reachability; do not bypass the gate by setting a variable or running `npm audit fix --force`. Until that is resolved, this is a prepared but blocked deployment path.

## 1. Owner: protect GitHub before enabling releases

In this repository's settings (not changed by this PR):

1. Protect `main` with a branch rule/ruleset: require pull requests, independent approving review, dismissal of stale approvals, approval of the latest reviewable push, and resolved conversations. Require the check **Test and build without production credentials** from this workflow with the GitHub Actions source, and require the branch to be up to date. Disallow direct/force pushes and deletion; do not configure bypass actors, including administrators. Include workflow, scripts, lockfiles, Firebase config/rules, and Functions changes in security review. The automated preflight checks that main is protected, not every detail of the branch rule; the owner must verify these settings.
2. Create the environment named exactly **production**. Add an independent required reviewer who is not the release initiator; enable **Prevent self-review**; disable **Allow administrators to bypass configured protection rules**. A sole reviewer cannot approve their own dispatch: add another trusted reviewer/operator rather than weakening protection.
3. Select deployment branches/tags **Selected branches and tags**, with exactly one **branch** policy named `main` and **no tag policies**. Do not choose 'protected branches only': with no protected branches GitHub permits every branch. This guard intentionally expects exactly one required-reviewers protection rule; adding a wait/custom rule requires a reviewed guard/test update (never silently ignored).
4. Confirm the repository's visibility/plan supports these protections. If unavailable, release stays blocked; do not substitute an unprotected environment.
5. Keep default workflow token permissions read-only and do not expose production keys/tokens to validation. Do not add `FIREBASE_TOKEN` or service-account JSON to this workflow. Existing Actions secrets have not been inspected and are not needed for this path.

The preflight uses only GitHub metadata GETs with the built-in token. It refuses missing/403/incomplete metadata. It requires `can_admins_bypass === false`; GitHub's public REST schema does not currently enumerate that field, although API clients have supported it. If the field is unavailable for this repository/API version, that is an owner/integration blocker requiring review, **not** a reason to assume bypass is disabled. Validate that contract during authorized setup. The release workflow itself has not been dispatched to test it.

See [GitHub environment protections](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments), [environment REST reads](https://docs.github.com/en/rest/deployments/environments), and [the client field discussion](https://github.com/google/go-github/pull/2722).

## 2. Owner/cloud administrator: establish keyless Google trust

Confirm project ID `pos-podda` and project number `34496743352` against your Google project. The number below comes from checked-in Firebase application configuration, not a live cloud lookup. These are setup instructions only; none were executed.

Create a dedicated WIF pool/provider (example pool `github-production`, provider `pos-podda`) and a dedicated deployer SA (example `github-production-deployer@pos-podda.iam.gserviceaccount.com`). Use GitHub's issuer `https://token.actions.githubusercontent.com`, with the normal provider-resource audience; do not allow arbitrary audiences. Use a dedicated pool so another provider cannot satisfy the same attribute principal binding.

Provider attribute mappings:

```text
google.subject=assertion.sub
attribute.repository_id=assertion.repository_id
attribute.repository_owner_id=assertion.repository_owner_id
attribute.ref=assertion.ref
attribute.environment=assertion.environment
attribute.workflow_ref=assertion.workflow_ref
attribute.event_name=assertion.event_name
```

Provider CEL attribute condition (all clauses are required):

```text
assertion.repository_id == '1172710487' &&
assertion.repository_owner_id == '150370681' &&
assertion.ref == 'refs/heads/main' &&
assertion.environment == 'production' &&
assertion.event_name == 'workflow_dispatch' &&
assertion.workflow_ref == 'SenanThewnaka/POS-PODDA/.github/workflows/deploy.yml@refs/heads/main'
```

Use `workflow_ref`, **not** `job_workflow_ref`: this is a normal workflow, not a reusable workflow. Numeric repository and owner IDs protect against name reuse; the workflow path additionally limits which workflow can request access. This does not replace main-branch review and environment approval.

Grant **only on the deployer SA** `roles/iam.workloadIdentityUser` to:

```text
principalSet://iam.googleapis.com/projects/34496743352/locations/global/workloadIdentityPools/github-production/attribute.repository_id/1172710487
```

Use the WIF pool's actual project number if hosted in a different project. No service-account key, GitHub PAT, self-granted Token Creator role, or static Firebase CI token is required for this impersonation pattern. Keep pool/provider and deployer-policy administration separate from the deployer.

See [Google deployment-pipeline WIF setup](https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines), [GitHub OIDC claims](https://docs.github.com/en/actions/reference/security/oidc), and [the pinned authentication action](https://github.com/google-github-actions/auth).

## 3. Owner/cloud administrator: bootstrap APIs and least-privilege IAM

The checked-in Functions use **second-generation HTTP/callable functions** (`firebase-functions/v2/https`), Node 22, with no explicit custom runtime SA. Do not assume first-generation defaults. Confirm existing names/regions/generations/runtime/build SAs and invoker policies before release; changing generation or removing existing Functions may require an explicitly reviewed migration. The non-interactive workflow intentionally fails rather than authorizing deletion.

Provision the following deployer access in `pos-podda`, scoped to individual resources wherever possible:

| Purpose | Required access / scope |
| --- | --- |
| Firestore rules | `roles/firebaserules.admin` on the project, or an audited custom equivalent limited to ruleset/release creation/read/update required by the CLI. No Firestore data role. |
| Hosting | `roles/firebasehosting.admin` on the project. |
| Functions deployment | `roles/cloudfunctions.developer` on the project, plus the IAM-policy permissions below for public HTTP/callable endpoints. Do not give Owner/Editor as a shortcut. |
| Endpoint invoker policy | A custom role containing `cloudfunctions.functions.getIamPolicy`, `cloudfunctions.functions.setIamPolicy`, `run.services.getIamPolicy`, and `run.services.setIamPolicy`, scoped to relevant resources where possible (project scope may be necessary for creation). Required for creating/updating HTTP invoker policies, not blanket project IAM administration. |
| Firebase/project discovery | `roles/firebase.viewer`, `roles/serviceusage.serviceUsageConsumer`, and project IAM policy **read** (`resourcemanager.projects.getIamPolicy`) where CLI service-agent verification requires it. No `resourcemanager.projects.setIamPolicy`. |
| Acting as runtime/build SAs | `roles/iam.serviceAccountUser` only on each actual Functions runtime SA and build SA. The usual gen2 runtime is `34496743352-compute@developer.gserviceaccount.com`; verify rather than assume. The pinned Firebase CLI also checks actAs on `pos-podda@appspot.gserviceaccount.com`: confirm/create the appropriate identity during owner bootstrap or review a compatible tooling/configuration change if absent. Never grant project-wide actAs merely to silence a failure. |
| Payment-secret metadata | `roles/secretmanager.viewer` only on `PAYMENTS_LK_SECRET_KEY` and `PAYMENTS_LK_WEBHOOK_SECRET` (metadata/version and IAM-policy reads; **not** payload access). Owner prebinds runtime access below so the deployer does not need secret IAM writes. |

Predefined roles are service-scoped baselines, not a claim that every included permission is mathematically minimal. Review effective policies with your organization restrictions and actual inventories. If an operation is denied, add only a documented required permission in a reviewed change; do not grant broad admin roles or a long-lived key. The deployment has not been proven against live IAM.

Owner bootstrap must enable/verify: IAM, IAM Credentials, Security Token Service, Resource Manager, Service Usage, Firebase Management, Firebase Hosting, Firebase Rules, Firestore, Cloud Functions, Cloud Run, Cloud Build, Artifact Registry, Secret Manager, and the Cloud Storage API/build buckets required by Functions. Verify billing/runtime support and quotas for Node 22 gen2. Provision default service agents and their documented service-agent roles, build SA permissions for build execution/logging/source storage/Artifact Registry, and any artifact cleanup policy **outside CI**. The deployer must not be an API-enablement or project-IAM administrator. If Firebase tries first-use bootstrap and cannot do it, stop and ask the administrator; do not broaden CI permissions.

On the verified runtime SA, grant only the application's necessary Firestore and Firebase Auth permissions (it resets employee Auth passwords), and `roles/secretmanager.secretAccessor` on the two payment secrets only. Provision active secret versions directly in Google/Firebase's secure interface and prebind access before deploying. Do not put payment secrets in GitHub, print/read their payloads in preflight, or give the deployer Secret Accessor. Service-account impersonation/actAs and deployment are privileged capabilities even without direct payload-read permission: protect approvals accordingly.

Confirm Payments.lk API credentials, separate webhook signing secret, configured webhook endpoint, signature format, checkout amount/currency/reference mapping, and replay behavior using the provider's sandbox and approved test plan. Unit tests do not prove the live provider contract. No payment or provider setting was changed here.

See [Functions deployment IAM](https://docs.cloud.google.com/functions/docs/reference/iam/roles), [Firebase IAM permissions](https://firebase.google.com/docs/projects/iam/permissions), [Functions secrets](https://firebase.google.com/docs/functions/config-env), and [Firebase ADC authentication](https://firebase.google.com/docs/cli).

## 4. Owner: configure environment variables, then authorize a release separately

Set these **non-secret environment variables** on `production`, after completing setup:

| Variable | Value |
| --- | --- |
| `FIREBASE_PROJECT_ID` | `pos-podda` |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/34496743352/locations/global/workloadIdentityPools/github-production/providers/pos-podda` (replace if using another verified pool/project) |
| `GCP_DEPLOY_SERVICE_ACCOUNT` | `github-production-deployer@pos-podda.iam.gserviceaccount.com` (replace with actual dedicated SA) |
| `PRODUCTION_RELEASE_ENABLED` | Keep absent/`false` until setup, advisory remediation, review, and separate release authorization are complete; only then set `true`. |

The owner reviews and merges this PR only after its checks pass. Merging itself never deploys. For an independently authorized release: select **POS Podda CI and controlled release**, choose **Run workflow** on `main`, enter its exact current full SHA as `release_sha`, and review the successful validation and immutable source SHA before an independent reviewer approves the production environment. This document is not permission to dispatch it. If main advances or the one-day artifact expires, start a fresh reviewed run; do not reuse artifacts from another run.

## Verify release and recover deliberately

Before release, record the deployed rules, Function revisions/invoker policies, and Hosting release; arrange an approved Firestore backup/export and rollback plan. Do not run backup or cleanup merely because this file mentions it.

After an authorized release, verify owner login/email verification, employee login and owner-mediated password reset, denied unauthorized/cross-shop access, and payment sandbox verification/webhooks. Inspect service health without exposing secrets. Legacy plaintext fields remain until a separately authorized, backed-up migration invokes the existing cleanup callable; there is no invocation in CI.

If Functions fails after rules, Hosting is not deployed and rules may already have changed. Pause, record which targets succeeded, and obtain the owner's decision to fix forward or restore reviewed prior rules/Functions/Hosting revisions. Never rerun blindly or run cleanup as a rollback. Review backward compatibility of existing clients with the new rules before the first release.
