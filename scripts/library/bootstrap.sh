#!/usr/bin/env bash
#
# Script: bootstrap.sh
# Descr: Support a "base" path where script git repository is located
#     :   allows a portable location of scripts/config/ansible based
#     :   on where the script that sources this file.
#     : Supports a known "scripts" or "scripts_prod" path
#     : If under "scripts_prod", config and ansible is assumed under 
#         to be "*_prod" folder to support a consistent "Production" git branchs.
#     : Also allows to support any base patch in a user's work path
#
# To source this bootstrap file use this method:
#   # load bootstrap dynamic path assuming 'script' is in the path
#   currentPath="$( cd "$(dirname "$0")" && pwd )"
#   source ${currentPath%${currentPath#*scripts*/}}library/bootstrap.sh
#
############################

# PSSA/user base folder for scripts
# dynamically discover path to support any path to "scripts*"
# All scripts using libraries must use PS_SCRIPT_BASE
# Will prevent resetting PS_SCRIPT_BASE if already set,
#    as this will not work if called in a parallel command
if [[ -z "$PS_SCRIPT_BASE" ]]; then
  currentPath="$( cd "$(dirname "$0")" && pwd )"
  PS_SOURCE_BASE="${currentPath%scripts*}"
  PS_SCRIPT_BASE="${currentPath%${currentPath#*scripts*/}}"
  # export so spawned subprocesses can use it
  export PS_SOURCE_BASE
  export PS_SCRIPT_BASE
fi

## Setup the main supporting paths from script base
export LIB_HOME="${PS_SCRIPT_BASE}library"
export MAINT_HOME="${PS_SCRIPT_BASE}maint"
export SCRIPT_HOME="${PS_SCRIPT_BASE}"
## Special case, if in prod git branch/path, use prod ansible/config
if [[ "$SCRIPT_HOME" == *prod* ]]; then 
  export ANSIBLE_HOME="${PS_SOURCE_BASE}ansible_prod"
  export CONFIG_HOME="${PS_SOURCE_BASE}config_prod"
else
  # for non prod path and any user development git path
  export ANSIBLE_HOME="${PS_SOURCE_BASE}ansible"
  export CONFIG_HOME="${PS_SOURCE_BASE}config"
fi
  

# Carry these to path
PATH="$MAINT_HOME:$PS_SCRIPT_BASE:$PATH"; export PATH

# standard SSH options
export SSH_CMD="ssh -o StrictHostKeyChecking=no"

# associative array field names for domainInfo, use these instead of 1, 2, 3, etc
#   for example:   ${domainInfo[$DOM_ATTR_HOST]} will return the host name
export DOM_ATTR_NAME="domainName"    # (domain ID appended with serverName for schedulers)
export DOM_ATTR_TYPE="type"          # (web, app, prc, els)
export DOM_ATTR_APP="app"            # (2 char code for apps)
export DOM_ATTR_ENV="env"            # (3 char code for envs)
export DOM_ATTR_REPORT="reporting"   # (Y/N for Reporting env)
export DOM_ATTR_PURPOSE="purpose"
export DOM_ATTR_SRVNAME="serverName"   # (for schedulers, ie: PSUNX)
export DOM_ATTR_HOST="host"
export DOM_ATTR_TOOLSVER="toolsVersion"
export DOM_ATTR_WEBVER="weblogicVersion"

## used to prevent re-running this bootstrap script in same session
export BOOTSTRAP_LOADED=yes
