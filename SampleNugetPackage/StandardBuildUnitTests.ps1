#RunUnitTests.ps1
#
#Purpose:
#  This script runs unit tests and is used by both Local dev builds and the TFS builds.
#
# History:
#   12-10-2015 - New
#   1.13.2016 - Update due to breaking change in MSBuild after VS update1 broke how jobs are run.  See notes section for ways to do the same thing.
#
#
# Notes: 
#   Visual Studio 2015 Update 1 and parallel testing  https://www.visualstudio.com/en-us/news/vs2015-update1-vs.aspx#misc




#Parameters that can be passed into this script file.
param( 
    $TfsUrl, 
    $BuildUri,
	$BuildName,
    $BinDir = "build", 
	$TestOutput = "TestResults", 
    $TeamProject,
    $Platform = "Any CPU", 
    $Flavor = "Release", 
    $UnitTestFilter = "\S+[Uu]nit[Tt]est\S?\.dll$" 
    )

$ErrorActionPreference = "Stop"

#Define a function block so a job can use the functions.

  #GetVsTestConsoleExecPath
  #Return the path of the vstest.console.exe
  #todo:   Will our tests run if we don't use visual studio 2015 test exe?
  function GetVsTestConsoleExePath
  {
        $VsTestConsoleExePath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe"

		if((Test-Path $VsTestConsoleExePath) -eq $False) 
        {
			# If can't find msbuild in the VS 2015 location, fall back to VS 2013
			Write-Host "Falling back to VS 12 for vstest.console.exe"
			$VsTestConsoleExePath = "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe"
		}
		
        if((Test-Path $VsTestConsoleExePath) -eq $False) 
        {
			# One more try, fall back to VS 2012.
			Write-Host "Falling back to VS 11 for vstest.console.exe"
			$VsTestConsoleExePath = "C:\Program Files (x86)\Microsoft Visual Studio 11.0\Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe"
		}

    Write-Host "VSTest.Console.exe found at: " $VsTestConsoleExePath

    return $VsTestConsoleExePath
  }

  #WriteTestResults
  #Given the test result string format it and write it out to host.
  function WriteTestResults([string] $testResults)
  {
        #Format the string so it is readable.
        $formatedOutput = $TestResults    -replace "Passed", "`n  Passed"
        $formatedOutput = $formatedOutput -replace "Failed", "`n  Failed"
        $formatedOutput = $formatedOutput -replace "Skipped ", "`n  Skipped "
        $formatedOutput = $formatedOutput -replace "Passed:", "`n  Passed:"
        $formatedOutput = $formatedOutput -replace "Skipped:", "`n  Skipped:"
        $formatedOutput = $formatedOutput -replace "Test Run", "`n`n  Test Run"
        $formatedoutput = $FormatedOutput -replace "Test execution time","'nTest execution time"

        Write-Host ""
        Write-Host ""
        Write-Host "Test Results:`n  "  $formatedOutput 
  }

  #WriteTestDllList
  #Format and write list of unit test dll's
  function WriteTestDllList([string] $UnitTestDlls)
  {
    Write-Host ""
    $FormatedOutput = $UnitTestDlls -replace ".dll", ".dll`n"
    Write-Host "Test Dll's`n" $FormatedOutput
  }

#Run the tests given the test dlls and test arguments
function RunVSTests( $testArgs ) 
{
    Write-Host ""
    Write-Host "Starting RunVSTests()"  -foregroundcolor DarkGray -backgroundcolor DarkMagenta
      
   [System.Diagnostics.Stopwatch] $sw = New-Object System.Diagnostics.StopWatch
   $sw.Start()

   #list out test dlls and arguments
   WriteTestDllList($testArgs)

   $exePath = GetVsTestConsoleExePath

   #execute the tests
   $TestResults = & $exePath $testArgs 2>$1

   #write out test results
   WriteTestResults($TestResults)

   Write-host "RunVSTestTests() Completed in - "  $sw.Elapsed.ToString()
   Write-host "RunVSTestTests() last exit code CODE [$LastExitCode]"  -foregroundcolor black -backgroundcolor green
        
   return ($LastExitCode -eq 0)
}


#GetTestDlls
#This function returns the paths for the test dlls found in the parameter $BinFolder that match the patter $UnitTestFilter
function GetTestDllsArray([string]$BinFolder, [string]$TestDllFilter)
{
    Write-Host "GetTestDllsArray()"
	Write-Host "    BinFolder:" $BinFolder
    Write-Host "    Unit test filter: [$UnitTestFilter]"

    $TestDllfiles = @()
    foreach($file in Get-ChildItem $BinFolder -recurse -filter "*.dll")  
    { 
        if($file.name -match $TestDllFilter ) 
        { 
            $TestDllfiles += $file.FullName
        } 
    }

    return $TestDllFiles
}

#Return the test arguments including test dlls.
#  Return value will be empty if there are no dlls'
function GetTestArgumentsArray($vsTestLoggerArg )
{
	Write-Host "GetTestArgumentsArray()"

	$TestDlls = GetTestDllsArray $BuildOuputFolder $UnitTestFilter  

	Write-Host "    TestDlls: " $TestDlls

	$testArgsArray = @()
	$testArgsArray += $TestDlls

    if( $vsTestLoggerArg ) 
	{
        $testArgsArray += "/EnableCodeCoverage"
		$testArgsArray += "/UseVsixExtensions:true"
		$testArgsArray += $vsTestLoggerArg + "RunTitle=UnitTests;"
    }

	#If there are no test dlls this lets the caller of the function know.
	if( $TestDlls.length -eq 0 ) 
	{
		Write-Host "TestDlls was empty."
    	$testArgsArray = @()
	}


	Write-Host "    testArgsArray " $testArgsArray
	return $testArgsArray
}


