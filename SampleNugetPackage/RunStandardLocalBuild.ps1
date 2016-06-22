#File: RunLocalBuild.ps1

#Purpose:
#  This script file runs a local build given some project specific parameters that are defined in this file.

#History:
#   New: DVD - 12-15-2015


###############
# Customization Section 
#  This section is the only place that needs to be modified for a build of a solution.
###############

#SoluitonName: Just the solution name, do not have file ext such as .sln  
#  Example to build the GeoLynxServicesAPI.sln
#      $SolutionName = "GeoLynxServicesAPI"
$SolutionName = "SampleNugetPackage"

#TFSTeamProjectName: TFS Team Project name for where the solution lives in TFS.
#  Example:
#      $TFSTeamProjectName = "GeoLynxPlatformGen5"
#
$TFSTeamProjectName = "Core"

#####################################################################################
# Change nothing below this line.
#   There is nothing below that needs to be changed for a given build of a solution.
#####################################################################################
cls
Write-Host ""
Write-Host ""
Write-Host "Starting build for solution: $SolutionName" -ForegroundColor DarkCyan
Write-Host ""

#Directory of where the script lives.
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

#Path of the standard local build script file
$LocalBuildScriptFile = "$ScriptDir\StandardLocalBuild.ps1"

Write-Host "executing script: $LocalBuildScriptFile"

#Call the build script passing in parameters.
Invoke-Expression "$LocalBuildScriptFile -SolutionName $SolutionName  -TFSTeamProjectName $TFSTeamProjectName" 

Write-Host "... Build done (RunLocalBuild.ps1)"