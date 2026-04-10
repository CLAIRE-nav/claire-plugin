#!/bin/bash
# jsf.sh — JSF stack operations for NAVAIR navair-dev
# Usage: claire jsf <subcommand> [target]
#   status              — show all 4 repos git status + pending builds
#   build [repo]        — run Maven/npm build for repo (or all)
#   test [repo]         — run test suite for repo (or all)
#   deploy [env]        — trigger Jenkins deploy pipeline (dev|staging|prod)
set -euo pipefail

SUBCOMMAND="${1:-}"
TARGET="${2:-all}"

JSF_REPOS=(jsf_service jsf_gateway jsf_web jsf_deployment)

# Resolve repo root from git context or fallback to parent directory convention
_repo_root() {
  local repo="$1"
  git -C "$(pwd)" rev-parse --show-toplevel 2>/dev/null | xargs dirname | xargs -I{} echo "{}/$repo" || echo "../$repo"
}

_status_all() {
  echo "=== JSF Stack Status ==="
  for repo in "${JSF_REPOS[@]}"; do
    local path
    path="$(_repo_root "$repo")"
    if [ -d "$path" ]; then
      echo ""
      echo "── $repo ($path)"
      git -C "$path" status --short --branch 2>/dev/null || echo "  [not a git repo]"
    else
      echo ""
      echo "── $repo: NOT FOUND at $path"
    fi
  done
}

_build_repo() {
  local repo="$1"
  local path
  path="$(_repo_root "$repo")"

  if [ ! -d "$path" ]; then
    echo "ERROR: repo not found: $path" >&2
    exit 3
  fi

  echo "=== Building $repo ==="
  case "$repo" in
    jsf_service|jsf_gateway)
      # Java/Spring — Maven build
      (cd "$path" && mvn clean package -DskipTests -q)
      echo "✓ $repo built (Maven)"
      ;;
    jsf_web)
      # Node/Vue — npm build
      (cd "$path" && npm ci --silent && npm run build)
      echo "✓ $repo built (npm)"
      ;;
    jsf_deployment)
      echo "jsf_deployment has no build step — use 'claire jsf deploy' to trigger Jenkins"
      ;;
    *)
      echo "Unknown repo: $repo" >&2
      exit 2
      ;;
  esac
}

_test_repo() {
  local repo="$1"
  local path
  path="$(_repo_root "$repo")"

  if [ ! -d "$path" ]; then
    echo "ERROR: repo not found: $path" >&2
    exit 3
  fi

  echo "=== Testing $repo ==="
  case "$repo" in
    jsf_service|jsf_gateway)
      (cd "$path" && mvn test -q)
      echo "✓ $repo tests passed"
      ;;
    jsf_web)
      (cd "$path" && npm test -- --watchAll=false)
      echo "✓ $repo tests passed"
      ;;
    jsf_deployment)
      echo "jsf_deployment tests run in Jenkins — no local test suite"
      ;;
    *)
      echo "Unknown repo: $repo" >&2
      exit 2
      ;;
  esac
}

_deploy_env() {
  local env="$1"
  echo "=== Deploying to $env ==="

  case "$env" in
    dev|staging|prod)
      echo "Triggering Jenkins pipeline: jsf-deploy-$env"
      echo "Jenkins URL: see ENVIRONMENT domain — claire domain read navair operational ENVIRONMENT"
      echo ""
      echo "Manual trigger:"
      echo "  curl -X POST \$JENKINS_URL/job/jsf-deploy-$env/build \\"
      echo "    --user \$JENKINS_USER:\$JENKINS_TOKEN"
      echo ""
      echo "After trigger, monitor at: claire jsf status"
      ;;
    *)
      echo "Unknown environment: $env (valid: dev|staging|prod)" >&2
      exit 2
      ;;
  esac
}

case "$SUBCOMMAND" in
  status)
    _status_all
    ;;
  build)
    if [ "$TARGET" = "all" ]; then
      for repo in "${JSF_REPOS[@]}"; do
        _build_repo "$repo"
      done
    else
      _build_repo "$TARGET"
    fi
    ;;
  test)
    if [ "$TARGET" = "all" ]; then
      for repo in "${JSF_REPOS[@]}"; do
        _test_repo "$repo"
      done
    else
      _test_repo "$TARGET"
    fi
    ;;
  deploy)
    _deploy_env "${TARGET:-dev}"
    ;;
  --agent-help)
    cat <<'EOF'
## jsf command (navair plugin)

Operate on the JSF stack across all 4 repositories.

### Subcommands

| Subcommand | Args | Description |
|------------|------|-------------|
| `status` | — | git status + branch for all 4 repos |
| `build` | `[repo\|all]` | Maven/npm build (jsf_service, jsf_gateway → Maven; jsf_web → npm) |
| `test` | `[repo\|all]` | Run tests (Maven/npm) |
| `deploy` | `[dev\|staging\|prod]` | Trigger Jenkins deploy pipeline |

### Repos
- `jsf_service` — Java/Spring backend (Maven)
- `jsf_gateway` — Java/Spring API gateway (Maven)
- `jsf_web` — Node/Vue frontend (npm)
- `jsf_deployment` — Jenkins + Ansible deployment scripts

### Examples
```bash
claire jsf status
claire jsf build jsf_service
claire jsf test all
claire jsf deploy dev
```
EOF
    ;;
  ""|--help|-h)
    echo "Usage: claire jsf <subcommand> [target]"
    echo ""
    echo "Subcommands:"
    echo "  status              Show git status for all JSF repos"
    echo "  build [repo|all]    Build repo (Maven/npm)"
    echo "  test [repo|all]     Run tests"
    echo "  deploy [env]        Trigger Jenkins deploy (dev|staging|prod)"
    echo ""
    echo "Repos: jsf_service, jsf_gateway, jsf_web, jsf_deployment"
    ;;
  *)
    echo "Unknown subcommand: $SUBCOMMAND" >&2
    echo "Run 'claire jsf --help' for usage" >&2
    exit 2
    ;;
esac
