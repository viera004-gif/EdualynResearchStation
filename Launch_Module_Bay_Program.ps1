param(
    [string]$ApiBase = 'http://127.0.0.1:1/api/v2/research-station',
    [ValidateSet('tr', 'en')]
    [string]$Locale = 'tr'
)
# Program access begins in the real 3D MB01 room. Use its operations console for MB02.
& (Join-Path $PSScriptRoot 'Launch_Module_Bay_Intervention_v02.ps1') -ApiBase $ApiBase -Locale $Locale
