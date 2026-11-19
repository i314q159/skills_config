$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$dir = Join-Path $HOME '.workbuddy\skills'
$out = Join-Path $PSScriptRoot 'skills.json'

$prev = @{}
if (Test-Path $out) {
    $old = Get-Content $out -Raw | ConvertFrom-Json
    $items = if ($old -is [array]) { $old } elseif ($old.skills) { $old.skills } else { @($old) }
    foreach ($i in $items) { if ($i.name -and $i.source) { $prev[$i.name] = $i.source } }
}

$list = Get-ChildItem $dir -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') } | ForEach-Object {
    $text = Get-Content (Join-Path $_.FullName 'SKILL.md') -Raw
    $name = if ($text -match '(?m)^name:\s*(\S+)') { $Matches[1] } else { $_.Name }

    if ($text -match 'github\.com[/:]([\w.-]+)/([\w.-]+)') {
        $source = "github.com/$($Matches[1])/$($Matches[2] -replace '\.git$', '')"
    } elseif ($prev.ContainsKey($name)) {
        $source = $prev[$name]
    } else {
        $source = ''
        try {
            $hit = (Invoke-RestMethod "https://skills.sh/api/search?q=$([uri]::EscapeDataString($name))" -TimeoutSec 15).skills |
                Where-Object { $_.name -eq $name -and $_.source -match '^[\w.-]+/[\w.-]+$' } |
                Select-Object -First 1
            if ($hit) { $source = "github.com/$($hit.source)" }
        } catch { }
    }

    [pscustomobject]@{ name = $name; source = $source }
}

$list | Sort-Object name | Format-Table -AutoSize
$miss = @($list | Where-Object { -not $_.source } | ForEach-Object { $_.name })
if ($miss) { Write-Warning "no source found for: $($miss -join ', ')" }

[IO.File]::WriteAllText($out, (ConvertTo-Json -InputObject @($list) -Depth 3), (New-Object Text.UTF8Encoding($false)))
