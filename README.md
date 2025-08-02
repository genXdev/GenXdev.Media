<hr/>

<img src="powershell.jpg" alt="GenXdev" width="50%"/>

<hr/>

### NAME
    GenXdev.Media
### SYNOPSIS
    A Windows PowerShell module that helps with converting media files like pictures and video files
[![GenXdev.Media](https://img.shields.io/powershellgallery/v/GenXdev.Media.svg?style=flat-square&label=GenXdev.Media)](https://www.powershellgallery.com/packages/GenXdev.Media/) [![License](https://img.shields.io/github/license/genXdev/GenXdev.Media?style=flat-square)](./LICENSE)

## MIT License

```text
MIT License

Copyright (c) 2025 GenXdev

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
````

### FEATURES

### DEPENDENCIES
[![WinOS - Windows-10 or later](https://img.shields.io/badge/WinOS-Windows--10--10.0.19041--SP0-brightgreen)](https://www.microsoft.com/en-us/windows/get-windows-10)  [![GenXdev.Data](https://img.shields.io/powershellgallery/v/GenXdev.Data.svg?style=flat-square&label=GenXdev.Data)](https://www.powershellgallery.com/packages/GenXdev.Data/)  [![GenXdev.Helpers](https://img.shields.io/powershellgallery/v/GenXdev.Helpers.svg?style=flat-square&label=GenXdev.Helpers)](https://www.powershellgallery.com/packages/GenXdev.Helpers/) [![GenXdev.Webbrowser](https://img.shields.io/powershellgallery/v/GenXdev.Webbrowser.svg?style=flat-square&label=GenXdev.Webbrowser)](https://www.powershellgallery.com/packages/GenXdev.Webbrowser/) [![GenXdev.Queries](https://img.shields.io/powershellgallery/v/GenXdev.Queries.svg?style=flat-square&label=GenXdev.Queries)](https://www.powershellgallery.com/packages/GenXdev.Webbrowser/) [![GenXdev.Console](https://img.shields.io/powershellgallery/v/GenXdev.Console.svg?style=flat-square&label=GenXdev.Console)](https://www.powershellgallery.com/packages/GenXdev.Console/)  [![GenXdev.FileSystem](https://img.shields.io/powershellgallery/v/GenXdev.FileSystem.svg?style=flat-square&label=GenXdev.FileSystem)](https://www.powershellgallery.com/packages/GenXdev.FileSystem/)
### INSTALLATION
````PowerShell
Install-Module "GenXdev.Media"
Import-Module "GenXdev.Media"
````
### UPDATE
````PowerShell
Update-Module
````
<br/><hr/><hr/><br/>

# Cmdlet Index
### GenXdev.Media<hr/>
### GenXdev.Media.ytdlp
| Command | Aliases | Description |
| --- | --- | --- |
| [EnsureYtdlp](#ensureytdlp) | &nbsp; | Ensures yt-dlp is installed and available in the default WSL image. |
| [Invoke-YTDlpSaveVideo](#invoke-ytdlpsavevideo) | save-video, savevideo | Downloads a video from a specified URL using yt-dlp and saves metadata. |

<br/><hr/><hr/><br/>


# Cmdlets

&nbsp;<hr/>
###	GenXdev.Media.ytdlp<hr/> 

##	EnsureYtdlp 
````PowerShell 

   EnsureYtDlp  
```` 

### SYNOPSIS 
    Ensures yt-dlp is installed and available in the default WSL image.  

### SYNTAX 
````PowerShell 
EnsureYtDlp [-WhatIf] [-Confirm] [<CommonParameters>] 
```` 

### DESCRIPTION 
    Checks for WSL, installs it if missing, ensures the default image is present,  
    installs python3, pip3, pipx, and yt-dlp if needed using a single command to minimize sudo prompts,  
    and provides status messages. Returns $true if setup is successful.  

### PARAMETERS 
    -WhatIf [<SwitchParameter>]  
        Required?                    false  
        Position?                    named  
        Default value                  
        Accept pipeline input?       false  
        Aliases                        
        Accept wildcard characters?  false  
    -Confirm [<SwitchParameter>]  
        Required?                    false  
        Position?                    named  
        Default value                  
        Accept pipeline input?       false  
        Aliases                        
        Accept wildcard characters?  false  
    <CommonParameters>  
        This cmdlet supports the common parameters: Verbose, Debug,  
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,  
        OutBuffer, PipelineVariable, and OutVariable. For more information, see  
        about_CommonParameters     (https://go.microsoft.com/fwlink/?LinkID=113216).   

<br/><hr/><hr/><br/>
 

##	Invoke-YTDlpSaveVideo 
````PowerShell 

   Invoke-YTDlpSaveVideo                --> Save-Video, savevideo  
```` 

### SYNOPSIS 
    Downloads a video from a specified URL using yt-dlp and saves metadata.  

### SYNTAX 
````PowerShell 
Invoke-YTDlpSaveVideo [-Url] <String> [-OutputFileName <String>] [<CommonParameters>] 
```` 

### DESCRIPTION 
    Downloads a video from the provided URL using yt-dlp, saves subtitles,  
    description, and info JSON, sanitizes filenames, and stores metadata in NTFS  
    alternate data streams. Handles clipboard input and provides verbose output  
    for key steps.  

### PARAMETERS 
    -Url <String>  
        The video URL to download. If not provided, attempts to use clipboard.  
        Required?                    true  
        Position?                    1  
        Default value                  
        Accept pipeline input?       true (ByValue, ByPropertyName)  
        Aliases                        
        Accept wildcard characters?  false  
    -OutputFileName <String>  
        The output filename or template for the downloaded video.  
        Required?                    false  
        Position?                    named  
        Default value                %(title)s.%(ext)s  
        Accept pipeline input?       false  
        Aliases                        
        Accept wildcard characters?  false  
    <CommonParameters>  
        This cmdlet supports the common parameters: Verbose, Debug,  
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,  
        OutBuffer, PipelineVariable, and OutVariable. For more information, see  
        about_CommonParameters     (https://go.microsoft.com/fwlink/?LinkID=113216).   

<br/><hr/><hr/><br/>
