# localization\parts\*.csv dosyalarını localization\strings.csv içinde birleştirir (keys,tr).
# Kullanım: powershell -ExecutionPolicy Bypass -File tools\merge_localization.ps1
$root = Split-Path -Parent $PSScriptRoot
$parts = Join-Path $root "localization\parts"
$out = Join-Path $root "localization\strings.csv"
$map = [ordered]@{}
Get-ChildItem $parts -Filter *.csv | Sort-Object Name | ForEach-Object {
    $rows = Import-Csv -Path $_.FullName -Encoding UTF8
    foreach ($r in $rows) {
        if ([string]::IsNullOrWhiteSpace($r.keys)) { continue }
        if ($map.Contains($r.keys)) {
            Write-Host "Yinelenen anahtar atlandı: $($r.keys) ($($_.Name))"
            continue
        }
        $map[$r.keys] = $r.tr
    }
}
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("keys,tr")
foreach ($k in $map.Keys) {
    $v = [string]$map[$k]
    $v = '"' + $v.Replace('"', '""') + '"'
    [void]$sb.AppendLine("$k,$v")
}
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($out, $sb.ToString(), $utf8)
Write-Host "Toplam anahtar: $($map.Count) -> $out"
