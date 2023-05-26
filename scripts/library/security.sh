# Library: sec
# Script: security.sh
###########################

#includes
if [ -z "$BOOTSTRAP_LOADED" ]; then
  currentPath="$( cd "$(dirname "$0")" && pwd )"
  source ${currentPath%${currentPath#*scripts*/}}library/bootstrap.sh
fi

# Passwords are stored in the ansible vault and secured with a password.
#  Check password for vault in Password Safe

# Use this function to get a password for a service that is not app/env specific
#   Applies to services like f5, rundeck, connect, common psoft users etc
function sec::getGenSecurity() #typeCode, out typePassword
{
   local ansibleVar="$1"
   local varPass=$2
   local currentDate=""
   local VaultPass_File=""
   local passwdKey=""
   local reqPasword=""
   local vaultResult=0

   if [ -z "$ansibleVar" ]; then
     util::log "ERROR" "The Code or Ansible Variable string is required"
     return 1
   fi

   # Lookup key from type provided
   if [[ "${ansibleVar:0:2}" == "DB" ]]; then
     # extract the app/env string in the type ie: 'DB:cstst'
     #  and build the variable like 'psoft_pass.db.cstst.pass', stored in group_vars/all/var file.
     passwdKey="psoft_pass.db.${ansibleVar:3}.pass"
   else
     passwdKey=$ansibleVar
   fi

   util::log "DEBUG" "sec::getGenSecurity: Mapped code to Key $passwdKey"
   # got a valid key, lookup password
   # run ansible to read password from vault

   # Check if Vault password was provided by env var
   if [ -n "$ANSIBLE_VAULT" ]; then
       # create a unique temporary vault password file
       currentDate="$(date +%y%m%d%H%M%S%N )"
       VaultPass_File="$ANSIBLE_HOME/tmp/ggsv_${PARALLEL_SEQ}_$currentDate"
       # use function getvaultaccess to encrypt the ANSIBLE_VAULT variable
       echo "$ANSIBLE_VAULT" | openssl enc -aes-256-cbc -md sha256 -a -d -salt -pass env:USER 2>/dev/null > $VaultPass_File
       chmod 600 $VaultPass_File
       util::log "DEBUG" "sec::getGenSecurity: Running ansible localhost --vault-password-file $VaultPass_File -m debug -a \"var=${passwdKey}\""
       reqPasword=$( cd $ANSIBLE_HOME && ANSIBLE_LOG_PATH=/dev/null ansible localhost --vault-password-file $VaultPass_File -m debug -a "var=${passwdKey}" | grep "${passwdKey}" | awk -F'"' '{ print $4}' )
   else
       # no password provide, will be prompted
       util::log "DEBUG" "sec::getGenSecurity: Running ansible localhost --ask-vault-pass -m debug -a \"var=${passwdKey}\""
       #reqPasword=$( cd $ANSIBLE_HOME && ANSIBLE_LOG_PATH=/dev/null ansible localhost --ask-vault-pass -m debug -a "var=${passwdKey}" | grep "${passwdKey}" | awk -F'"' '{ print $4 }' | sed 's/\$/\\$/' )
       reqPasword=$( cd $ANSIBLE_HOME && ANSIBLE_LOG_PATH=/dev/null ansible localhost --ask-vault-pass -m debug -a "var=${passwdKey}" | grep "${passwdKey}" | awk -F'"' '{ print $4 }' )
   fi
   vaultResult=$?
   if [ -n "$ANSIBLE_VAULT" ]; then
     rm $VaultPass_File > /dev/null 2>&1
   fi
   if [[ "${reqPasword}" == "VARIABLE IS NOT DEFINED!" ]]; then
     util::log "WARNING" "Unable to retrive password from vault!"
     return 1
   else
     eval "$varPass"'="${reqPasword}"'
     return 0
   fi
}

# Prompts for vault password and stores in encrypted variable
# used my maint library to store vault pass before using for
# other passwords, prevents user needing to be reprompted
# in same session of a maint function.  Works for remote
# function calls by parameter
function sec::getandStoreVaultAccess()
{
   local vaultPass
   local encryptPass=""

   # Bypass if running from RunDeck
   if sec::setRDVaultAccess; then
     util::log "DEBUG" "sec::getandStoreVaultAccess - Read Rundeck provided password"
     return 0
   else
     # Only allow PSSA user access to function
     if sec::isValidUser; then
       util::log "DEBUG" "sec::getandStoreVaultAccess: Valid user retreiving password for vault"

       if [ -z "$ANSIBLE_VAULT" ]; then
         # Call the security access function for the vault pass
         sec::getGenSecurity "vault" vaultPass
         if [[ $? -ne 0 ]]; then
           return 1
         fi
         encryptPass=$( echo "$vaultPass" | openssl enc -aes-256-cbc -md sha256 -a -salt -pass env:USER )
         util::log "DEBUG" "sec::getandStoreVaultAccess - Store vault pass $encryptPass"
         export ANSIBLE_VAULT="${encryptPass}"
         return 0
       fi
     else
       util::log "ERROR" "You are not authorized to access psoft security"
       return 1
     fi
   fi
}

# Use for when it is passed by env variable (Rundeck)
function sec::setRDVaultAccess()
{
   if [ -n "$RD_OPTION_VAULTPASS" ]; then
     encryptPass=$( echo "$RD_OPTION_VAULTPASS" | openssl enc -aes-256-cbc -md sha256 -a -salt -pass env:USER )
     util::log "DEBUG" "sec::getandStoreVaultAccess - Store vault pass $encryptPass"
     export ANSIBLE_VAULT="${encryptPass}"
     return 0
   else
     return 1
   fi
}

# Use this function to get a password for a service this is unique to an app/env
#   Specifically applies to DB schema owners for PSoft envs.
function sec::getAppEnvDBSecurity() #app, env, out typePassword
{
   local app="$1"
   local env="$2"
   local varPass=$3
   # prefix with 'DB:' to identify a DB pasword for specific app/env
   local typeCode="DB:$app$env"
   local dbPass
   local secResult=0

   util::log "DEBUG" "sec::getAppEnvDBSecurity Accessing pass for $typeCode"
   sec::getGenSecurity "${typeCode}" dbPass
   secResult=$?
   eval "$varPass"'="${dbPass}"'
   return $secResult
}

