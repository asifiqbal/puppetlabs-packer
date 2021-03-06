param (
  [string]$LoginUser = "Administrator",
  [string]$LoginPassword = "PackerAdmin"
)
$ErrorActionPreference = 'Stop'

. A:\windows-env.ps1
$PackageDir = 'A:\'

# Remove AutoLogin for Packer - will be re-instated at end if required.
$WinlogonPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
Remove-ItemProperty -Path $WinlogonPath -Name AutoAdminLogon -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $WinlogonPath -Name DefaultUserName -ErrorAction SilentlyContinue

$packageFile = Get-ChildItem -Path $PackageDir | ? { $_.Name -match '.package.ps1$'} | Select-Object -First 1
if ($packageFile -eq $null) {
  Write-Warning "No boxstarter packages found in $PackageDir"
  return
}

if ($WindowsVersion -like $WindowsServer2008 ) {
  # Compatibility issues with latest updates for boxstarter/chocolatey, so pin to earlier versions.
  $env:chocolateyVersion = "0.10.3"
  Write-Host "Pinning to chocolatey Version $env:chocolateyVersion and Boxstarter Version $env:boxstarterVersion"
  iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

  # Install each of the boxstarter modules with dependencies disabled to ensure Version 2.8.29 is used across the board.
  # Also resort to pinning the packages to see if this stops boxstarter gratuitously upgrading them
  # This is probably way too verbose, the but the order and combination below was necessary to ensure an error free
  # install and ability to run box-starter on the older windows platforms.

  $BoxstarterPackages = @(
    'boxstarter',
    'boxstarter.common',
    'boxstarter.winconfig',
    'boxstarter.bootstrapper',
    'boxstarter.chocolatey',
    'boxstarter.hyperv'
  )
  $BoxstarterPackages | % {
    choco install $_ -y --force --version "2.8.29" --argsglobal=true --paramsglobal=true --ignoredependencies=true
    choco pin add --name="$_"
  }
}
else {
  iex ((new-object net.webclient).DownloadString('https://raw.githubusercontent.com/mwrock/boxstarter/master/BuildScripts/bootstrapper.ps1'))
  Get-Boxstarter -Force
}

# Cleanup after boxstarter install
Remove-Item -Path "$($Env:USERPROFILE)\Desktop\Boxstarter Shell.lnk" -Confirm:$false -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item -Path "$($Env:APPDATA)\Microsoft\Windows\Start Menu\Programs\Boxstarter" -Recurse -Confirm:$false -Force -ErrorAction SilentlyContinue | Out-Null

# Use Admin Plaintext password for this phase of configuration
$secpasswd = ConvertTo-SecureString "$LoginPassword" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("$LoginUser", $secpasswd)

Write-Host "Importing Modules"
Import-Module $env:appdata\boxstarter\boxstarter.chocolatey\boxstarter.chocolatey.psd1

Write-Host "Executing Boxstarter Package"
Install-BoxstarterPackage -PackageName ($packageFile.Fullname) -Credential $cred
