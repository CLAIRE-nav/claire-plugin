---
name: JSF_STACK
description: "JSF (Joint Strike Fighter) — 4-repo architecture, stack overview, and build relationships"
type: knowledge
keywords: [jsf, navair, architecture, java, spring, vue, oracle, mq, four-repo, stack]
updated: 2026-04-10
---

# JSF Stack — Architecture Overview

The JSF (Joint Strike Fighter) project is organized across 4 repositories in the CLAIRE-nav GitHub org.

---

## Stack at a Glance

| Layer | Technology | Repo |
|-------|-----------|------|
| Backend services | Java 17 + Spring Boot 3.x | `jsf_service` |
| API gateway | Java 17 + Spring Cloud Gateway | `jsf_gateway` |
| Frontend | Node 18 + Vue 3 + Vite | `jsf_web` |
| Deployment | Jenkins + Ansible + Docker Compose | `jsf_deployment` |
| Database | Oracle 19c | shared |
| Messaging | IBM MQ 9.x | shared |

---

## Repository Overview

### jsf_service
- **Role:** Core business logic and REST APIs
- **Tech:** Java 17, Spring Boot 3.x, Spring Data JPA, Spring AMQP
- **Build:** Maven (`mvn clean package`)
- **Test:** JUnit 5 + Mockito (`mvn test`)
- **Port:** 8080 (local)
- **Exposes:** `/api/v1/**` internal endpoints consumed by `jsf_gateway`
- **DB:** Oracle via Hikari connection pool (`application.yml` datasource)
- **MQ:** IBM MQ queues for async event publishing

### jsf_gateway
- **Role:** API gateway — routing, auth, rate limiting, CORS
- **Tech:** Java 17, Spring Cloud Gateway, Spring Security (JWT)
- **Build:** Maven (`mvn clean package`)
- **Test:** JUnit 5 + Spring WebFlux test (`mvn test`)
- **Port:** 8090 (local)
- **Exposes:** Public-facing `/api/**` — proxies to `jsf_service`
- **Auth:** JWT validation at gateway layer; passes claims downstream

### jsf_web
- **Role:** Browser UI
- **Tech:** Node 18, Vue 3, Vite, Pinia, Axios
- **Build:** `npm ci && npm run build`
- **Test:** Vitest (`npm test`)
- **Port:** 5173 (Vite dev server) | served from nginx in staging/prod
- **API base URL:** Configured via `VITE_API_URL` env var → points to `jsf_gateway`

### jsf_deployment
- **Role:** Infrastructure and deployment orchestration
- **Contents:** Jenkinsfiles, Ansible playbooks, Docker Compose files, environment configs
- **No build step** — executed by Jenkins pipelines
- **Pipelines:**
  - `jsf-deploy-dev` — deploy to dev from `main`
  - `jsf-deploy-staging` — deploy to staging from tagged release
  - `jsf-deploy-prod` — deploy to prod (requires 2-approver gate)

---

## Build Order

When building from scratch:

```
1. jsf_service   (no internal deps)
2. jsf_gateway   (depends on jsf_service API contract — shared DTO jars)
3. jsf_web       (depends on jsf_gateway API spec)
4. jsf_deployment (triggers after all 3 artifact builds pass)
```

### Shared DTO Library
`jsf_service` publishes a `jsf-api-contracts` Maven artifact to the internal Nexus registry.
`jsf_gateway` imports this artifact as a dependency.

```xml
<!-- jsf_gateway/pom.xml -->
<dependency>
  <groupId>mil.navair.jsf</groupId>
  <artifactId>jsf-api-contracts</artifactId>
  <version>${jsf.contracts.version}</version>
</dependency>
```

---

## Local Development Setup

### Prerequisites
- JDK 17 (`JAVA_HOME` set)
- Maven 3.8+
- Node 18 + npm 9+
- Oracle client (or Docker: `jsf_deployment/docker/oracle-local.yml`)
- IBM MQ client (or Docker: `jsf_deployment/docker/mq-local.yml`)

### Start local dependencies
```bash
cd jsf_deployment
docker-compose -f docker/oracle-local.yml -f docker/mq-local.yml up -d
```

### Run services
```bash
# Terminal 1 — service
cd jsf_service && mvn spring-boot:run

# Terminal 2 — gateway
cd jsf_gateway && mvn spring-boot:run

# Terminal 3 — web
cd jsf_web && npm run dev
```

---

## Environment Configuration

See `ENVIRONMENT` domain for full path/credential/tool details:
```bash
claire domain read navair operational ENVIRONMENT
```

---

## Key Patterns

### Spring Profile Convention
- `local` — local dev, H2 in-memory or Docker Oracle
- `dev` — dev server (auto-deployed from main)
- `staging` — pre-prod
- `prod` — production

Activate with: `SPRING_PROFILES_ACTIVE=local`

### Versioning
All 4 repos version together. Release tags use the form `v{MAJOR}.{MINOR}.{PATCH}`.
When a release is cut, `jsf_deployment` Jenkinsfile pulls matching tags from the other 3 repos.

### Database Migrations
`jsf_service` uses Flyway. Migrations in `src/main/resources/db/migration/`.
Convention: `V{version}__{description}.sql`

### MQ Queue Names
| Queue | Direction | Consumer |
|-------|-----------|----------|
| `JSF.SERVICE.EVENTS` | OUT | External consumers |
| `JSF.COMMAND.INBOUND` | IN | jsf_service listens |
| `JSF.DLQ` | IN | Dead letter for failed processing |
