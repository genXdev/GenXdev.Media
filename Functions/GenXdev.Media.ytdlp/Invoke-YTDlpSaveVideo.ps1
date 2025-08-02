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
    [OutputType([System.Boolean])]
    [Alias("Save-Video", "savevideo")]
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

        Microsoft.PowerShell.Utility\Write-Verbose "Running: wsl bash -c $ytDlpCmd"
        try {
            $result = & wsl bash -c $ytDlpCmd 2>&1 | Microsoft.PowerShell.Utility\Write-Host
            if ($LASTEXITCODE -ne 0) {
                Microsoft.PowerShell.Utility\Write-Error "yt-dlp failed: $result"
                return $false
            }
            Microsoft.PowerShell.Utility\Write-Host "✅ Video saved using yt-dlp: $outputTemplate"
        } catch {
            Microsoft.PowerShell.Utility\Write-Error "yt-dlp execution error: $_"
            return $false
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
        return $true
    }
}