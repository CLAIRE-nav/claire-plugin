---
name: JENKINS_WORKFLOW
description: "JSF Jenkins CI/CD — build, deploy, track procedures"
type: knowledge
keywords: [jenkins, ci-cd, pipeline, deploy, build, track, navair, jsf]
updated: 2026-04-10
---

# Jenkins CI/CD Workflow

JSF uses Jenkins as the CI/CD orchestrator. All pipelines are defined as
`Jenkinsfile`s in the `jsf_deployment` repo.

---

## Pipeline Inventory

| Pipeline | Trigger | Branch | What it does |
|----------|---------|--------|--------------|
| `jsf-ci-service` | PR + push to `main` | jsf_service | Compile, test, publish artifact to Nexus |
| `jsf-ci-gateway` | PR + push to `main` | jsf_gateway | Compile, test |
| `jsf-ci-web` | PR + push to `main` | jsf_web | `npm ci`, lint, test, build |
| `jsf-deploy-dev` | Auto after `main` merge | all | Deploy all 3 services to dev |
| `jsf-deploy-staging` | Manual + release tag | all | Deploy to staging (requires 1 approval) |
| `jsf-deploy-prod` | Manual | all | Deploy to prod (requires 2 approvals) |

---

## Build Procedure

### Triggering a build manually

```bash
# Via curl (set JENKINS_URL, JENKINS_USER, JENKINS_TOKEN in ENVIRONMENT)
curl -X POST "$JENKINS_URL/job/jsf-ci-service/build" \
  --user "$JENKINS_USER:$JENKINS_TOKEN"

# Via claire (after ENVIRONMENT config)
claire jsf build jsf_service
# Note: claire jsf build runs local Maven/npm — NOT Jenkins
# For Jenkins builds, use the curl above or Jenkins UI
```

### Build status check

```bash
curl -s "$JENKINS_URL/job/jsf-ci-service/lastBuild/api/json" \
  --user "$JENKINS_USER:$JENKINS_TOKEN" | jq '.result, .url'
```

---

## Deploy Procedure

### Deploy to dev (automated)
- Push or merge to `main` on any of the 3 service repos
- GitHub webhook triggers `jsf-deploy-dev` automatically
- Pipeline pulls latest `main` from all 3 repos and deploys

### Deploy to staging (manual)

1. Cut a release tag on each repo:
   ```bash
   git tag v1.2.0 && git push origin v1.2.0
   ```
2. Trigger `jsf-deploy-staging` in Jenkins UI or via API
3. Jenkins fetches the matching tag, builds, and deploys
4. One approver clicks "Proceed" in the Jenkins input step

### Deploy to prod (manual, gated)

1. Staging deploy must have passed (checked by pipeline)
2. Trigger `jsf-deploy-prod` manually
3. Two approvers must click "Proceed" within 1 hour
4. Pipeline deploys with zero-downtime rolling strategy

---

## Jenkinsfile Structure (jsf_deployment)

```
jsf_deployment/
├── Jenkinsfile.ci-service       # CI for jsf_service
├── Jenkinsfile.ci-gateway       # CI for jsf_gateway
├── Jenkinsfile.ci-web           # CI for jsf_web
├── Jenkinsfile.deploy-dev       # Deploy to dev
├── Jenkinsfile.deploy-staging   # Deploy to staging
├── Jenkinsfile.deploy-prod      # Deploy to prod
├── ansible/
│   ├── deploy-service.yml
│   ├── deploy-gateway.yml
│   └── deploy-web.yml
└── docker/
    ├── docker-compose.dev.yml
    ├── oracle-local.yml
    └── mq-local.yml
```

---

## Tracking a Build

### In Jenkins UI
- Navigate to `$JENKINS_URL/job/<pipeline-name>/`
- Click the latest build number
- "Console Output" for full logs

### Via API
```bash
# Last build result
curl -s "$JENKINS_URL/job/<pipeline>/lastBuild/api/json" \
  --user "$JENKINS_USER:$JENKINS_TOKEN" \
  | jq '{result: .result, number: .number, url: .url, duration: .duration}'

# Build console log
curl -s "$JENKINS_URL/job/<pipeline>/lastBuild/consoleText" \
  --user "$JENKINS_USER:$JENKINS_TOKEN" | tail -50
```

---

## Common Failures

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `jsf-ci-service` fails on test | Oracle connection in CI | Check `application-ci.yml` datasource; Oracle Docker in CI must be running |
| `jsf-deploy-dev` stuck | Approval timeout | Check Jenkins `jsf-deploy-dev` input step — hit "Abort" and retrigger |
| `jsf-ci-web` fails on lint | ESLint rule violation | Run `npm run lint` locally, fix, re-push |
| MQ connection refused in service | IBM MQ not started | `docker-compose -f docker/mq-local.yml up -d` |
| Nexus artifact not found | `jsf-ci-service` didn't publish | Run `jsf-ci-service` CI first, then `jsf-ci-gateway` |

---

## Environment Variables Required by Jenkins

All set in Jenkins Credentials (Manage Jenkins → Credentials):

| Variable | What |
|----------|------|
| `ORACLE_URL` | JDBC URL for target environment |
| `ORACLE_USER` / `ORACLE_PASSWORD` | DB credentials |
| `MQ_HOST` / `MQ_CHANNEL` / `MQ_QMGR` | IBM MQ connection |
| `NEXUS_USER` / `NEXUS_PASSWORD` | Artifact publish credentials |
| `DOCKER_REGISTRY` | Registry for Docker images |
| `ANSIBLE_VAULT_PASSWORD` | Ansible vault decrypt key |

These are injected into the build environment by the Jenkinsfile's `credentials()` block.
Never commit credentials to source — use Jenkins Credential Store.
