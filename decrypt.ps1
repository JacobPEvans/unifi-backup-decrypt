# PowerShell script to perform the same actions as decrypt.sh
# Authors:
# 2017-2019 Youfu Zhang
# 2019 Balint Reczey <balint.reczey@canonical.com>
# 2025 Jacob Evans <
# PowerShell version by Copilot

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$InputUnf,
    [Parameter(Mandatory=$false, Position=1)]
    [string]$OutputZip
)

function Show-Usage {
    Write-Host 'Usage: .\\decrypt.ps1 <input .unf file> <output .zip file>'
}

if (-not $OutputZip) {
    $OutputZip = $InputUnf -replace '\.\w+$', '.zip'
}

if (-not (Test-Path $InputUnf) -or -not $OutputZip) {
    Show-Usage
    exit 1
}

try {
    # Decrypt using OpenSSL
    $openssl = "openssl"
    $key = "626379616e676b6d6c756f686d617273"
    $iv = "75626e74656e74657270726973656170"
    $encArgs = "enc -d -in `"$InputUnf`" -out `"$OutputZip`" -aes-128-cbc -K $key -iv $iv -nopad"
    $proc = Start-Process -FilePath $openssl -ArgumentList $encArgs -NoNewWindow -Wait -PassThru
    if ($proc.ExitCode -ne 0) { throw "OpenSSL decryption failed." }

    Expand-Archive -Path $OutputZip -DestinationPath $($OutputZip -replace '\.zip$', '')
}
finally {

}
