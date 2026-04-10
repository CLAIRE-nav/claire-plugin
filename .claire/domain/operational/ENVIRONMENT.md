---
name: ENVIRONMENT
description: "NAVAIR JSF developer environment — Windows/Mac paths, credentials, and tool setup"
type: operational
keywords: [environment, windows, mac, paths, credentials, tools, git-bash, zsh, navair, jsf]
updated: 2026-04-10
---

# NAVAIR Developer Environment

JSF developers work on both **Windows** (primary workstation) and **Mac** (personal/lab).
This document covers paths, tools, and credential setup for both platforms.

---

## Platform Detection

```bash
# In scripts — detect platform
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OS" == "Windows_NT" ]]; then
  PLATFORM="windows"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  PLATFORM="mac"
else
  PLATFORM="linux"
fi
```

Windows developers run Git Bash or WSL2. Mac developers use zsh (default since macOS Catalina).

---

## Path Conventions

### Windows (Git Bash)

| Location | Path |
|----------|------|
| Repos root | `C:/dev/jsf/` or `/c/dev/jsf/` (Git Bash) |
| Maven home | `C:/dev/tools/apache-maven-3.9.x/` |
| Java home | `C:/Program Files/Eclipse Adoptium/jdk-17.x/` |
| Node/npm | `C:/Program Files/nodejs/` |
| Jenkins home | `C:/jenkins/` (local agent) |
| Oracle Wallet | `C:/oracle/wallet/` |

#### JAVA_HOME (Windows Git Bash)
```bash
export JAVA_HOME="/c/Program Files/Eclipse Adoptium/jdk-17.0.9+9"
export PATH="$JAVA_HOME/bin:$PATH"
```

#### MAVEN_HOME (Windows Git Bash)
```bash
export MAVEN_HOME="/c/dev/tools/apache-maven-3.9.6"
export PATH="$MAVEN_HOME/bin:$PATH"
```

### Mac (zsh)

| Location | Path |
|----------|------|
| Repos root | `~/dev/jsf/` |
| Maven | Homebrew: `/opt/homebrew/opt/maven/` or SDKMAN |
| Java | SDKMAN: `~/.sdkman/candidates/java/17.x/` or Homebrew |
| Node/npm | nvm: `~/.nvm/versions/node/v18.x/` |
| Oracle Wallet | `~/oracle/wallet/` |

#### .zshrc additions
```bash
# Java (SDKMAN)
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
```

---

## Credential Setup

### Oracle Database

Credentials are stored in an Oracle Wallet (not plain text).

| Env Var | Description |
|---------|-------------|
| `TNS_ADMIN` | Path to Oracle Wallet directory |
| `ORACLE_USER` | Database username |
| `ORACLE_PASSWORD` | Database password (from wallet in CI) |

**Local setup:**
```bash
# Set TNS_ADMIN to wallet dir
export TNS_ADMIN=/path/to/wallet

# application-local.yml (DO NOT COMMIT)
spring:
  datasource:
    url: jdbc:oracle:thin:@jsf_dev_tns?TNS_ADMIN=${TNS_ADMIN}
    username: ${ORACLE_USER}
    password: ${ORACLE_PASSWORD}
```

### IBM MQ

| Env Var | Description |
|---------|-------------|
| `MQ_HOST` | MQ broker hostname or IP |
| `MQ_PORT` | Port (default 1414) |
| `MQ_QMGR` | Queue manager name |
| `MQ_CHANNEL` | Channel name |
| `MQ_USER` / `MQ_PASSWORD` | Auth credentials |

**Local (Docker):**
```bash
export MQ_HOST=localhost
export MQ_PORT=1414
export MQ_QMGR=QM1
export MQ_CHANNEL=DEV.APP.SVRCONN
export MQ_USER=app
export MQ_PASSWORD=passw0rd
```

### Jenkins

| Env Var | Description |
|---------|-------------|
| `JENKINS_URL` | Jenkins base URL |
| `JENKINS_USER` | Jenkins username |
| `JENKINS_TOKEN` | Jenkins API token |

**Retrieve your API token:**
1. Log into Jenkins UI
2. Click your username (top right) → Configure
3. Add new Token → copy it
4. Set: `export JENKINS_TOKEN=<your-token>`

### Nexus (Maven artifacts)

Add to `~/.m2/settings.xml`:
```xml
<servers>
  <server>
    <id>jsf-nexus</id>
    <username>${NEXUS_USER}</username>
    <password>${NEXUS_PASSWORD}</password>
  </server>
</servers>
```

---

## Required Tools

### All Platforms

| Tool | Version | Install |
|------|---------|---------|
| Git | 2.40+ | System package manager |
| JDK | 17 (Eclipse Temurin) | SDKMAN (Mac) / direct installer (Win) |
| Maven | 3.9+ | SDKMAN / Homebrew / direct installer |
| Node.js | 18 LTS | nvm |
| npm | 9+ | bundled with Node |
| Docker | 24+ | Docker Desktop |
| curl | any | bundled |
| jq | 1.6+ | Homebrew / winget |

### Windows-specific

| Tool | Purpose |
|------|---------|
| Git Bash (Git for Windows) | Unix-compatible shell |
| WinSCP | SFTP for file transfers |
| DBeaver Community | Oracle DB GUI client |
| MQ Explorer | IBM MQ administration GUI |

### Mac-specific

| Tool | Purpose |
|------|---------|
| Homebrew | Package manager |
| iTerm2 | Recommended terminal |
| DBeaver Community | Oracle DB GUI client |

---

## Local `.env` Template

Create `jsf_service/.env.local` (gitignored):

```bash
# Oracle
TNS_ADMIN=/path/to/wallet
ORACLE_USER=jsf_dev_user
ORACLE_PASSWORD=change_me

# MQ
MQ_HOST=localhost
MQ_PORT=1414
MQ_QMGR=QM1
MQ_CHANNEL=DEV.APP.SVRCONN
MQ_USER=app
MQ_PASSWORD=passw0rd

# Spring
SPRING_PROFILES_ACTIVE=local

# Jenkins (only for admin tasks)
JENKINS_URL=https://jenkins.navair.internal
JENKINS_USER=your.username
JENKINS_TOKEN=your-api-token
```

Load with: `set -a && source .env.local && set +a`

---

## SSH / Git Configuration

```bash
# Generate SSH key for GitHub (if not already done)
ssh-keygen -t ed25519 -C "firstname.lastname@navair.mil"

# Add to ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Test
ssh -T git@github.com
```

Add the public key (`~/.ssh/id_ed25519.pub`) to your GitHub profile under Settings → SSH keys.

### Windows Git Bash
```bash
# Start agent automatically — add to ~/.bashrc
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```
