param([Parameter(Mandatory=$true)][string]$Script, [string[]]$ScriptArgs = @())
# Blender'i (Microsoft Store surumu) arka planda bir Python scriptiyle calistirir.
$launcher = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\blender-launcher.exe"
$argList = @("--background", "--factory-startup", "--python", "`"$Script`"")
if ($ScriptArgs.Count -gt 0) { $argList += "--"; $argList += $ScriptArgs }
$p = Start-Process -FilePath $launcher -ArgumentList $argList -PassThru -Wait -NoNewWindow
exit $p.ExitCode