#Run the unit tests
function RunUnitTests( $BuildOuputFolder, $vsTestLoggerArg ) 
{
    Write-Host ""
    Write-Host "RunUnitTests()"  -foregroundcolor DarkGray -backgroundcolor DarkMagenta

    $testArgsArray = GetTestArgumentsArray($vsTestLoggerArg )
   
	#If we have test args we have test dlls and thus run tests.
    if( $testArgsArray.length -ne 0 ) 
    {
		$RunUnitTestsResult = RunVSTests ($testArgsArray)
    }
    else 
    {
        Write-Host "NO TESTS DLLs FOUND" -foregroundcolor black -backgroundcolor green
		#only stop build if there where test errors not if we don't have tests. 
		$RunUnitTestsResult = $true
    }

	Write-Host "RunUnitTests(): " $RunVSTestsResult

    return $RunUnitTestsResult
}


#Return the number of cores
function GetNumCores() {
    
    $info = Get-WmiObject -Class Win32_ComputerSystem
    return $info.NumberOfLogicalProcessors
}


function PrintSystemProperties() 
{
    write-host "SYSTEM PROPERTIES:"
    Get-WmiObject -Class Win32_ComputerSystem | fl TotalPhysicalMemory,SystemType,Number*
}

function PrintProcessorProperties() 
{
    write-host "PROCESSOR PROPERTIES"
    Get-WmiObject win32_processor | fl Description, Name, DataWidth, Number*, LoadPercentage
}

function PrintAvailableMemory() 
{
   # -Namespace root/cimv2
    write-host "`r`nLOCAL MEMORY USAGE:" (Get-WmiObject -Class Win32_OperatingSystem -ComputerName . | Format-List TotalVirtualMemorySize,TotalVisibleMemorySize,FreePhysicalMemory,FreeVirtualMemory,FreeSpaceInPagingFiles | Out-String)   
}

function PrintCpuUsage() 
{
    write-host "`r`nLocal CPU USAGE:" ( Get-WmiObject win32_processor | Measure-Object -property LoadPercentage -Average | Select Average ) "`r`n"
}

function PrintProcessInfo([string]$process)
{
    Write-Host "PRINTING PROCESS INFO ON: " $process
    $set = @(Get-Process -ea silentlycontinue $process)
    Write-Host $set.count " INSTANCE(S)"
     
    foreach( $p in $set ) 
    {
        $p | out-default | fl *
    }
}

function PrintTestDiagnostics()
{
  
  Write-Host "TeamProject:" $TeamProject

  PrintSystemProperties
  PrintProcessorProperties
  PrintAvailableMemory
  PrintCpuUsage
  PrintProcessInfo -process "dev*"
  PrintProcessInfo -process "qtagent*"
  PrintProcessInfo -process "msbuild*"
}

########################################################################################
#                                   Main Script Start                                  #
########################################################################################
Write-Host ""
Write-Host ""
Write-Host "************************************"
Write-Host "Starting StandardBuildUnitTests.ps1 script"
Write-Host "************************************"

PrintTestDiagnostics

$MSTestOutput = "$(get-location)\TestResults"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if( $TestOutput ) 
{
    $MSTestOutput = $TestOutput
}

if (-not(Test-Path $MSTestOutput))
{
    new-item $MSTestOutput -type directory
}

$MSTestOutput = Resolve-Path $MSTestOutput

$MSTestArguments += "/resultsfileroot:$MSTestOutput"

$BuildOutput = "$(get-location)\build\output"

if( $BinDir ) 
{
    $BuildOutput = $BinDir
}

if( $TfsUrl -and $BuildUri -and $TeamProject -and $Platform -and $Flavor ) 
{
    $MSTestArguments += "/publish:$TfsUrl"
    $MSTestArguments += "/publishbuild:$BuildUri"
    $MSTestArguments += "/teamproject:$TeamProject"
    $MSTestArguments += "/platform:$Platform"
    $MSTestArguments += "/flavor:$Flavor"
}

$vsTestLoggerArg = ""
if( $TfsUrl -and $TeamProject -and $BuildName -and $Platform -and $Flavor ) 
{
    $vsTestLoggerArg += "/logger:TfsPublisher;TeamProject=$TeamProject;Collection=$TfsUrl;BuildName=$BuildName;Platform=$Platform;Flavor=$Flavor;"
}

Get-Host
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
write-host "ScriptDir: $ScriptDir"

[System.Collections.Queue] $jobArgsQueue = [System.Collections.Queue]::Synchronized( (New-Object System.Collections.Queue) )
[System.Collections.ArrayList] $workerJobs = [System.Collections.ArrayList]::Synchronized( (New-Object System.Collections.ArrayList) )

[System.Diagnostics.Stopwatch] $scriptSW = New-Object System.Diagnostics.StopWatch
$scriptSW.Start()

Write-Host "RunUnitTests Running tests" -foregroundcolor black -backgroundcolor red
$retval = $true
$retval = RunUnitTests "$BuildOutput" $vsTestLoggerArg

Write-Host "RunUnitTests exiting - Successful=$retval - Ran for " $scriptSW.Elapsed.ToString() -foregroundcolor black -backgroundcolor red

if($retval -eq $false) 
{
    Exit 1
}

