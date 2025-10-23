<##############################################################################
Part of PowerShell module : GenXdev.Media.ytdlp
Original cmdlet filename  : Invoke-YTDlpSaveVideo.ps1
Original author           : René Vaessen / GenXdev
Version                   : 2.1.2025
################################################################################
Copyright (c)  René Vaessen / GenXdev

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
################################################################################>
###############################################################################
<#
.SYNOPSIS
Downloads a video from a specified URL using yt-dlp and saves metadata.

.DESCRIPTION
Downloads a video from the provided URL using yt-dlp, saves subtitles,
description, and info JSON, sanitizes filenames, and stores metadata in NTFS
alternate data streams. Handles clipboard input and provides verbose output
for key steps.

.PARAMETER Url
The video URL to download. If not provided, attempts to use clipboard.

.PARAMETER OutputFileName
The output filename or template for the downloaded video.

.EXAMPLE
Invoke-YTDlpSaveVideo -Url "https://youtube.com/watch?v=abc123" -OutputFileName "%(title)s.%(ext)s"

.EXAMPLE
Save-Video "https://youtube.com/watch?v=abc123"
#>
function Invoke-YTDlpSaveVideo {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    [Alias("savevideo")]
    param(
        ###############################################################################
        [Parameter(
            Mandatory = $true,
            Position = 0,
            HelpMessage = 'The video URL to download',
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [string]$Url,
        ###############################################################################
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Output filename or template'
        )]
        [ValidateNotNullOrEmpty()]
        [string]$OutputFileName = '%(title)s.%(ext)s'
        ###############################################################################
    )

    begin {
        # Ensure yt-dlp environment is ready
        GenXdev.Media\EnsureYtDlp

        # Detect the correct WSL distro (same logic as EnsureYtdlp.ps1)
        $defaultImage = 'kali-linux'
        $images = wsl -l -q | Microsoft.PowerShell.Core\Where-Object { $_ -and $_ -ne 'docker-desktop' }
        $compatibleDistros = @('kali-linux', 'Ubuntu', 'Ubuntu-24.04', 'Ubuntu-20.04', 'Ubuntu-22.04', 'Ubuntu-18.04', 'AlmaLinux-8', 'AlmaLinux-9', 'AlmaLinux-Kitten-10', 'AlmaLinux-10')
        $selectedDistro = $null
        foreach ($distro in $compatibleDistros) {
            if ($images -contains $distro) {
                $pythonCheck = wsl -d $distro -- which python3
                $pipCheck = wsl -d $distro -- which pip3
                if ($pythonCheck -and $pipCheck) {
                    $selectedDistro = $distro
                    break
                }
            }
        }
        if (-not $selectedDistro) {
            $selectedDistro = $defaultImage
        }
    }

    process {
        if ([string]::IsNullOrWhiteSpace($Url)) {
            $Url = Microsoft.PowerShell.Management\Get-Clipboard
            "" | Microsoft.PowerShell.Management\Set-Clipboard
        }
        if ([string]::IsNullOrWhiteSpace($Url)) {
            Microsoft.PowerShell.Utility\Write-Error 'No URL provided.'
            return
        }

        $outputTemplate = $OutputFileName
        $quotedUrl = "'${Url}'"
        $quotedOutput = '"%(title)s.%(ext)s"'
        $ytDlpCmd = "~/.local/bin/yt-dlp ${quotedUrl} -o ${quotedOutput} --no-playlist --merge-output-format mp4 --embed-subs --embed-thumbnail --write-info-json --write-annotations --write-description --write-thumbnail --write-subs"

        Microsoft.PowerShell.Utility\Write-Verbose "Running: wsl -d $selectedDistro -- bash -c $ytDlpCmd"

        # Progress tracking variables
        $progressId = Microsoft.PowerShell.Utility\Get-Random
        $errorOutput = @()

        try {
            Microsoft.PowerShell.Utility\Write-Progress -Id $progressId -Activity "Initializing download" -Status "Starting yt-dlp..."

            # Use simple WSL pipeline with ForEach-Object for real-time processing
            $null = & wsl -d $selectedDistro -- bash -c $ytDlpCmd 2>&1 | Microsoft.PowerShell.Core\ForEach-Object {
                $line = $_.ToString()

                # Progress patterns for download
                if ($line -match '\[download\]\s+(\d+\.?\d*)%\s+of\s+(\d+\.?\d*)(.*?)\s+at\s+(\d+\.?\d*)(.*?)\s+ETA\s+(\d+:\d+:\d+|\d+:\d+)') {
                    $percent = [double]$matches[1]
                    $totalSize = $matches[2] + $matches[3]
                    $speed = $matches[4] + $matches[5]
                    $eta = $matches[6]

                    $activity = "Downloading Video"
                    $status = "Progress: ${percent}% | Size: ${totalSize} | Speed: ${speed} | ETA: ${eta}"
                    Microsoft.PowerShell.Utility\Write-Progress -Id $progressId -Activity $activity -Status $status -PercentComplete $percent
                    return
                }

                # Progress patterns for subtitles
                if ($line -match '\[download\]\s+(\d+\.?\d*)%\s+of\s+(\d+\.?\d*)(.*?)\s+at.*?(\.vtt|\.srt)') {
                    $percent = [double]$matches[1]
                    $totalSize = $matches[2] + $matches[3]

                    $activity = "Downloading Subtitles"
                    $status = "Progress: ${percent}% | Size: ${totalSize}"
                    Microsoft.PowerShell.Utility\Write-Progress -Id $progressId -Activity $activity -Status $status -PercentComplete $percent
                    return
                }

                # Show only the URL extraction (starting point) and extracting video title
                if ($line -match '\[.*\] Extracting URL:') {
                    Microsoft.PowerShell.Utility\Write-Host $line -ForegroundColor Cyan
                    Microsoft.PowerShell.Utility\Write-Progress -Id $progressId -Activity "Extracting Video Information" -Status "Analyzing URL..."
                    return
                }

                # Show video title when found - look for the actual video ID and title pattern
                if ($line -match '\[.*\] (\d{13,}): (.+)' -and $matches[2] -notmatch '^Downloading') {
                    $videoTitle = $matches[2]
                    Microsoft.PowerShell.Utility\Write-Host "📹 Video: $videoTitle" -ForegroundColor Green
                    return
                }

                # Update progress for different phases (but don't show the detailed messages)
                if ($line -match 'Downloading.*format') {
                    Microsoft.PowerShell.Utility\Write-Progress -Id $progressId -Activity "Preparing Download" -Status "Setting up video download..."
                    return
                } elseif ($line -match 'Writing.*subtitles') {
                    Microsoft.PowerShell.Utility\Write-Progress -Id $progressId -Activity "Processing Subtitles" -Status "Saving subtitle files..."
                    return
                } elseif ($line -match 'Writing.*thumbnail') {
                    Microsoft.PowerShell.Utility\Write-Progress -Id $progressId -Activity "Processing Thumbnail" -Status "Saving thumbnail image..."
                    return
                } elseif ($line -match 'Writing.*description') {
                    Microsoft.PowerShell.Utility\Write-Progress -Id $progressId -Activity "Processing Metadata" -Status "Saving video description..."
                    return
                } elseif ($line -match 'EmbedSubtitle') {
                    Microsoft.PowerShell.Utility\Write-Progress -Id $progressId -Activity "Embedding Subtitles" -Status "Adding subtitles to video file..."
                    return
                } elseif ($line -match 'EmbedThumbnail') {
                    Microsoft.PowerShell.Utility\Write-Progress -Id $progressId -Activity "Embedding Thumbnail" -Status "Adding thumbnail to video file..."
                    return
                }

                # Warning patterns - show these
                if ($line -match '^WARNING:' -or $line -match '^\[.*\].*WARNING') {
                    Microsoft.PowerShell.Utility\Write-Warning $line
                    return
                }

                # Error patterns - collect these
                if ($line -match '^ERROR:' -or $line -match 'failed' -or $line -match 'error') {
                    $script:errorOutput += $line
                    Microsoft.PowerShell.Utility\Write-Host $line -ForegroundColor Red
                    return
                }

                # Skip raw progress lines (these are the ones we're replacing)
                if ($line -match '^\[download\]\s+\d+\.?\d*%') {
                    return
                }

                # Skip most technical info messages - be comprehensive
                if ($line -match '^\[download\] Destination:' -or
                    $line -match '^\[download\] 100%' -or
                    $line -match '^\[info\] Writing' -or
                    $line -match '^\[info\] Downloading.*thumbnail' -or
                    $line -match '^\[info\] \d+: Downloading subtitles:' -or
                    $line -match '^\[info\] \d+: Downloading \d+ format' -or
                    $line -match '^\[info\] Writing video metadata' -or
                    $line -match '^\[info\] Writing video description' -or
                    $line -match '^\[info\] Writing video subtitles') {
                    return
                }

                # Only pass through truly important messages
                # Skip all other [info] messages that are technical details
                if ($line -match '^\[info\]') {
                    return
                }

                # Pass through other important output that's not filtered above
                if ($line.Trim().Length -gt 0) {
                    $line
                }
            }

            # Clear the progress bar
            Microsoft.PowerShell.Utility\Write-Progress -Id $progressId -Completed

            if ($LASTEXITCODE -ne 0) {
                $errorText = if ($errorOutput.Count -gt 0) { $errorOutput -join "`n" } else { "Unknown error" }
                Microsoft.PowerShell.Utility\Write-Error "yt-dlp failed with exit code ${LASTEXITCODE}: $errorText"
                return # Return nothing on failure
            }

            Microsoft.PowerShell.Utility\Write-Host "✅ Video saved using yt-dlp: $outputTemplate"
        } catch {
            Microsoft.PowerShell.Utility\Write-Progress -Id $progressId -Completed
            Microsoft.PowerShell.Utility\Write-Error "yt-dlp execution error: $_"
            return # Return nothing on failure
        }

        # Find the created mp4 file
    $currentFolder = (Microsoft.PowerShell.Management\Get-Location).Path
    $mp4Files = Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath  $currentFolder -Filter "*.mp4" | Microsoft.PowerShell.Utility\Sort-Object LastWriteTime -Descending
        $mp4FilePath = $null
        if ($mp4Files.Count -gt 0) {
            $mp4FilePath = $mp4Files[0].FullName
        }

        # Find all .srt files and keep only those
        $baseName = $mp4FilePath ? [System.IO.Path]::GetFileNameWithoutExtension($mp4FilePath) : $null
        $srtFiles = @()
        if ($baseName) {
            $srtFiles = Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath  $currentFolder -Filter "$baseName*.srt" | Microsoft.PowerShell.Utility\Sort-Object LastWriteTime -Descending
        }

        # Sanitize filenames (remove leading/trailing unicode, replace invalid chars, trim length)
        function Format-Filename($name) {
            $sanitized = $name -replace "^[^\w\d]+", '' -replace "[^\w\d\-. ]", '_'
            $sanitized = $sanitized.Trim()
            if ($sanitized.Length -gt 128) { $sanitized = $sanitized.Substring(0,128) }
            return $sanitized
        }

        # Rename srt files to sanitized names
        $sanitizedSrtFiles = @()
        foreach ($file in $srtFiles) {
            $newName = Format-Filename $file.Name
            if ($file.Name -ne $newName) {
                try {
                    # Removed unused variable 'newPath' per PSScriptAnalyzer rule
                    Microsoft.PowerShell.Management\Rename-Item -LiteralPath $file.FullName -NewName $newName -ErrorAction Stop
                    $sanitizedSrtFiles += $newName
                } catch {
                    Microsoft.PowerShell.Utility\Write-Warning "Failed to rename $($file.Name) to ${newName}: $_"
                    $sanitizedSrtFiles += $file.Name
                }
            } else {
                $sanitizedSrtFiles += $file.Name
            }
        }

        # Find .info.json and .description files and add their contents to the NTFS stream object
        $infoJsonFile = $null
        $descriptionFile = $null
        if ($mp4FilePath) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($mp4FilePath)
            $infoJsonFile = Microsoft.PowerShell.Management\Join-Path $currentFolder ("${baseName}.info.json")
            $descriptionFile = Microsoft.PowerShell.Management\Join-Path $currentFolder ("${baseName}.description")
        }

        $videoInfoObj = @{}
        if (Microsoft.PowerShell.Management\Test-Path -LiteralPath $infoJsonFile) {
            try {
                $infoJsonContent = Microsoft.PowerShell.Management\Get-Content -LiteralPath  $infoJsonFile -Raw
                $videoInfoObj.InfoJson = $infoJsonContent | Microsoft.PowerShell.Utility\ConvertFrom-Json
            } catch {
                Microsoft.PowerShell.Utility\Write-Warning "Failed to parse info.json: $_"
                $videoInfoObj.InfoJson = $infoJsonContent
            }
        }
        if (Microsoft.PowerShell.Management\Test-Path -LiteralPath $descriptionFile) {
            try {
                $descriptionContent = Microsoft.PowerShell.Management\Get-Content -LiteralPath  $descriptionFile -Raw
                $videoInfoObj.Description = $descriptionContent
            } catch {
                Microsoft.PowerShell.Utility\Write-Warning "Failed to read description: $_"
            }
        }

        # Add srt file list to videoinfo object
        if ($sanitizedSrtFiles.Count -gt 0) {
            $videoInfoObj.SrtFileNames = $sanitizedSrtFiles
        }

        # Save videoinfo object to NTFS alternate data stream
        if ($mp4FilePath -and $videoInfoObj.Count -gt 0) {
            try {
                $jsonToSave = $videoInfoObj | Microsoft.PowerShell.Utility\ConvertTo-Json -Depth 10
                [io.file]::WriteAllText("${mp4FilePath}:videoinfo.json", $jsonToSave)
                Microsoft.PowerShell.Utility\Write-Verbose "Saved video info JSON to alternate data stream: ${mp4FilePath}:videoinfo.json"
                # Remove .info.json and .description files
                if (Microsoft.PowerShell.Management\Test-Path -LiteralPath $infoJsonFile) { Microsoft.PowerShell.Management\Remove-Item -LiteralPath $infoJsonFile -Force }
                if (Microsoft.PowerShell.Management\Test-Path -LiteralPath $descriptionFile) { Microsoft.PowerShell.Management\Remove-Item -LiteralPath $descriptionFile -Force }
            } catch {
                Microsoft.PowerShell.Utility\Write-Warning "Failed to save video info JSON to alternate data stream: $_"
            }
        } else {
            Microsoft.PowerShell.Utility\Write-Warning "Could not find both mp4 and json files to save alternate data stream."
        }

        # Return the downloaded video file on success
        if ($mp4FilePath -and (Microsoft.PowerShell.Management\Test-Path -LiteralPath $mp4FilePath)) {
            Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath $mp4FilePath
        } else {
            # Try to find the most recently created .mp4 file as fallback
            $currentFolder = (Microsoft.PowerShell.Management\Get-Location).Path
            $recentMp4 = Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath $currentFolder -Filter "*.mp4" |
                Microsoft.PowerShell.Utility\Sort-Object LastWriteTime -Descending |
                Microsoft.PowerShell.Utility\Select-Object -First 1
            if ($recentMp4) {
                $recentMp4
            }
            # If no MP4 found, return nothing (implicit)
        }
    }
}