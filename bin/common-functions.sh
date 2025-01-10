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
#   - PROJECTS: (Optional) Space-separated list of projects to process, defaulting to the contents of `.repo/project.list`.
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
: "${PROJECTS:=$(cat .repo/project.list)}"

# shellcheck disable=SC2034 disable=SC2154
# root is used in other scripts, dir is injeted by the caller
root=$(readlink -f "${dir}/..")
: "${PROJECTS=$(cat .repo/project.list)}"
noof_projects=$(echo "${PROJECTS}" | wc -w | sed -e 's/ //g')
counter=0

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

  if ! test -r "${project}/pom.xml" && eval "${ONLY_MAVEN}"; then
    echo "${project} is not a Maven project (${counter}/${noof_projects})"
    return
  fi

  test ! -d "${project}" && echo "${project} does not exist" >&2 && return
  mkdir -p "logs/${project}"
  ext=""
  case "${project}" in
  "core/maven")
    ext="(no extension) "
    ;;
  *)
    mkdir -p "${project}/.mvn"
    ln -f develocity/*.xml "${project}/.mvn"
    ;;
  esac

  mvn="mvn"
  with="with"
  if test -r "${project}/mvnw"; then
    mvn="./mvnw"
  else
    with="without"
  fi
  logs="logs/${project}/${task}-$$-${counter}.log"
  echo -n "${project} (${counter}/${noof_projects}), a Maven project ${with} wrapper, build ${ext}"
  set +e
  (
    cd "${project}"
    # shellcheck disable=SC2086
    ${mvn} ${opts} ${goals} 2>&1
  ) > "${logs}"
  status="${?}"
  if test ${status} -ne 0; then
    echo "failed (logs: '${logs}')"
    test "${PREVIEW_LOGLINES:-0}" -gt 0 && tail -"${PREVIEW_LOGLINES}" "${logs}"
    if eval "${FAIL_FAST:-false}"; then
      echo "Failing fast and current execution failed with status '${status}'"
      exit ${status}
    fi
  else
    echo "succeeded"
  fi
  set -e
}
