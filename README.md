# claire-plugin — CLAIRE-nav

Claire plugin for the NAVAIR JSF (Joint Strike Fighter) project.

Provides:
- JSF stack domain knowledge (4-repo architecture, Jenkins CI/CD, Oracle/MQ)
- `navair-dev` agent persona with domain priority stack
- `claire jsf` command for local build/test/status operations

## Installation

```bash
claire plugin install CLAIRE-nav/claire-plugin
```

This auto-installs specialty plugin dependencies:
- `CLAIRE-plugins/plugin-java` — Java/Spring patterns
- `CLAIRE-plugins/plugin-jenkins` — Jenkins CI/CD patterns
- `CLAIRE-plugins/plugin-oracle` — Oracle DB patterns

## Usage

```bash
# Stack status
claire jsf status

# Build a repo
claire jsf build jsf_service

# Run tests
claire jsf test jsf_web

# Deploy to dev
claire jsf deploy dev

# Context search
claire context "jsf"       # → navair domains
claire context "java"      # → plugin-java domains

# Boot with navair-dev persona
claire boot
```

## Domain Documents

| Document | Command |
|----------|---------|
| JSF Stack Architecture | `claire domain read navair knowledge JSF_STACK` |
| Jenkins Workflow | `claire domain read navair knowledge JENKINS_WORKFLOW` |
| Developer Environment | `claire domain read navair operational ENVIRONMENT` |
| Multi-Repo Interactions | `claire domain read navair technical MULTI_REPO` |
| navair-dev Persona | `claire domain read navair persona navair-dev` |

## Stack

- **Backend:** Java 17 + Spring Boot 3.x + Spring Cloud Gateway
- **Frontend:** Node 18 + Vue 3 + Vite
- **Database:** Oracle 19c (Flyway migrations)
- **Messaging:** IBM MQ 9.x
- **CI/CD:** Jenkins (Jenkinsfiles in `jsf_deployment`)
- **Platforms:** Windows (Git Bash) + Mac (zsh)

## Repos

| Repo | Stack | Role |
|------|-------|------|
| `jsf_service` | Java/Spring Boot | Business logic + REST APIs |
| `jsf_gateway` | Spring Cloud Gateway | Routing + JWT auth |
| `jsf_web` | Vue 3 / Vite | Browser frontend |
| `jsf_deployment` | Jenkins + Ansible | CI/CD + infrastructure |
