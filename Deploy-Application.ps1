<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>

## Suppress PSScriptAnalyzer errors for not using declared variables during AppVeyor build
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "", Justification="Suppress AppVeyor errors on unused variables below")]

[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall','Repair')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch { Write-Error "Failed to set the execution policy to Bypass for this process." }

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = 'Adobe'
	[string]$appName = 'Premiere Pro'
	[string]$appVersion = '22.6.3'
	[string]$appArch = 'x64'
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.0.0'
	[string]$appScriptDate = '01/25/2023'
	[string]$appScriptAuthor = 'Ryan McKenna'
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = ''

	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.8.4'
	[string]$deployAppScriptDate = '26/01/2021'
	[hashtable]$deployAppScriptParameters = $psBoundParameters

	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

	If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
		Show-InstallationWelcome -CloseApps 'acrobat,acrocef,acrodist,acrotray,adobe audition cc,adobe cef helper,adobe desktop service,adobe qt32 server,adobearm,adobecollabsync,adobegcclient,adobeipcbroker,adobeupdateservice,afterfx,agsservice,animate,armsvc,cclibrary,ccxprocess,cephtmlengine,coresync,creative cloud,dynamiclinkmanager,illustrator,indesign,node,pdapp,photoshop,firefox,chrome,excel,groove,iexplore,infopath,lync,onedrive,onenote,onenotem,outlook,mspub,powerpnt,winword,winproj,visio' -CheckDiskSpace -PersistPrompt

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Installation tasks here>
		## This essentially replaces the functionality of Creative Cloud Packager. It even uses the same xml file as Creative Cloud Packager to perform the uninstall.
		$applicationList = 'Premiere Pro','Creative Cloud'
		ForEach($installedApplication in $applicationList) {
			$installedApplicationList = Get-InstalledApplication -Name $installedApplication
			ForEach($application in $installedApplicationList) {
				$application
				if($application.UninstallString) {
					Write-Log -Message "Uninstall string: $($application.UninstallString)" -Source 'Pre-Installation' -LogType 'CMTrace'
					Write-Log -Message "Uninstall subkey: $($application.UninstallSubkey)" -Source 'Pre-Installation' -LogType 'CMTrace'
					## First, we want to check if the program was installed with a package. If it was, then we simply run the MSI uninstaller.
					if($application.UninstallString.contains("MsiExec.exe") -and ($application.UninstallSubkey)) {
						## You might get exit code 1603 if the packaged apps were uninstalled without using the MSI uninstaller.
						## The MSI uninstaller will try to run, see that there are no apps to uninstall, and fail with exit code 1603.
						## The only way to remove the package is to reinstall the package and then uninstall it with the MSI uninstaller.
						## You might also be able to do a manual cleanup of leftover files, directories, and or reg keys.
						Write-Log -Message "Attempting to run uninstaller..." -Source 'Pre-Installation' -LogType 'CMTrace'
						$exitCode = Execute-Process -Path "MsiExec.exe" -Parameters "/x$($application.UninstallSubkey) /q" -WindowStyle "Hidden"-IgnoreExitCodes '1603' -PassThru
						If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) { $mainExitCode = $exitCode.ExitCode }
					}
					## If the application wasn't installed with a package, we'll to check to see if it uses the standard Adobe uninstaller. If it does, we're in luck.
					## Unfortunately, we can't run it as is because the standard Adobe uninstaller requires user interaction. However, it does give us everything we need to do a silent uninstall.
					## The full uninstall string provided by Get-InstalledApplication will look something like this:
					## C:\Program Files (x86)\Common Files\Adobe\Adobe Desktop Common\HDBox\Uninstaller.exe" --uninstall=1 --sapCode=ILST --productVersion=26.3.1 --productPlatform=win64 --productAdobeCode={ILST-26.3.1-64-ADBEADBEADBEADBEADBEA} --productName="Illustrator" --mode=0
					## First, we separate out the options into individual strings using split and then remove everything except the value using trim.
					ElseIf($application.UninstallString.contains("${Env:ProgramFiles(x86)}\Common Files\Adobe\Adobe Desktop Common\HDBox\Uninstaller.exe")) {
						$substringArray = $application.UninstallString -split " --"
						ForEach($item in $substringArray) {
							if($item.contains("sapCode=")) {
								$sapCode = $item.trim("sapCode=")
							}
							elseif($item.contains("productVersion=")) {
								$productVersion = $item.trim("productVersion=")
								$pointValues = $productVersion.split('.')
								$baseVersion = $pointValues[0]
							}
							elseif($item.contains("productPlatform=")) {
								$productPlatform = $item.trim("productPlatform=")
							}
						}
						## This next part is a little messy. We can't just pass the $productVersion into the uninstaller below because the uninstaller is expecting the base version of the application so it knows what to uninstall.
						## To get around that, we have to compare the installed version against a list of base versions that Adobe provides as an xml file.
						## If you look above, you'll see that we take our $productVersion and pare it down to $baseVersion. In other words, 25.4.6 becomes 25.
						## Unfortunately, we can't pass that directly, because the base version could be 25.0 or even 25.0.0. So now, we compare our 25 to the product version contained in our xml file.
						## Conceivably, you could get 13.0.25 instead of 25.0.0, so we want to make sure that 25 shows up at the beginning of the version number. We perform a wildcard comparision  using * to see if 25 matches 25.0 in the XML file.
						[xml]$xmlAdobeCCUninstallerConfig = Get-Content -Path "$dirFiles\AdobeCCUninstallerConfig.xml"
						$xmlAdobeCCUninstallerConfig.CCPUninstallXML.UninstallInfo.RIBS.Products.Product | Where-Object {$_.SapCode -eq $sapCode -and $_.Version -like "$baseVersion*"} |  ForEach-Object {
							Write-Log -Message "$($_.SapCode), $($_.Version)" -Source 'Pre-Installation' -LogType 'CMTrace'
							If ( Test-Path "${Env:ProgramFiles(x86)}\Common Files\Adobe\Adobe Desktop Common\HDBox\Setup.exe") {
								$exitCode = Execute-Process -Path "${Env:ProgramFiles(x86)}\Common Files\Adobe\Adobe Desktop Common\HDBox\Setup.exe" -Parameters "--uninstall=1 --sapCode=$($_.SapCode) --baseVersion=$($_.Version) --platform=$($_.Platform) --deleteUserPreferences=false" -WindowStyle "Hidden" -IgnoreExitCodes '33,135' -PassThru
								If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) { $mainExitCode = $exitCode.ExitCode }
							}
						}
						$xmlAdobeCCUninstallerConfig.CCPUninstallXML.UninstallInfo.HD.Products.Product | Where-Object {$_.SapCode -eq $sapCode -and $_.BaseVersion -like "$baseVersion*"} |  ForEach-Object {
							Write-Log -Message "$($_.SapCode), $($_.BaseVersion)" -Source 'Pre-Installation' -LogType 'CMTrace'
							If ( Test-Path "${Env:ProgramFiles(x86)}\Common Files\Adobe\Adobe Desktop Common\HDBox\Setup.exe") {
								$exitCode = Execute-Process -Path "${Env:ProgramFiles(x86)}\Common Files\Adobe\Adobe Desktop Common\HDBox\Setup.exe" -Parameters "--uninstall=1 --sapCode=$($_.SapCode) --baseVersion=$($_.BaseVersion) --platform=$($_.Platform) --deleteUserPreferences=false" -WindowStyle "Hidden" -IgnoreExitCodes '33,135' -PassThru
								If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) { $mainExitCode = $exitCode.ExitCode }
							}
						}
					}
					ElseIf($application.UninstallString.contains("${Env:ProgramFiles(x86)}\Adobe\Adobe Creative Cloud\Utils\Creative Cloud Uninstaller.exe")) {
						Write-Log -Message "Attempting to run uninstaller..." -Source 'Pre-Installation' -LogType 'CMTrace'
						Write-Log -Message "Note: Creative Cloud can not be uninstalled if there are Creative Cloud applications installed that require it." -Source 'Pre-Installation' -LogType 'CMTrace'
						$exitCode = Execute-Process -Path "${Env:ProgramFiles(x86)}\Adobe\Adobe Creative Cloud\Utils\Creative Cloud Uninstaller.exe" -Parameters "-u" -WindowStyle "Hidden" -PassThru
						If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) { $mainExitCode = $exitCode.ExitCode }
					}
					Else {
						Write-Log -Message "The uninstall string returned was not expected." -Source 'Pre-Installation' -LogType 'CMTrace'
					}
				}
				Else {
					Write-Log -Message "A program was detected but a valid uninstall string and or subkey could not be found." -Source 'Pre-Installation' -LogType 'CMTrace'

				}
			}
		}

		## This is the old way of doing it. Adobe is no longer continuing development and maintenance of Creative Cloud Packager and
		## recommends that you do not continue using Creative Cloud Packager to uninstall Creative Cloud apps.
		<#
		Remove-File -Path "$envCommonProgramFilesX86\Adobe\OOBE\PDApp\*" -Recurse -ContinueOnError $true
		If (-not ($envOSVersion -like "10.0*")) {
			Install-MSUpdates -Directory "$dirSupportFiles\$envOSVersionMajor.$envOSVersionMinor"
		}
				$exitCode = Execute-Process -Path "$dirSupportFiles\Uninstall\AdobeCCUninstaller.exe" -WindowStyle "Hidden" -IgnoreExitCodes '33,135' -PassThru
				If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) { $mainExitCode = $exitCode.ExitCode }
		#>

		##*===============================================
		##* INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}

		## <Perform Installation tasks here>

		$exitCode = Execute-Process -Path "$dirFiles\Build\setup.exe" -Parameters "--silent --INSTALLLANGUAGE=en_US" -WindowStyle "Hidden" -PassThru
		If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) { $mainExitCode = $exitCode.ExitCode }


		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		## <Perform Post-Installation tasks here>

		#Fix Adobe's garbage installer if it kills explorer
        $ProcessActive = Get-Process explorer -ErrorAction SilentlyContinue
        if(!$ProcessActive){
            Execute-ProcessAsUser -Path "$envSystemRoot\explorer.exe"
            Write-Log "Restarting Explorer"
        }
        Else{
            Write-Log "No restart of explorer needed"
        }

		Execute-Process -Path "$envCommonProgramFilesX86\Adobe\OOBE_Enterprise\RemoteUpdateManager\RemoteUpdateManager.exe" -WindowStyle "Hidden" -PassThru -IgnoreExitCodes '1'
	  	Remove-File -Path "$envCommonDesktop\Adobe Creative Cloud.lnk" -ContinueOnError $true

		## Display a message at the end of the install
		If (-not $useDefaultMsi) { Show-InstallationPrompt -Message "$appName $appVersion has been successfully installed." -ButtonRightText 'OK' -Icon Information -NoWait }
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'

		## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
		Show-InstallationWelcome -CloseApps 'acrobat,acrocef,acrodist,acrotray,adobe audition cc,adobe cef helper,adobe desktop service,adobe qt32 server,adobearm,adobecollabsync,adobegcclient,adobeipcbroker,adobeupdateservice,afterfx,agsservice,animate,armsvc,cclibrary,ccxprocess,cephtmlengine,coresync,creative cloud,dynamiclinkmanager,illustrator,indesign,node,pdapp,photoshop,firefox,chrome,excel,groove,iexplore,infopath,lync,onedrive,onenote,onenotem,outlook,mspub,powerpnt,winword,winproj,visio' -CloseAppsCountdown 60


		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Uninstallation tasks here>


		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'

		## Handle Zero-Config MSI Uninstallations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}

		# <Perform Uninstallation tasks here>
		$exitCode = Execute-Process -Path "MsiExec.exe" -Parameters "/x{8d9b513e-434a-403f-94aa-916a93f5baaf} /q" -WindowStyle "Hidden" -PassThru
		If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) { $mainExitCode = $exitCode.ExitCode }


		## Adobe is no longer continuing development and maintenance of Creative Cloud Packager and recommends that you do not continue using Creative Cloud Packager to uninstall Creative Cloud apps.
		<#
		$exitCode = Execute-Process -Path "$dirSupportFiles\Uninstall\AdobeCCUninstaller.exe" -WindowStyle "Hidden" -IgnoreExitCodes '33,135' -PassThru
		Start-Sleep -s 10
		If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) { $mainExitCode = $exitCode.ExitCode }
		#>

		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'

		## <Perform Post-Uninstallation tasks here>

	}
	ElseIf ($deploymentType -ieq 'Repair')
	{
		##*===============================================
		##* PRE-REPAIR
		##*===============================================
		[string]$installPhase = 'Pre-Repair'

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Repair tasks here>

		##*===============================================
		##* REPAIR
		##*===============================================
		[string]$installPhase = 'Repair'

		## Handle Zero-Config MSI Repairs
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}
		# <Perform Repair tasks here>

		##*===============================================
		##* POST-REPAIR
		##*===============================================
		[string]$installPhase = 'Post-Repair'

		## <Perform Post-Repair tasks here>


    }
	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}

