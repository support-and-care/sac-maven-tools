# shellcheck shell=bash

# NAME
#   common-functions.sh - Shell library for managing and building Maven projects
#
# SYNOPSIS
#   Source this file in your shell script to gain access to helper functions for handling Maven projects.
#
# DESCRIPTION
#   This file is a shell script library intended to be sourced by other scripts.
#   It provides helper functions such as `exec_mvn` to build or handle Maven-based projects.
#   The script processes multiple projects at once and generates logs for each task performed.
#
# INPUT VARIABLES
#   - dir: (Required, injected by caller) The directory path injected by the caller. This is used to determine the root directory.
#   - ONLY_MAVEN: (Optional) If set to true (default), only Maven-based projects will be processed.
#   - MAVEN_PROJECTS_DIR: (Optional) Directory containing Maven project checkouts, defaults to `maven`.
#   - PROJECTS: (Optional) Space-separated list of projects to process, defaulting to the contents of `${MAVEN_PROJECTS_DIR}/.repo/project.list`.
#   - PREVIEW_LOGLINES: (Optional) Number of log lines to preview in case of a build failure.
#   - FAIL_FAST: (Optional) If set to true, the script will exit immediately upon a build failure.
#
# OUTPUT VARIABLES
#   - root: Absolute path to the parent directory of the given `dir`.
#   - noof_projects: Count of the projects being processed.
#   - Logs are stored per project under `logs/<project>/<task>-<pid>.log`.
#
# FUNCTIONS
#   exec_mvn(project, task, counter, opts, goals)
#       Executes the Maven build for a given project.
#       - project: Path to the Maven project directory.
#       - task: A descriptive name for the task (used in logs).
#       - counter: Current project number being processed.
#       - opts: Additional options for the Maven command.
#       - goals: Space-separated list of Maven goals to execute.
#
#       The function checks for the presence of `pom.xml` to identify a Maven project
#       and determines whether to use the Maven wrapper (`mvnw`) if available.
#       Logs build results (succeeded/failed) in the appropriate log directory.
#

: "${ONLY_MAVEN:=true}"
: "${MAVEN_PROJECTS_DIR:=maven}"
: "${SETTINGS:=${PWD}/settings.xml}"
# Find a Maven binary by version, searching known installation locations.
# Checks (in order): SDKman, GitHub Actions tool-cache, MAVEN_HOMES (custom).
# Returns the path to the mvn binary, or empty string if not found.
find_mvn_by_version() {
  local version="$1"
  local candidate

  # SDKman (local development)
  candidate="${HOME}/.sdkman/candidates/maven/${version}/bin/mvn"
  if [[ -x "${candidate}" ]]; then
    echo "${candidate}"
    return
  fi

  # GitHub Actions tool-cache (stCarolas/setup-maven)
  if [[ -n "${RUNNER_TOOL_CACHE:-}" ]]; then
    candidate="${RUNNER_TOOL_CACHE}/maven/${version}/x64/bin/mvn"
    if [[ -x "${candidate}" ]]; then
      echo "${candidate}"
      return
    fi
  fi

  # Custom location via MAVEN_HOMES (colon-separated list of base dirs)
  # Each dir is expected to contain <version>/bin/mvn
  local IFS=':'
  for base in ${MAVEN_HOMES:-}; do
    candidate="${base}/${version}/bin/mvn"
    if [[ -x "${candidate}" ]]; then
      echo "${candidate}"
      return
    fi
  done
}

