$DOCKER_VERSION="19.03.0"

# disable security :)
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -name Shell -Value 'PowerShell.exe -noExit'
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
Uninstall-WindowsFeature Windows-Defender

# install Docker
Install-WindowsFeature -Name Containers
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
Install-Package -Name docker -ProviderName DockerMsftProvider -Force -RequiredVersion $DOCKER_VERSION

Restart-Computer -Force