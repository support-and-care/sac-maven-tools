# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Maven Support & Care Tools - an automation toolkit for managing, building, and analyzing the Apache Maven multi-repository ecosystem. Uses the `repo` tool to manage 100+ Apache Maven repositories (manifest hosted at [maven-sources](https://github.com/apache/maven-sources)). Repositories are checked out into the `./maven` directory (a symlink to external storage) with `.repo` at `maven/.repo`.

## Prerequisites

- JDK 21
- Maven 3.9.9+
- `repo` tool (multi-repository management)

## Common Commands

### Repository Setup

```bash
# Initialize and sync repositories from maven-sources manifest
./bin/repo-start

# Execute command across all repos (from maven/ directory)
cd maven && repo forall -c "${PWD}/../bin/gh-subscribe"

# Execute on subset (by group)
cd maven && repo forall -r 'core' -c "${PWD}/../bin/some-script"
```

### Building Projects

```bash
# Build all projects
./bin/run-maven clean install

# Build with fail-fast and log preview on failures
FAIL_FAST=true PREVIEW_LOGLINES=50 ./bin/run-maven clean install

# Build specific projects only
PROJECTS="core/maven core/maven-resolver" ./bin/run-maven clean install

# Enable Develocity build scans
USE_DEVELOCITY=true ./bin/run-maven clean install
```

### jQAssistant Analysis

```bash
# Reset store and scan all projects
./bin/run-jqa reset scan

# Run analysis (after scanning)
./bin/run-jqa analyze

# Use remote Neo4j (bolt protocol)
./bin/run-jqa -r scan

# Other commands
./bin/run-jqa list-rules
./bin/run-jqa list-plugins
./bin/run-jqa effective-configuration
```

## Architecture

### Key Components

- **`bin/run-maven`**: Batch Maven executor for multiple projects. Uses `common-functions.sh` for shared logic. Generates per-project logs in `logs/`.

- **`bin/run-jqa`**: jQAssistant orchestration. Supports local file-based Neo4j store (default) or remote Bolt connection (`-r` flag).

- **`bin/common-functions.sh`**: Shared shell library. Provides `exec_mvn()` function, handles Maven wrapper detection, log generation.

- **`jqassistant/rules/`**: Custom Cypher-based constraints for code quality analysis.

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MAVEN_PROJECTS_DIR` | Directory containing Maven project checkouts | `maven` |
| `PROJECTS` | Space-separated list of project paths | Contents of `${MAVEN_PROJECTS_DIR}/.repo/project.list` |
| `USE_DEVELOCITY` | Enable Develocity build scans | `false` |
| `FAIL_FAST` | Exit on first build failure | `false` |
| `PREVIEW_LOGLINES` | Lines of log to show on failure | `0` |
| `JQA_VERSION` | jQAssistant plugin version | `2.6.0` |
| `SETTINGS` | Maven settings file path | `${PWD}/settings.xml` |

### Build Logs

All Maven execution output goes to `logs/<project>/<task>-<pid>-<counter>.log`. Console output is minimal (success/failure per project).

## jQAssistant Integration

Uses Neo4j graph database to analyze code structure across all Maven projects:

- **Store location**: `jqassistant/store/` (file-based) or `bolt://localhost:7687` (remote)
- **Rules**: `jqassistant/rules/apache-maven-rules.xml`
- **Config**: `.jqassistant.yml` (includes Git plugin for repository analysis)

## CI/CD

GitHub Actions workflow (`.github/workflows/maven-repo-reactor-build.yml`):
- Scheduled nightly builds on main branch
- Manual trigger with branch selection
- Uploads build logs and jQAssistant store as artifacts
