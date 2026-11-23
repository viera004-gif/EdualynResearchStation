param(
    # Default development playtests stay offline. Pass an isolated dev API explicitly.
    [string]$ApiBase = 'http://127.0.0.1:1/api/v2/research-station',
    [ValidateSet('tr', 'en')]
    [string]$Locale = 'tr'
)
$godotPath = 'C:\Users\DELL\Desktop\Alkın\Programlar Setup\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godotPath)) {
    throw "Godot 4.7.2 not found at $godotPath"
}
& $godotPath --path $PSScriptRoot --rendering-method mobile --rendering-driver vulkan 'res://scenes/main/power_coupling_cascade.tscn' -- "--api-base=$ApiBase" "--locale=$Locale"