# Select the appropriate Maven binary based on project path.
# Maven 4 projects are identified by having "-4/" in their path
# (e.g. plugins/core-4/*, plugins/packaging-4/*).
# The required Maven version is read from <mavenVersion> in pom.xml.
# MAVEN4_VERSION env var can override the auto-detected version.
select_mvn() {
  local project="$1"
  local project_dir="$2"
  if [[ "${project}" == *-4/* ]]; then
    local mvn4_version="${MAVEN4_VERSION:-}"
    if [[ -z "${mvn4_version}" && -r "${project_dir}/pom.xml" ]]; then
      mvn4_version=$(sed -n 's/.*<mavenVersion>\(.*\)<\/mavenVersion>.*/\1/p' "${project_dir}/pom.xml" | head -1)
    fi
    if [[ -z "${mvn4_version}" ]]; then
      echo "WARNING: ${project}: no <mavenVersion> found in pom.xml and MAVEN4_VERSION not set, falling back to system mvn" >&2
      echo "mvn"
      return
    fi
    local mvn4_bin
    mvn4_bin=$(find_mvn_by_version "${mvn4_version}")
    if [[ -n "${mvn4_bin}" ]]; then
      echo "${mvn4_bin}"
      return
    fi
    echo "WARNING: ${project}: Maven ${mvn4_version} not found in any known location, falling back to system mvn" >&2
  fi
  echo "mvn"
}

# shellcheck disable=SC2034 disable=SC2154
# root is used in other scripts, dir is injected by the caller
root=$(readlink -f "${dir}/..")
[[ -z "${PROJECTS:-}" ]] && PROJECTS="$(cat ${root}/${MAVEN_PROJECTS_DIR}/.repo/project.list)"
noof_projects=$(echo "${PROJECTS}" | wc -w | sed -e 's/ //g')
counter=0

# Only set maven.repo.local if not already configured in MAVEN_OPTS
MAVEN_REPO_LOCAL_OPT=""
if [[ ! "${MAVEN_OPTS:-}" =~ maven.repo.local ]]; then
  MAVEN_REPO_LOCAL_OPT="-Dmaven.repo.local=${root}/.m2/repository"
fi

exec_mvn() {
  project=$1
  shift
  task=$1
  shift
  counter=$1
  shift
  opts=$1
  shift
  goals=${*}

  # Full path to project directory (under MAVEN_PROJECTS_DIR)
  project_dir="${root}/${MAVEN_PROJECTS_DIR}/${project}"

  if ! test -r "${project_dir}/pom.xml" && eval "${ONLY_MAVEN}"; then
    echo "${project} is not a Maven project (${counter}/${noof_projects})"
    return
  fi

  test ! -d "${project_dir}" && echo "${project} does not exist" >&2 && return
  mkdir -p "${root}/logs/${project}"
  ext=""
  case "${project}" in
  "core/maven")
    ext=" (no extension)"
    ;;
  *)
    mkdir -p "${project_dir}/.mvn"
    ln -f "${root}/develocity"/*.xml "${project_dir}/.mvn"
    ;;
  esac

  mvn_info=""
  if test -r "${project_dir}/mvnw"; then
    mvn="./mvnw"
    mvn_info="with wrapper"
  else
    mvn=$(select_mvn "${project}" "${project_dir}")
    if [[ "${mvn}" != "mvn" ]]; then
      local detected_version
      detected_version=$(echo "${mvn}" | sed 's|.*/maven/\([^/]*\)/.*|\1|')
      mvn_info="without wrapper (using Maven ${detected_version})"
    else
      mvn_info="without wrapper"
    fi
  fi
  logs="${root}/logs/${project}/${task}-$$-${counter}.log"
  echo -n "${project} (${counter}/${noof_projects}), a Maven project ${mvn_info}, build (logs: '${logs}') "
  set +e
  (
    cd "${project_dir}"
    # shellcheck disable=SC2086
    ${mvn} -B -s "${SETTINGS}" ${opts} ${goals} 2>&1
  ) > "${logs}"
  status="${?}"
  if test ${status} -ne 0; then
    echo "failed${ext}"
    test "${PREVIEW_LOGLINES:-0}" -gt 0 && tail -"${PREVIEW_LOGLINES}" "${logs}"
    if eval "${FAIL_FAST:-false}"; then
      echo "Failing fast and current execution failed with status '${status}'"
      exit ${status}
    fi
  else
    echo "succeeded${ext}"
  fi
  set -e
}