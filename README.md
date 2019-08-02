# CM-ClearSoftwareUpdateGroups

Script to clear Configuration Manager current branch Software Update Groups (SUG) created by active Automatic Deployment Rules (ADR).

For new machines or machines not connected for long time the newest SUG with an already reached deadline will be kept, so machines are forced to install the updates.

A log-file ClearSUG_%DATE%.log is created in LogFolder (%TEMP% as default).
# Prerequisites
The script uses Configuration Manager CMDlets, so it needs to run on a machine with Configuration Manager console installed.
# Deployment
The script has two mandatory parameters:

**CMSiteCode**: Configuration Manager site code

**CMProviderMachineName**: Machine name of the Configuration Manager SMSProvider to be used by the script.

The easiest way is to create a Scheduled Task with an action like “Clear_SoftwareUpdateGroups.ps1 SBX CM01.mydemodomain.local”
# License
This project is licensed under the MIT License - see the LICENSE.md file for details
