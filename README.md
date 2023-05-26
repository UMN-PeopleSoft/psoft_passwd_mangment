# Sample Scripts for automating password maintenance for PeopleSoft

Provided are some sample scripts we use to help automate the update password process for an infrastructure with a large number of PeopleSoft environments and applications.
This procces is currently tied to passwords based on a PeopleTools patch release, but we continue to look for improved methods for unscheduled automation.

## changeUserPassword
 Script to run dynamic DMS file to update a single PeopleSoft User password.  This would not trigger IB messaging, so needs to be ran in all applications in the same environment (unified/SSO setup)

## bulkPSUserPwdUpdate 
Bulk password script to run "ChangeUserPassword" for a full set of managed users in Peoplesoft.  Adds ability to extract all passwords from vault by tools version instead of prompting for password.  Adds ability to select which password to use for the "changer" user that runs DMS.

## changeIBPassword 
Script to update IB Node password in all applications that are part of a SSO Unified setup. To accomplish this a custom ACM class and Template was created to support this process.
  
### PTEM_CONFIG_UM_pcode_ib.txt 
App Package PeopleCode for the custom ACM Template to update local and remote Node passwords.

## changeAccessPassword 
Script to automate the access ID password change using the CHANGE_ACCESS_PASSWORD function in DMS.

## sample_vault
A Sample yaml structure to organize passwords in a vault file.
