<#
.SYNOPSIS
Ensures yt-dlp is installed and available in the default WSL image.

.DESCRIPTION
Checks for WSL, installs it if missing, ensures the default image is present,
installs python3, pip3, pipx, and yt-dlp if needed using a single command to minimize sudo prompts,
and provides status messages. Returns $true if setup is successful.

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
        # Set default WSL image name
        $defaultImage = 'kali-linux'

        # Get list of installed WSL images
    $images = wsl -l -q | Microsoft.PowerShell.Core\Where-Object { $_ -and $_ -ne 'docker-desktop' }

        # Define compatible distros (must support python3 and pip)
        $compatibleDistros = @('kali-linux', 'Ubuntu', 'Ubuntu-24.04', 'Ubuntu-20.04', 'Ubuntu-22.04', 'Ubuntu-18.04', 'AlmaLinux-8', 'AlmaLinux-9', 'AlmaLinux-Kitten-10', 'AlmaLinux-10')

        # Try to find a compatible installed distro
        $selectedDistro = $null
        foreach ($distro in $compatibleDistros) {
            if ($images -contains $distro) {
                # Check if python3 and pip3 are installed in this distro
                $pythonCheck = wsl -d $distro -- which python3
                $pipCheck = wsl -d $distro -- which pip3
                if ($pythonCheck -and $pipCheck) {
                    $selectedDistro = $distro
                    break
                }
            }
        }

        # If no compatible distro found, use default
        if (-not $selectedDistro) {
            $selectedDistro = $defaultImage
            if (-not $PSCmdlet.ShouldProcess("Install default WSL image: $defaultImage")) {
                Microsoft.PowerShell.Utility\Write-Host "Operation cancelled by user." -ForegroundColor Yellow
                return $false
            }
        }

        # Check if WSL is installed
    $wslInstalled = Microsoft.PowerShell.Core\Get-Command wsl -ErrorAction SilentlyContinue
        if (-not $wslInstalled) {
            if ($PSCmdlet.ShouldProcess("Install WSL")) {
                Microsoft.PowerShell.Utility\Write-Host "WSL is not installed. Installing WSL..." -ForegroundColor Cyan
                wsl --install
                Microsoft.PowerShell.Utility\Write-Host "Waiting for WSL installation to complete..." -ForegroundColor Cyan
                Microsoft.PowerShell.Utility\Start-Sleep -Seconds 30
            } else {
                Microsoft.PowerShell.Utility\Write-Host "WSL installation cancelled by user." -ForegroundColor Yellow
                return $false
            }
        }

        # If selected distro is not installed, install it
        if ($images -notcontains $selectedDistro) {
            if ($PSCmdlet.ShouldProcess("Install default WSL image: $defaultImage")) {
                Microsoft.PowerShell.Utility\Write-Host "Installing default WSL image: $defaultImage" -ForegroundColor Cyan
                Microsoft.PowerShell.Utility\Write-Host "Create new user/password and enter 'exit'" -ForegroundColor Green
                wsl --install -d $defaultImage
                Microsoft.PowerShell.Utility\Write-Host "Waiting for WSL image installation to complete..." -ForegroundColor Cyan
                Microsoft.PowerShell.Utility\Start-Sleep -Seconds 30
            } else {
                Microsoft.PowerShell.Utility\Write-Host "WSL image installation cancelled by user." -ForegroundColor Yellow
                return $false
            }
        }

        # Ensure the distro is running
    Microsoft.PowerShell.Utility\Write-Host "Ensuring $selectedDistro is running..." -ForegroundColor Cyan

        wsl -d $selectedDistro -- echo "Distro is running"

        # Check if python3, pip3, pipx, and yt-dlp are installed
        $pythonCheck = wsl -d $selectedDistro -- which python3
        $pipCheck = wsl -d $selectedDistro -- which pip3
        $pipxCheck = wsl -d $selectedDistro -- which pipx
        # Explicitly set PATH and check yt-dlp
        $ytDlpCheckCmd = 'export PATH="$HOME/.local/bin:$PATH"; if command -v yt-dlp >/dev/null; then yt-dlp --version; else echo "not_found"; fi'
        $ytDlpResult = wsl -d $selectedDistro -- bash -c $ytDlpCheckCmd 2>&1

        if (-not $pythonCheck -or -not $pipCheck -or -not $pipxCheck -or $ytDlpResult -eq "not_found") {
            if ($PSCmdlet.ShouldProcess("Install python3, pip3, pipx, and yt-dlp in $selectedDistro")) {
                Microsoft.PowerShell.Utility\Write-Host "Installing required packages and yt-dlp in $selectedDistro" -ForegroundColor Cyan
                # Combine all sudo-required commands into a single bash session to minimize password prompts
                $sudoBlock = @(
                    'sudo apt-get update -y',
                    'sudo apt-get install -y python3 python3-pip pipx ffmpeg',
                    'pipx ensurepath',
                    'pipx install --force yt-dlp',
                    'echo "export PATH=\"$HOME/.local/bin:$PATH\"" >> ~/.bashrc',
                    'source ~/.bashrc'
                ) -join ' && '
                wsl -d $selectedDistro -- bash -c "$sudoBlock"
                if ($LASTEXITCODE -ne 0) {
                    Microsoft.PowerShell.Utility\Write-Warning "Failed to install required packages or yt-dlp."
                    return $false
                }

                # Re-check installations
                $pythonCheck = wsl -d $selectedDistro -- which python3
                $pipCheck = wsl -d $selectedDistro -- which pip3
                $pipxCheck = wsl -d $selectedDistro -- which pipx
                $ytDlpResult = wsl -d $selectedDistro -- bash -c $ytDlpCheckCmd 2>&1

                if ($pythonCheck -and $pipCheck -and $pipxCheck -and $ytDlpResult -ne "not_found") {
                    Microsoft.PowerShell.Utility\Write-Host "Successfully installed python3, pip3, pipx, and yt-dlp in $selectedDistro : yt-dlp version $ytDlpResult" -ForegroundColor Green
                } else {
                    Microsoft.PowerShell.Utility\Write-Warning "Installation verification failed in $selectedDistro"
                    return $false
                }
            } else {
                Microsoft.PowerShell.Utility\Write-Host "Installation cancelled by user." -ForegroundColor Yellow
                return $false
            }
        } else {
            Microsoft.PowerShell.Utility\Write-Host "yt-dlp is already installed in $selectedDistro : version $ytDlpResult" -ForegroundColor Green
        }
    }

    process {
        # Return true if setup completed successfully
    return $true
    }

    end {
    }
}
