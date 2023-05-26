# Library: util
# Script: utilities.sh
# Purpose: General utility functions that don't fall into any particular bucket
# CB: Nate Werner
# Created: 11/18/2017
#
##################

#includes
if [ -z "$BOOTSTRAP_LOADED" ]; then
  currentPath="$( cd "$(dirname "$0")" && pwd )"
  echo "currentP: $currentPath"
  source ${currentPath%${currentPath#*scripts*/}}library/bootstrap.sh
fi

# load domain tools
source $LIB_HOME/security.sh

function util::setLogFile()  #logfilepath
{
  gblLogFilePath="$1"

}
function util::log() # messageType,  MessageString
{
  local messageType="$1"
  local messageString="$2"
  local currentScript="$0"
  local currentDate="$(date +%y/%m/%d-%H:%M:%S )"
  local RED='\033[0;31m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[0;33m'
  local NC='\033[0m' # No Color
  if [[ -n "$gblLogFilePath" ]]; then
     maintLogFile="$gblLogFilePath"
  else
    if [[ -z "$maintLogFile" ]]; then
       maintLogFile="$MAINT_LOG_FILE"
    fi
  fi
  if [[ "$currentScript" == *bash* ]]; then
    currentScript=""
  fi

  if [[ "$debugFlag" == "y" && "$messageType" == "DEBUG" ]]; then
    # If in debug mode, display message to screen
    echo "    ${messageType}: $messageString"
    #local test=1
  elif [[ "$messageType" != "DEBUG" ]]; then
    if [[ "$messageType" == "ERROR" ]]; then
      echo -e "${RED}*${messageType}${NC}: $messageString"
    elif [[ "$messageType" == "WARNING" ]]; then
      echo -e "${YELLOW}${messageType}${NC}: $messageString"
    else
      echo -e "  ${GREEN}${messageType}${NC}: $messageString"
    fi
  fi
  # all logs types are written to file
  echo "$currentDate - $currentScript > $messageType: $messageString" >> $maintLogFile

}

function util::runDMS() # app, #env, DMS file, bootstrap=N
{
  local app="$1"
  local env="$2"
  local dbName="${app^^}${env^^}"
  local dmsFile="$3"
  local bootstrap="$4"
  local runHost=""
  local currentDateTime="$( date +%y%m%d_%H%M_%N )"
  local configFile="/psoft/admin/tmp/.dmxcfg${currentDateTime}.txt"
  local dmsResult=""
  local dmsExitCode=""
  local schedulerList=()
  local DBUser="SYSADM"
  local DMSPass=""
  local DMSUser="PS"
  local DMSLogDir="/psoft/logs/$app$env/dms"

  mkdir -p $DMSLogDir
  local majorToolsVer=$( inventory::getCurrentToolsAppEnv "$app" "$env" "prc")

  if [[ "$bootstrap" == "Y" || "$bootstrap" == "bootstrap" ]]; then
    DMSUser=$DBUser
    # DB Access PWD
    sec::getAppEnvDBSecurity "$app" "$env" DMSPass
    util::log "DEBUG" "Running DMS $dmsFile in Bootstrap mode"
  else
    # Get the PS password

    # lookup password based on tools verison of environment
    pwdToolsVersion="${majorToolsVer//.}"
    # now dynamically lookup each password and run script
    # first try matching to patch level
    util::log "INFO" "Trying Tools Patch Level Version for password lookup"
    #  Using poweruser (PS) as "Changer" running DMS
    sec::getGenSecurity "psoft_pass.apppoweruser.pt${pwdToolsVersion}.pass" AEPass
    if [ $? -ne 0 ]; then
       util::log "INFO" "Trying Major Tools Version for password lookup"
       # didn't match to a patch version of password, try just using major tools version
       sec::getGenSecurity "psoft_pass.apppoweruser.pt${pwdToolsVersion:0:3}.pass" DMSPass
    fi
    util::log "DEBUG" "Running DMS $dmsFile in User mode"
  fi

  inventory::getDomainsByEnv "$app" "$env" "prc" "" "$majorToolsVer" schedulerList
  # Grab the first scheduler, we'll run it there
  inventory::getDomainInfo "${schedulerList[0]}" "" "$majorToolsVer" prcAttribs
  runHost="${prcAttribs[$DOM_ATTR_HOST]}"
  util::log "DEBUG" "Using $runHost from domain ${schedulerList[0]} to run psdmtx"

  #Write config
  cat <<EOT > $configFile
-CT ORACLE
-CD ${dbName}
-CO ${DMSUser}
-CP "${DMSPass}"
-FP ${dmsFile}
EOT

  util::log "INFO" "Starting DMS $dmsFile on $app$env..."
  # Now run script on scheduler
  util::log "DEBUG" "Running DMS: source ${app}${env}.env && PS_SERVER_CFG=\$PS_CONFIG_HOME/appserv/prcs/${app}${env}/psprcs.cfg psdmtx $configFile"
  dmsResult=$( source ${app}${env}.env && PS_SERVDIR=$DMSLogDir && PS_SERVER_CFG=\$PS_CFG_HOME/appserv/prcs/${app}${env}/psprcs.cfg psdmtx $configFile 2>&1 )
  dmsExitCode=$?
  util::log "DEBUG" "DMS Exit Code: $dmsExitCode, Result: $dmsResult"
  if (( $dmsExitCode != 0 )); then
    return 1
  else
    return 0
  fi
}

function util::runAE() # app, #env, AE Program, RunControl_name
{
  local app="$1"
  local env="$2"
  local dbName="${app^^}${env^^}"
  local aeProgram="$3"
  local runControl="$4"
  local runHost=""
  local currentDateTime="$( date +%y%m%d_%H%M_%N )"
  local configFile="/psoft/admin/tmp/.aecfg${currentDateTime}.txt"
  local dmsResult=""
  local dmsExitCode=""
  local schedulerList=()
  local DBUser="SYSADM"
  local AEPass=""
  local AEUser="PS"
  local AELogDir="/psoft/logs/$app$env/ae"

  mkdir -p $AELogDir

  if [ -z "$runControl" ]; then
    runControl="psadmin.io"
  fi
  # Get the Changer/PS password
  local majorToolsVer=$( inventory::getCurrentToolsAppEnv "$app" "$env" "prc")
  # lookup password based on tools verison of environment
  pwdToolsVersion="${majorToolsVer//.}"

  # now dynamically lookup each password and run script
  # first try matching to patch level
  util::log "INFO" "Trying Tools Patch Level Version for password lookup"
  sec::getGenSecurity "psoft_pass.apppoweruser.pt${pwdToolsVersion}.pass" AEPass
  if [ $? -ne 0 ]; then
     util::log "INFO" "Trying Major Tools Version for password lookup"
     # didn't match to a patch version of password, try just using major tools version
     sec::getGenSecurity "psoft_pass.apppoweruser.pt${pwdToolsVersion:0:3}.pass" AEPass
  fi
  util::log "DEBUG" "Running AE Program $aeProgram as $AEUser"

  inventory::getDomainsByEnv "$app" "$env" "prc" "" "$majorToolsVer" schedulerList
  # Grab the first scheduler, we'll run it there
  inventory::getDomainInfo "${schedulerList[0]}" "" "$majorToolsVer" prcAttribs
  runHost="${prcAttribs[$DOM_ATTR_HOST]}"
  util::log "DEBUG" "Using $runHost from domain ${schedulerList[0]} to run psae"

  #Write config
  cat <<EOT > $configFile
-CT ORACLE
-CD ${dbName}
-CO ${AEUser}
-CP "${AEPass}"
-R ${runControl}
-AI ${aeProgram}
EOT

  util::log "INFO" "Starting program $aeProgram on $app$env..."
  # Now run script on scheduler
  util::log "DEBUG" "Running AE: $SSH_CMD $runHost \"source ${app}${env}.env && PS_SERVER_CFG=\$PS_CONFIG_HOME/appserv/prcs/${app}${env}/psprcs.cfg psae $configFile\""
  aeResult=$( $SSH_CMD $runHost "source ${app}${env}.env && PS_SERVDIR=$AELogDir && PS_SERVER_CFG=\$PS_CFG_HOME/appserv/prcs/${app}${env}/psprcs.cfg psae $configFile 2>&1" )
  aeExitCode=$?
  util::log "INFO" "AE Results: $aeResult"
  util::log "DEBUG" "AE Exit Code: $aeExitCode, Result: $aeResult"
  if (( $aeExitCode != 0 )); then
    return 1
  else
    return 0
  fi
}