# SIG # Begin signature block
# MIImVgYJKoZIhvcNAQcCoIImRzCCJkMCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAexXyFHhY9luQW
# fwzTnBFa6/LMyIdrmLSvbFk5BKmNPaCCH8EwggVvMIIEV6ADAgECAhBI/JO0YFWU
# jTanyYqJ1pQWMA0GCSqGSIb3DQEBDAUAMHsxCzAJBgNVBAYTAkdCMRswGQYDVQQI
# DBJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcMB1NhbGZvcmQxGjAYBgNVBAoM
# EUNvbW9kbyBDQSBMaW1pdGVkMSEwHwYDVQQDDBhBQUEgQ2VydGlmaWNhdGUgU2Vy
# dmljZXMwHhcNMjEwNTI1MDAwMDAwWhcNMjgxMjMxMjM1OTU5WjBWMQswCQYDVQQG
# EwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS0wKwYDVQQDEyRTZWN0aWdv
# IFB1YmxpYyBDb2RlIFNpZ25pbmcgUm9vdCBSNDYwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQCN55QSIgQkdC7/FiMCkoq2rjaFrEfUI5ErPtx94jGgUW+s
# hJHjUoq14pbe0IdjJImK/+8Skzt9u7aKvb0Ffyeba2XTpQxpsbxJOZrxbW6q5KCD
# J9qaDStQ6Utbs7hkNqR+Sj2pcaths3OzPAsM79szV+W+NDfjlxtd/R8SPYIDdub7
# P2bSlDFp+m2zNKzBenjcklDyZMeqLQSrw2rq4C+np9xu1+j/2iGrQL+57g2extme
# me/G3h+pDHazJyCh1rr9gOcB0u/rgimVcI3/uxXP/tEPNqIuTzKQdEZrRzUTdwUz
# T2MuuC3hv2WnBGsY2HH6zAjybYmZELGt2z4s5KoYsMYHAXVn3m3pY2MeNn9pib6q
# RT5uWl+PoVvLnTCGMOgDs0DGDQ84zWeoU4j6uDBl+m/H5x2xg3RpPqzEaDux5mcz
# mrYI4IAFSEDu9oJkRqj1c7AGlfJsZZ+/VVscnFcax3hGfHCqlBuCF6yH6bbJDoEc
# QNYWFyn8XJwYK+pF9e+91WdPKF4F7pBMeufG9ND8+s0+MkYTIDaKBOq3qgdGnA2T
# OglmmVhcKaO5DKYwODzQRjY1fJy67sPV+Qp2+n4FG0DKkjXp1XrRtX8ArqmQqsV/
# AZwQsRb8zG4Y3G9i/qZQp7h7uJ0VP/4gDHXIIloTlRmQAOka1cKG8eOO7F/05QID
# AQABo4IBEjCCAQ4wHwYDVR0jBBgwFoAUoBEKIz6W8Qfs4q8p74Klf9AwpLQwHQYD
# VR0OBBYEFDLrkpr/NZZILyhAQnAgNpFcF4XmMA4GA1UdDwEB/wQEAwIBhjAPBgNV
# HRMBAf8EBTADAQH/MBMGA1UdJQQMMAoGCCsGAQUFBwMDMBsGA1UdIAQUMBIwBgYE
# VR0gADAIBgZngQwBBAEwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybC5jb21v
# ZG9jYS5jb20vQUFBQ2VydGlmaWNhdGVTZXJ2aWNlcy5jcmwwNAYIKwYBBQUHAQEE
# KDAmMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5jb21vZG9jYS5jb20wDQYJKoZI
# hvcNAQEMBQADggEBABK/oe+LdJqYRLhpRrWrJAoMpIpnuDqBv0WKfVIHqI0fTiGF
# OaNrXi0ghr8QuK55O1PNtPvYRL4G2VxjZ9RAFodEhnIq1jIV9RKDwvnhXRFAZ/ZC
# J3LFI+ICOBpMIOLbAffNRk8monxmwFE2tokCVMf8WPtsAO7+mKYulaEMUykfb9gZ
# pk+e96wJ6l2CxouvgKe9gUhShDHaMuwV5KZMPWw5c9QLhTkg4IUaaOGnSDip0TYl
# d8GNGRbFiExmfS9jzpjoad+sPKhdnckcW67Y8y90z7h+9teDnRGWYpquRRPaf9xH
# +9/DUp/mBlXpnYzyOmJRvOwkDynUWICE5EV7WtgwggYaMIIEAqADAgECAhBiHW0M
# UgGeO5B5FSCJIRwKMA0GCSqGSIb3DQEBDAUAMFYxCzAJBgNVBAYTAkdCMRgwFgYD
# VQQKEw9TZWN0aWdvIExpbWl0ZWQxLTArBgNVBAMTJFNlY3RpZ28gUHVibGljIENv
# ZGUgU2lnbmluZyBSb290IFI0NjAeFw0yMTAzMjIwMDAwMDBaFw0zNjAzMjEyMzU5
# NTlaMFQxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxKzAp
# BgNVBAMTIlNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBDQSBSMzYwggGiMA0G
# CSqGSIb3DQEBAQUAA4IBjwAwggGKAoIBgQCbK51T+jU/jmAGQ2rAz/V/9shTUxjI
# ztNsfvxYB5UXeWUzCxEeAEZGbEN4QMgCsJLZUKhWThj/yPqy0iSZhXkZ6Pg2A2NV
# DgFigOMYzB2OKhdqfWGVoYW3haT29PSTahYkwmMv0b/83nbeECbiMXhSOtbam+/3
# 6F09fy1tsB8je/RV0mIk8XL/tfCK6cPuYHE215wzrK0h1SWHTxPbPuYkRdkP05Zw
# mRmTnAO5/arnY83jeNzhP06ShdnRqtZlV59+8yv+KIhE5ILMqgOZYAENHNX9SJDm
# +qxp4VqpB3MV/h53yl41aHU5pledi9lCBbH9JeIkNFICiVHNkRmq4TpxtwfvjsUe
# dyz8rNyfQJy/aOs5b4s+ac7IH60B+Ja7TVM+EKv1WuTGwcLmoU3FpOFMbmPj8pz4
# 4MPZ1f9+YEQIQty/NQd/2yGgW+ufflcZ/ZE9o1M7a5Jnqf2i2/uMSWymR8r2oQBM
# dlyh2n5HirY4jKnFH/9gRvd+QOfdRrJZb1sCAwEAAaOCAWQwggFgMB8GA1UdIwQY
# MBaAFDLrkpr/NZZILyhAQnAgNpFcF4XmMB0GA1UdDgQWBBQPKssghyi47G9IritU
# pimqF6TNDDAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADATBgNV
# HSUEDDAKBggrBgEFBQcDAzAbBgNVHSAEFDASMAYGBFUdIAAwCAYGZ4EMAQQBMEsG
# A1UdHwREMEIwQKA+oDyGOmh0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1
# YmxpY0NvZGVTaWduaW5nUm9vdFI0Ni5jcmwwewYIKwYBBQUHAQEEbzBtMEYGCCsG
# AQUFBzAChjpodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2Rl
# U2lnbmluZ1Jvb3RSNDYucDdjMCMGCCsGAQUFBzABhhdodHRwOi8vb2NzcC5zZWN0
# aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOCAgEABv+C4XdjNm57oRUgmxP/BP6YdURh
# w1aVcdGRP4Wh60BAscjW4HL9hcpkOTz5jUug2oeunbYAowbFC2AKK+cMcXIBD0Zd
# OaWTsyNyBBsMLHqafvIhrCymlaS98+QpoBCyKppP0OcxYEdU0hpsaqBBIZOtBajj
# cw5+w/KeFvPYfLF/ldYpmlG+vd0xqlqd099iChnyIMvY5HexjO2AmtsbpVn0OhNc
# WbWDRF/3sBp6fWXhz7DcML4iTAWS+MVXeNLj1lJziVKEoroGs9Mlizg0bUMbOalO
# hOfCipnx8CaLZeVme5yELg09Jlo8BMe80jO37PU8ejfkP9/uPak7VLwELKxAMcJs
# zkyeiaerlphwoKx1uHRzNyE6bxuSKcutisqmKL5OTunAvtONEoteSiabkPVSZ2z7
# 6mKnzAfZxCl/3dq3dUNw4rg3sTCggkHSRqTqlLMS7gjrhTqBmzu1L90Y1KWN/Y5J
# KdGvspbOrTfOXyXvmPL6E52z1NZJ6ctuMFBQZH3pwWvqURR8AgQdULUvrxjUYbHH
# j95Ejza63zdrEcxWLDX6xWls/GDnVNueKjWUH3fTv1Y8Wdho698YADR7TNx8X8z2
# Bev6SivBBOHY+uqiirZtg0y9ShQoPzmCcn63Syatatvx157YK9hlcPmVoa1oDE5/
# L9Uo2bC5a4CH2RwwggZCMIIEqqADAgECAhEApU3fcPvc8UxUgrjysXLKMTANBgkq
# hkiG9w0BAQwFADBUMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1p
# dGVkMSswKQYDVQQDEyJTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2
# MB4XDTIxMDYwOTAwMDAwMFoXDTI0MDYwODIzNTk1OVowgZUxCzAJBgNVBAYTAlVT
# MREwDwYDVQQIDAhDb2xvcmFkbzEPMA0GA1UEBwwGRGVudmVyMTAwLgYDVQQKDCdN
# ZXRyb3BvbGl0YW4gU3RhdGUgVW5pdmVyc2l0eSBvZiBEZW52ZXIxMDAuBgNVBAMM
# J01ldHJvcG9saXRhbiBTdGF0ZSBVbml2ZXJzaXR5IG9mIERlbnZlcjCCAaIwDQYJ
# KoZIhvcNAQEBBQADggGPADCCAYoCggGBAKboC13rIRz9blQI2n+HkGKRao8qAg0x
# ItxGNohGKXOT1Ua7hDWG5+l2MBpddbQQfMSOyFT+AyisStRfFRb1TU1aSI8QxHJ1
# vkOq64AZKXIKuNxTEQv71RKyTgnjzduII4QqBhsIsrX4vN5PaFq/yKjJqKSsYQjF
# ej4Kx2fORXMFRHnqaAGW7qAwJvKcTUCzVn/1hq9dh6b3TxOd3t1x2L0Paz/4aF+J
# AhkNOF9Gc2B8heToRllTQOOSUdPz3wkW3y7u6zcJMEgxenniTP7fk348hXlrPBjy
# Z7qizCJ3wWH+QRqBqSheKZN/Olw6aYdqLAmbl9LZ3Z0/rvQMk/ADTHsY5jAXwARj
# xAlU+gnxj/6kysS6JDFP+0H7CD3fRlSBOWscPbg314zeGMx8eOLN81WWKu/79S3W
# HWAf84uxNnp2DcV/8aNsjXoaxfdQWXJp6s3V1wf5Jywv7nxcZgtS5+MJzHTv+Yc3
# hPUP7XjLpaAinHf8+rae6yP7OV6r3JZ39QIDAQABo4IByzCCAccwHwYDVR0jBBgw
# FoAUDyrLIIcouOxvSK4rVKYpqhekzQwwHQYDVR0OBBYEFMtdqsyLtKCxfncLB6Dk
# r4Az8FclMA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAAMBMGA1UdJQQMMAoG
# CCsGAQUFBwMDMBEGCWCGSAGG+EIBAQQEAwIEEDBKBgNVHSAEQzBBMDUGDCsGAQQB
# sjEBAgEDAjAlMCMGCCsGAQUFBwIBFhdodHRwczovL3NlY3RpZ28uY29tL0NQUzAI
# BgZngQwBBAEwSQYDVR0fBEIwQDA+oDygOoY4aHR0cDovL2NybC5zZWN0aWdvLmNv
# bS9TZWN0aWdvUHVibGljQ29kZVNpZ25pbmdDQVIzNi5jcmwweQYIKwYBBQUHAQEE
# bTBrMEQGCCsGAQUFBzAChjhodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29Q
# dWJsaWNDb2RlU2lnbmluZ0NBUjM2LmNydDAjBggrBgEFBQcwAYYXaHR0cDovL29j
# c3Auc2VjdGlnby5jb20wLQYDVR0RBCYwJIEiaXRzc3lzdGVtZW5naW5lZXJpbmdA
# bXN1ZGVudmVyLmVkdTANBgkqhkiG9w0BAQwFAAOCAYEAf8UAUe7L6IftWT8u5nDy
# eSlAgGxBzj4Dd3xgjRwkshSH7H5TvyTadkZlBBooTL390IG1X1uvLHmOC23qGI0Y
# ytYLCfNcKpq1Jjo8V0Jc9e1RwHGH/z653cJ4TsCYYdGTgtwz1J1OZHHVeMwr0p6y
# 3g7t0ERRuBClq1vnixURJyWRwg7mlSjBriRpv2AKY8xwSB3JMcDF9+YsRYCShih+
# hLcPp4YygkaHjlVhc5K/iKsoS1j7CT4qbjVl077CmVysO8KMDSTATMfOaYFngaxF
# vPfOcqNxCu8n1IMIFnMndoiWe/St3tDdwgSdQQqBxZ24KZZGDqa9j+jlvcO7AviT
# 258+icvZibXngUBM1aTePvMnW91uTJlwyl58K1W2CDnXVps8TZUMXQq8uD9Yn4VA
# 1MDNkfN5meHBUmmiI8ZMHBr2trzM94U/EpTCVK+HuSlOB0oTVC09tMqrcoK3UJXN
# dNc+j+IKHek+dzUcwi4VgmJG+dgrgSXPVPc2s0+AvTfzMIIG7DCCBNSgAwIBAgIQ
# MA9vrN1mmHR8qUY2p3gtuTANBgkqhkiG9w0BAQwFADCBiDELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYD
# VQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBS
# U0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTkwNTAyMDAwMDAwWhcNMzgw
# MTE4MjM1OTU5WjB9MQswCQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5j
# aGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0
# ZWQxJTAjBgNVBAMTHFNlY3RpZ28gUlNBIFRpbWUgU3RhbXBpbmcgQ0EwggIiMA0G
# CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDIGwGv2Sx+iJl9AZg/IJC9nIAhVJO5
# z6A+U++zWsB21hoEpc5Hg7XrxMxJNMvzRWW5+adkFiYJ+9UyUnkuyWPCE5u2hj8B
# BZJmbyGr1XEQeYf0RirNxFrJ29ddSU1yVg/cyeNTmDoqHvzOWEnTv/M5u7mkI0Ks
# 0BXDf56iXNc48RaycNOjxN+zxXKsLgp3/A2UUrf8H5VzJD0BKLwPDU+zkQGObp0n
# dVXRFzs0IXuXAZSvf4DP0REKV4TJf1bgvUacgr6Unb+0ILBgfrhN9Q0/29DqhYyK
# VnHRLZRMyIw80xSinL0m/9NTIMdgaZtYClT0Bef9Maz5yIUXx7gpGaQpL0bj3duR
# X58/Nj4OMGcrRrc1r5a+2kxgzKi7nw0U1BjEMJh0giHPYla1IXMSHv2qyghYh3ek
# FesZVf/QOVQtJu5FGjpvzdeE8NfwKMVPZIMC1Pvi3vG8Aij0bdonigbSlofe6GsO
# 8Ft96XZpkyAcSpcsdxkrk5WYnJee647BeFbGRCXfBhKaBi2fA179g6JTZ8qx+o2h
# ZMmIklnLqEbAyfKm/31X2xJ2+opBJNQb/HKlFKLUrUMcpEmLQTkUAx4p+hulIq6l
# w02C0I3aa7fb9xhAV3PwcaP7Sn1FNsH3jYL6uckNU4B9+rY5WDLvbxhQiddPnTO9
# GrWdod6VQXqngwIDAQABo4IBWjCCAVYwHwYDVR0jBBgwFoAUU3m/WqorSs9UgOHY
# m8Cd8rIDZsswHQYDVR0OBBYEFBqh+GEZIA/DQXdFKI7RNV8GEgRVMA4GA1UdDwEB
# /wQEAwIBhjASBgNVHRMBAf8ECDAGAQH/AgEAMBMGA1UdJQQMMAoGCCsGAQUFBwMI
# MBEGA1UdIAQKMAgwBgYEVR0gADBQBgNVHR8ESTBHMEWgQ6BBhj9odHRwOi8vY3Js
# LnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNBQ2VydGlmaWNhdGlvbkF1dGhvcml0
# eS5jcmwwdgYIKwYBBQUHAQEEajBoMD8GCCsGAQUFBzAChjNodHRwOi8vY3J0LnVz
# ZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNBQWRkVHJ1c3RDQS5jcnQwJQYIKwYBBQUH
# MAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20wDQYJKoZIhvcNAQEMBQADggIB
# AG1UgaUzXRbhtVOBkXXfA3oyCy0lhBGysNsqfSoF9bw7J/RaoLlJWZApbGHLtVDb
# 4n35nwDvQMOt0+LkVvlYQc/xQuUQff+wdB+PxlwJ+TNe6qAcJlhc87QRD9XVw+K8
# 1Vh4v0h24URnbY+wQxAPjeT5OGK/EwHFhaNMxcyyUzCVpNb0llYIuM1cfwGWvnJS
# ajtCN3wWeDmTk5SbsdyybUFtZ83Jb5A9f0VywRsj1sJVhGbks8VmBvbz1kteraMr
# Qoohkv6ob1olcGKBc2NeoLvY3NdK0z2vgwY4Eh0khy3k/ALWPncEvAQ2ted3y5wu
# jSMYuaPCRx3wXdahc1cFaJqnyTdlHb7qvNhCg0MFpYumCf/RoZSmTqo9CfUFbLfS
# ZFrYKiLCS53xOV5M3kg9mzSWmglfjv33sVKRzj+J9hyhtal1H3G/W0NdZT1QgW6r
# 8NDT/LKzH7aZlib0PHmLXGTMze4nmuWgwAxyh8FuTVrTHurwROYybxzrF06Uw3hl
# IDsPQaof6aFBnf6xuKBlKjTg3qj5PObBMLvAoGMs/FwWAKjQxH/qEZ0eBsambTJd
# tDgJK0kHqv3sMNrxpy/Pt/360KOE2See+wFmd7lWEOEgbsausfm2usg1XTN2jvF8
# IAwqd661ogKGuinutFoAsYyr4/kKyVRd1LlqdJ69SK6YMIIG9jCCBN6gAwIBAgIR
# AJA5f5rSSjoT8r2RXwg4qUMwDQYJKoZIhvcNAQEMBQAwfTELMAkGA1UEBhMCR0Ix
# GzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEY
# MBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSUwIwYDVQQDExxTZWN0aWdvIFJTQSBU
# aW1lIFN0YW1waW5nIENBMB4XDTIyMDUxMTAwMDAwMFoXDTMzMDgxMDIzNTk1OVow
# ajELMAkGA1UEBhMCR0IxEzARBgNVBAgTCk1hbmNoZXN0ZXIxGDAWBgNVBAoTD1Nl
# Y3RpZ28gTGltaXRlZDEsMCoGA1UEAwwjU2VjdGlnbyBSU0EgVGltZSBTdGFtcGlu
# ZyBTaWduZXIgIzMwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCQsnE/
# eeHUuYoXzMOXwpCUcu1aOm8BQ39zWiifJHygNUAG+pSvCqGDthPkSxUGXmqKIDRx
# e7slrT9bCqQfL2x9LmFR0IxZNz6mXfEeXYC22B9g480Saogfxv4Yy5NDVnrHzgPW
# AGQoViKxSxnS8JbJRB85XZywlu1aSY1+cuRDa3/JoD9sSq3VAE+9CriDxb2YLAd2
# AXBF3sPwQmnq/ybMA0QfFijhanS2nEX6tjrOlNEfvYxlqv38wzzoDZw4ZtX8fR6b
# WYyRWkJXVVAWDUt0cu6gKjH8JgI0+WQbWf3jOtTouEEpdAE/DeATdysRPPs9zdDn
# 4ZdbVfcqA23VzWLazpwe/OpwfeZ9S2jOWilh06BcJbOlJ2ijWP31LWvKX2THaygM
# 2qx4Qd6S7w/F7KvfLW8aVFFsM7ONWWDn3+gXIqN5QWLP/Hvzktqu4DxPD1rMbt8f
# vCKvtzgQmjSnC//+HV6k8+4WOCs/rHaUQZ1kHfqA/QDh/vg61MNeu2lNcpnl8TIt
# UfphrU3qJo5t/KlImD7yRg1psbdu9AXbQQXGGMBQ5Pit/qxjYUeRvEa1RlNsxfTh
# hieThDlsdeAdDHpZiy7L9GQsQkf0VFiFN+XHaafSJYuWv8at4L2xN/cf30J7qusc
# 6es9Wt340pDVSZo6HYMaV38cAcLOHH3M+5YVxQIDAQABo4IBgjCCAX4wHwYDVR0j
# BBgwFoAUGqH4YRkgD8NBd0UojtE1XwYSBFUwHQYDVR0OBBYEFCUuaDxrmiskFKkf
# ot8mOs8UpvHgMA4GA1UdDwEB/wQEAwIGwDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB
# /wQMMAoGCCsGAQUFBwMIMEoGA1UdIARDMEEwNQYMKwYBBAGyMQECAQMIMCUwIwYI
# KwYBBQUHAgEWF2h0dHBzOi8vc2VjdGlnby5jb20vQ1BTMAgGBmeBDAEEAjBEBgNV
# HR8EPTA7MDmgN6A1hjNodHRwOi8vY3JsLnNlY3RpZ28uY29tL1NlY3RpZ29SU0FU
# aW1lU3RhbXBpbmdDQS5jcmwwdAYIKwYBBQUHAQEEaDBmMD8GCCsGAQUFBzAChjNo
# dHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29SU0FUaW1lU3RhbXBpbmdDQS5j
# cnQwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28uY29tMA0GCSqGSIb3
# DQEBDAUAA4ICAQBz2u1ocsvCuUChMbu0A6MtFHsk57RbFX2o6f2t0ZINfD02oGnZ
# 85ow2qxp1nRXJD9+DzzZ9cN5JWwm6I1ok87xd4k5f6gEBdo0wxTqnwhUq//EfpZs
# K9OU67Rs4EVNLLL3OztatcH714l1bZhycvb3Byjz07LQ6xm+FSx4781FoADk+AR2
# u1fFkL53VJB0ngtPTcSqE4+XrwE1K8ubEXjp8vmJBDxO44ISYuu0RAx1QcIPNLiI
# ncgi8RNq2xgvbnitxAW06IQIkwf5fYP+aJg05Hflsc6MlGzbA20oBUd+my7wZPvb
# pAMxEHwa+zwZgNELcLlVX0e+OWTOt9ojVDLjRrIy2NIphskVXYCVrwL7tNEunTh8
# NeAPHO0bR0icImpVgtnyughlA+XxKfNIigkBTKZ58qK2GpmU65co4b59G6F87VaA
# pvQiM5DkhFP8KvrAp5eo6rWNes7k4EuhM6sLdqDVaRa3jma/X/ofxKh/p6FIFJEN
# gvy9TZntyeZsNv53Q5m4aS18YS/to7BJ/lu+aSSR/5P8V2mSS9kFP22GctOi0MBk
# 0jpCwRoD+9DtmiG4P6+mslFU1UzFyh8SjVfGOe1c/+yfJnatZGZn6Kow4NKtt32x
# akEnbgOKo3TgigmCbr/j9re8ngspGGiBoZw/bhZZSxQJCZrmrr9gFd2G9TGCBesw
# ggXnAgEBMGkwVDELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRl
# ZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMgQ29kZSBTaWduaW5nIENBIFIzNgIR
# AKVN33D73PFMVIK48rFyyjEwDQYJYIZIAWUDBAIBBQCggYQwGAYKKwYBBAGCNwIB
# DDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEE
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg2Ty/xtPwRQOG
# I5guFH3KV20C0b6oQx9z/pnxmUnYm/QwDQYJKoZIhvcNAQEBBQAEggGAOIqWid7Q
# F8j3GJ4d4YkTzMGLJiv0nlznuNT89R9gDiLPTYy30RQ00bUZm1TNolDEcex5YXmC
# zrWGURNe92Y4YMPQbGp1CnKhqHA8FjCIxGRzN+PNlDMAeveqh93Av2HE+18jOxeH
# Zwbmyn9jCjAlw463yHQ108A1wAo4MaQ5AY2osXfgVyz8WOuXAMfN4VO4wU6YW8gS
# 34qNzh/VKJ50YGFXrsYttyX6esp7EE7J/gFQkZd0Y8fCZDWB53ii23GCam3p2AmU
# xxOldmYuCEC1sED1zqyNDTW4i1FSaayMRqkSReAk5hbMdGhl5eRIkhIUIZlc/ONA
# HQF+aVX7ZYnfN2ay6fiESLh2JLNQfs8oKZLQIUaMU4h5nD0lXDjAyDiRnVmNGfiO
# aWTj0jAhUUo3vkGw1TFp4OQeqK7ld5/+SkLKQ2mHOwWkOU6gVwGhjNg+BAfIiwEp
# 9gM7uoiFYuc20go090GdzU43r9Y2Fu0Xrg1MiQ8LP9QO+FDtIugdufBgoYIDTDCC
# A0gGCSqGSIb3DQEJBjGCAzkwggM1AgEBMIGSMH0xCzAJBgNVBAYTAkdCMRswGQYD
# VQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGDAWBgNV
# BAoTD1NlY3RpZ28gTGltaXRlZDElMCMGA1UEAxMcU2VjdGlnbyBSU0EgVGltZSBT
# dGFtcGluZyBDQQIRAJA5f5rSSjoT8r2RXwg4qUMwDQYJYIZIAWUDBAICBQCgeTAY
# BgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yMzAxMjUx
# OTU2MjhaMD8GCSqGSIb3DQEJBDEyBDBiPaWjBDv41ZZjIZgpBqDSIJ6jVdqmC+1p
# kCmIjKaAtJe4eomYNJxLJavEcbXtZiEwDQYJKoZIhvcNAQEBBQAEggIAL7iOZOpq
# poMWWmWj+DjafjGwb8YT9lEUIZ6ML78z7LLKh4lVHdNgEve1nGS1jpgcQJ2B98cV
# nTc44EU38UIxPw3cBz+Ok32joBtDY4jkFb1oBkDjyrOm4AozQIKX4IeW1UCjFepP
# G9Nj7X68BBQqEDry0EAO1iSyla+5YzlWMqz8dYZHxy+JQbT5GSO2mnF3dS/oCLYa
# +LVP/4W7EMI95qsl5rSyyz63hqv0wiINMwGbBzzhhvjXblmhsouVGYXr36zfOTwr
# GOpoW9WTGysHcuGux23Zbh/blf5zB1aDX+DCwAGSB8XQ/S/QS9g2AMJrZAQVhkkm
# L2CatQ74IsmFsitCd9c9UH9Q5l05PnYgWy0AmARjTH8gf5sDeIKbdWC3i4nKGxQn
# uuhrz7JqB3gOQcgXyjpqdLuzAH/E4eucaPiO4UxYNxvmMrIh5hLjEzuuQfU5GREO
# 3Rq1vK19As4ePC++7DPx187Cm+m/i4wgItfOPvY1E5nLOhpkiqD8rdcEpQNG/q8G
# Kg9xXsZCGl6FA3E+QQkHLTIn2L+XpLqPShoweb1TU7TCVEw/Q72o7R9ezjyB6r8e
# qqXpYi1QTwQcYdRPdNujL5IDfbQp3YAfzLxE5fd/E9cykjPljRKw2NndDnqzg/0S
# JDuLlpHADSnp499UrP/EJEma+FNCn25JLBM=
# SIG # End signature block
