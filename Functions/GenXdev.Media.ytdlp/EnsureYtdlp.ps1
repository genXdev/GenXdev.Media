###############################################################################
<#
.SYNOPSIS
Ensures yt-dlp is installed and available in the default WSL image.

.DESCRIPTION
Checks for WSL, installs it if missing, ensures the default image is present,
installs python3 and yt-dlp if needed, and provides status messages. Returns
$true if setup is successful.

.EXAMPLE
EnsureYtDlp
#>
function EnsureYtDlp {

    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'High'
    )]
    [OutputType([System.Boolean])]
    param ()

    begin {

        # set default WSL image name
        $defaultImage = 'kali-linux'

        # get list of installed WSL images
        $images = wsl -l -q | Microsoft.PowerShell.Core\Where-Object { $_ -and $_ -ne 'docker-desktop' }

        # define compatible distros (must support python3 and pip)
        $compatibleDistros = @('kali-linux', 'Ubuntu', 'Ubuntu-20.04', 'Ubuntu-22.04', 'Ubuntu-18.04')

        # try to find a compatible installed distro
        $selectedDistro = $null
        foreach ($distro in $compatibleDistros) {
            if ($images -contains $distro) {
                # check if python3 and pip are installed in this distro
                $pythonCheck = wsl -d $distro which python3
                $pipCheck = wsl -d $distro which pip3
                if ($pythonCheck -and $pipCheck) {
                    $selectedDistro = $distro
                    break
                }
            }
        }

        # if no compatible distro found, use default
        if (-not $selectedDistro) {

            $selectedDistro = $defaultImage
            if (-not $PSCmdlet.ShouldProcess(
                "Install default WSL image: $defaultImage"
            )) {
                return
            }
        }

        # build arguments for yt-dlp version check
        $ytDlpCheckArgs = @(
            '-d',
            $selectedDistro,
            'python3',
            '-m',
            'yt_dlp',
            '--version'
        )

        # build arguments for yt-dlp installation
        $ytDlpInstallArgs = @(
            '-d',
            $selectedDistro,
            'python3',
            '-m',
            'pip',
            'install',
            '-U',
            'yt-dlp'
        )

        # check if WSL is installed
        $wslInstalled = Microsoft.PowerShell.Core\Get-Command wsl -ErrorAction SilentlyContinue
        if (-not $wslInstalled) {
            # output message about WSL installation
                Microsoft.PowerShell.Utility\Write-Host 'WSL is not installed. Installing WSL...' -ForegroundColor Cyan
            wsl --install --accept-eula
            # wait for WSL install to complete
                Microsoft.PowerShell.Utility\Start-Sleep -Seconds 10
        }

        # if selected distro is not installed, install default
        if ($images -notcontains $selectedDistro) {
            # only install default image if ShouldProcess returns true
            if ($PSCmdlet.ShouldProcess(
                "Install default WSL image: $defaultImage"
            )) {
                    Microsoft.PowerShell.Utility\Write-Host (
                        "Installing default WSL image: $defaultImage"
                    ) -ForegroundColor Cyan
                wsl --install -d $defaultImage --accept-eula
            }
        }

        # check if python3 is installed in selected distro
        $pythonCheck = wsl -d $selectedDistro which python3
        if (-not $pythonCheck) {
            # output message about python3 installation
                Microsoft.PowerShell.Utility\Write-Host (
                    "Installing python3 in $selectedDistro"
                ) -ForegroundColor Cyan
            wsl -d $selectedDistro sudo apt-get update -y
            wsl -d $selectedDistro sudo apt-get install -y python3 python3-pip
        }

        # check if yt-dlp is installed in selected distro
        $ytDlpVersion = & wsl @ytDlpCheckArgs 2>$null
        if (-not $ytDlpVersion) {
            # output message about yt-dlp installation
                Microsoft.PowerShell.Utility\Write-Host (
                    "Installing yt-dlp in $selectedDistro"
                ) -ForegroundColor Cyan
                Microsoft.PowerShell.Management\Start-Process wsl -ArgumentList $ytDlpInstallArgs -NoNewWindow -Wait
        } else {
            # output message if yt-dlp is already installed
                Microsoft.PowerShell.Utility\Write-Host (
                    "yt-dlp is already installed in ${selectedDistro}: $ytDlpVersion"
                ) -ForegroundColor Green
        }
    }

    process {

        # return true if setup completed
        return ($null -ne $selectedDistro);
    }

    end {

    }
}
###############################################################################