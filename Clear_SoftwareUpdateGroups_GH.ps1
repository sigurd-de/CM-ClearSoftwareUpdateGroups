<#
.Synopsis
Script to delete Software Update Groups that reached the deadline

.DESCRIPTION
Script to clear Software Update Groups created by active Automatic Deployment Groups.
For new machines or machines not connected for long time the newest SUG with an already reached deadline
will be kept,so machines are forced to install the updates.
A log-file ClearSUG_%DATE%.log is created in LogFolder

.PARAMETER CMSiteCode
Configuration Manager site code [mandatory]
.PARAMETER CMProviderMachineName [mandatory]
Machine name of Configuration Manager SMSProvider to be used by the script [mandatory]

.Notes
ADRs[] = GetADRNames
for ADR in ADRs {
  SoftwareUpdateGroupNameTemplate = ADR.Name + *
  
  SUGNT = SoftwareUpdateGroupNameTemplate
  SUGDeadline = [SUG.Name, SUG.Deadline]

  AllSUGs[] = GetAllSUG -SUGNT

  for AllSUG in AllSUGs {
    AllSUGDPs[] =  Get-Deployment -AllSUG
    for AllSUGDP in ALLSUGDPs {
      If AllSUGDP.Deadline > SUGDeadline[AllSUGDP].Deadline OR !SUGDeadline[AllSUGDP].Deadline {
        SUGDeadline[AllSUGDP].Name = AllSUGDP.Name
        SUGDeadline[AllSUGDP].Deadline = AllSUGDP.Deadline
      }
    }
  }
  
  Sort-Array SUGDeadline by Deadline NewToOld

  For SUGDeadlineDate in SUGDeadline {
    if ToBeDeleted {
      ToBeDeletedSUG.Name = SUGDeadlineDate.Name
    }
    else {
      if SUGDeadline.Deadline < Current DateTime {
        ToBeDeletedSUG = True
      }
    }
  }
}

#>

Param(
 [Parameter (Mandatory=$true)][string]$CMSiteCode,
 [Parameter (Mandatory=$true)][string]$CMProviderMachineName
)

# Prepare log-file
$LogFolder = $env:TEMP
$Logfile = "ClearSUG_" + (Get-Date -Format FileDateTimeUniversal)
$LogPath = "$LogFolder\$Logfile.log"
if (!(Test-Path -LiteralPath $LogPath)) {
    New-Item -Path $LogPath  -ItemType file -Force
}

Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) -->Start maintenance"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) -->Start initialization step"
# Import the ConfigurationManager.psd1 module 
$initParams = @{}
if(!(Get-Module ConfigurationManager)) {
  Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) PoSh module loaded"

# Connect to the site's drive if it is not already present
if(!(Get-PSDrive -Name $CMSiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
  New-PSDrive -Name $CMSiteCode -PSProvider CMSite -Root $CMProviderMachineName @initParams
}
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Connected to CM site"

# Set the current location to be the site code.
Set-Location "$($CMSiteCode):\" @initParams

Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Set location = $CMSiteCode"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) <--Finished initialization step"


$SUGDDeadlineList = @{}
$SUGDDeadlineListSorted = @{}
New-Variable -Name DeadLineMax
$ToBeDeleted = $false
$Now = Get-Date

Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) -->Start ADR"
# Get all ADRs
$ADRs = Get-CMSoftwareUpdateAutoDeploymentRule -Name "*" -ForceWildcardHandling -Fast
foreach ($ADRItem in $ADRs) {
  if ($ADRItem.AutoDeploymentEnabled) {
    # If the ADR is enabled
    $LogPrint = $ADRItem.Name
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Run ADR = $LogPrint"
    $SUGNameWildcard = $ADRItem.Name + "*"
    
    # Find all Software Update Groups
    $SUGroups =  Get-CMSoftwareUpdateGroup -Name $SUGNameWildcard -ForceWildcardHandling
    foreach ($SUGItem in $SUGroups) {
      $LogPrint = $SUGItem.LocalizedDisplayName
      Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Run SUG = $LogPrint"
    
      # Find all deployments for a SUG
      $SUGDeployments = Get-CMDeployment -FeatureType SoftwareUpdate -SoftwareName $SUGItem.LocalizedDisplayName
      if ($SUGDeployments) {
        foreach ($SUGDItem in $SUGDeployments) {
          #Search for the deadlines of a SUG deployment
          if (!$DeadLineMax) {
            [datetime]$DeadLineMax = $SUGDItem.EnforcementDeadline
          }
          elseif ($SUGDItem.EnforcementDeadline -gt $DeadLineMax) {
            #Keep the greatest (latest) deadline of a SUG deployment
            [datetime]$DeadLineMax = $SUGDItem.EnforcementDeadline
          }
        }  

        # Add to list
        if ($DeadLineMax) {
          $LogPrint = $SUGDItem.ApplicationName
          # A list of all greatest (latest) deadlines of all deployments of all SUGs of a specific ADR 
          Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Max deadline of SUG = $LogPrint is $DeadLineMax"
          $SUGDDeadlineList.Add($SUGDItem.ApplicationName, $DeadLineMax)
          Remove-Variable DeadLineMax
        }
      }
      else {
        $LogPrint = $SUGItem.LocalizedDisplayName
        Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) To be deleted = $LogPrint"
        Remove-CMSoftwareUpdateGroup -Name $SUGItem.LocalizedDisplayName -Force 
      }
    }
    
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Run Sort deadline list"
    # Sort the list by deadlines
    $SUGDDeadlineListSorted = $SUGDDeadlineList.GetEnumerator() | Sort-Object -Property Value -Descending
    # Find the SUGs of a ADR to be deleted
    foreach ($SUGDLItem in $SUGDDeadlineListSorted) {
      if ($ToBeDeleted){
        $LogPrint = $SUGDLItem.Name
        Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) To be deleted = $LogPrint"
        Remove-CMSoftwareUpdateGroup -Name $SUGDLItem.Name -Force
      }
      elseif ($SUGDLItem.Value -lt $Now) {
        # from here all smaller (older) deadlines in the list can be deleted
        $ToBeDeleted = $true
      }
    }
    # Refresh for next ADR
    $SUGDDeadlineListSorted = @{}
    $SUGDDeadlineList = @{}
    $ToBeDeleted = $false
  }
}
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) <--Finished ADR"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) <--Finished maintenance"
