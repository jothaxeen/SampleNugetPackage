#Standard BuildProject script.
# Do Not update this file.
#
#Purpose
#  This script is a generic script file that will run a build given the following require parameters:
#      SoluitonName: Just the solution name,  do not have file ext such as .sln  
#          Example to build the GeoLynxServicesAPI.sln
#              $SolutionName = "GeoLynxServicesAPI"
#      TFSTeamProjectName: TFS Team Project name for where the solution lives in TFS.
#          Example:
#              $TFSTeamProjectName = "GeoLynxPlatformGen5"
#

#parameters - Any pramater that is set to "" must be provided by calling script.
param (
 	[string] $Configuration = "Release",
	[string] $BuildProjectName = "StandardBuild.proj",
    [string] $SolutionName = "", 
	#[string] $Targets = "Build,Nuget_Pack",
	[string] $TFSTeamProjectName=""
)


##############################################################################################
#                                 F u n c t i o n s
##############################################################################################

#
#Present the user with a message pop up box.
#Note: there are times when this message box may be hidden behind something else.
function PopUpMessage([string] $Msg, [string] $Tile = "")
{
    Write-Host "PopUpMessage: $Msg"
    Write-Host "PopUpMessage: If you don't see a pop up window it may be behind a window." -ForegroundColor DarkCyan

    [System.Windows.Forms.MessageBox]::Show($Msg, $Title) 

    Write-Host "PopUpMessage: $Msg" 
}

#
#Delete the build direcotry so we don't have any file from previous build.
function DeleteBuildDirectory([string] $buildDirectory)
{
  #if the build directory delete all files and folders 
  if((Test-Path $buildDirectory) -eq $True) 
  {
	Write-Host "Delete Build Directory: $buildDirectory ..."  -foregroundcolor white -backgroundcolor blue

    #Remove-Item has an issue some times where it can't delete all the files.  This try catch will stop the build if there is an error.
    #also, if something has a file open we will get an error.
    Try
    {
	    Remove-Item -Recurse -Force $buildDirectory -ErrorAction Stop
    }
    Catch
    {
      $ErrorMsg = "Remove-Item Exception:" + $Error[0].ToString() + "`n`nIf this continues make sure that none of the build files are being used.  This error can also be an intermittent error and try the build again usually fixes it. Try waiting 10 seconds and try again. `n`nThis build will stop."
      PopUpMessage($ErrorMsg, "Error deleting Build Directory") 
      Exit
    }

	Write-Host "   Complete"  -foregroundcolor white -backgroundcolor blue
  }

}


#
#Create the build argument string
function CreateBuildArgumentArray
{
    $buildArgumentString = @()
    $buildArgumentString += Join-Path $ScriptDir $BuildProjectName
    $buildArgumentString += "/p:Configuration=$Configuration"
    $buildArgumentString += "/p:SkipInvalidConfigurations=true"
    $buildArgumentString += "/p:OutDir=$outDir\"
    $buildArgumentString += "/p:SolutionName=$SolutionName"
    $buildArgumentString += "/p:TFSTeamProjectName=$TFSTeamProjectName"
    $buildArgumentString += "/p:BinariesRoot='$outDir'"
    $buildArgumentString += "/p:CopyEntLibConfigTools=false"
    $buildArgumentString += "/p:VisualStudioVersion=14.0"
    $buildArgumentString += "/tv:14.0"
    $buildArgumentString += "/flp:logfile=$buildDir\build.log;verbosity=normal"
	if ($Targets -ne $null)
	{
		$buildArgumentString += "/t:$Targets"
	}

	# For testing Nuget Server push and pack
	#$buildArgumentString += '/p:NugetServerUri="http://dev-win2012r2-1.geo-comm.local/Nuget/api/v2/package"'
	#$buildArgumentString += '/p:NugetServerApiKey="00000"'
	#$buildArgumentString += '/p:NugetFolder="\NugetPackages"'
	#$buildArgumentString += '/p:NuspecFiles="GeoComm.Gen5.Auth\Nuget\GeoComm.Gen5.Auth.nuspec;"'

    return $buildArgumentString
}

#
#Validate that required parameters are passed in and exit if missing.
function ValidateInputScriptparameters ($parameterSolutionName, $parameterTFSTeamProjectName  )
{
  if ($parameterSolutionName.Length -le 0 )
  {
     $msg = $MyInvocation.MyCommand.Name + ": Required parameter missing or blank: 'SolutionName'.  `nBuild will exit.`nThis is not a script to run directly."
     PopUpMessage($msg, "Error- Build will exit.")
     Exit
  }

  if ($parameterTFSTeamProjectName.Length -le 0 )
  {
     $Msg = $MyInvocation.MyCommand.Name + ": Required parameter missing or blank: 'TFSTeamProjectName'.  `nBuild will exit.`nThis is not a script to run directly."
     PopUpMessage("Error- Build will exit.")
     Exit
  }

}

#
#This returns the path for the msbuild.exe and makes sure its there else it will exit.
function  GetMSBuildPathAndValidate
{

  #path for where msBuild exe live for VS 2015
  $msBuildExePath = "C:\Program Files (x86)\MSBuild\14.0\Bin\MSBuild.exe"

  # Make sure we have access to VS 2015 msbuild.
  if((Test-Path $msBuildExePath) -eq $False) 
  {
    PopUpMessage("Build of this project requires VS 2015.  Build will stop.", "Need Visual Studio 2015 to run this build.")

    Write-Host "Did not find vs 2015"  -foregroundcolor white -backgroundcolor blue
  
    Exit
  }

  return $msBuildExePath
}

#
#create the needed directories needed for the build.
function CreateDirectories([string] $buildDirectory, [string]$outputDirectory)
{
  #if the build directory does not exists
  #   Create BuildDirectory
  #   Create output directory
  if((Test-Path $buildDirectory) -eq $False) 
  {
    Write-Host ""
	Write-Host "Creating Build Dir..."  -foregroundcolor white -backgroundcolor blue
	new-item $buildDirectory -itemtype directory
	new-item $outputDirectory -itemtype directory
	Write-Host "Complete"  -foregroundcolor white -backgroundcolor blue
  }
}



##############################################################################################
#                                 S T A R T   S C R I P T
##############################################################################################

Write-Host "ENTERING RUN SUPER BUILD SCRIPT"  -foregroundcolor black -backgroundcolor green
Write-Host "  INCOMING PARAMETERS"  -foregroundcolor black -backgroundcolor green
Write-Host "    Targets             : $Targets"  -foregroundcolor black -backgroundcolor green
Write-Host "    Configuration       : $Configuration"  -foregroundcolor black -backgroundcolor green

#validate the input parameters and possibly exit script if there is an issue.
ValidateInputScriptparameters $SolutionName $TFSTeamProjectName

#setup directory parameters.
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$buildDir = (Join-Path $ScriptDir "build")
$outDir = (Join-Path $buildDir "output")

#Delete the build directory so build starts clean.
DeleteBuildDirectory $buildDir

CreateDirectories $buildDir $outDir  

#Get the path of the msbuild.exe and validate that it exists.  Will exit if missing.
$msbuildPath = GetMSBuildPathAndValidate

#Get the build argument string
$msbuildArgs = CreateBuildArgumentArray

$deployArgs = @()

Write-Host "MSBUILD ARGUMENTS"  -foregroundcolor black -backgroundcolor green

$argOutput = [string]::join("`r`n", $msbuildArgs + $deployArgs)
Write-Host $argOutput -foregroundcolor black -backgroundcolor green

#execute the build.
& $msbuildPath $msbuildArgs $deployArgs 


