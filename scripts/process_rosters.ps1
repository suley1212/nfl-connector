$ErrorActionPreference = "Stop"
$rawDir = "raw_rosters"
$files = Get-ChildItem $rawDir -Filter "roster_*.csv" | Sort-Object Name

# key -> PlayerRec
class PlayerRec {
    [string]$Name
    [System.Collections.Generic.Dictionary[string,int]]$Pos
    [System.Collections.Generic.HashSet[string]]$TS   # "team|season"
    PlayerRec([string]$name) {
        $this.Name = $name
        $this.Pos = New-Object 'System.Collections.Generic.Dictionary[string,int]'
        $this.TS = New-Object 'System.Collections.Generic.HashSet[string]'
    }
}

$players = New-Object 'System.Collections.Generic.Dictionary[string,PlayerRec]'

$fileCount = 0
foreach ($f in $files) {
    $fileCount++
    $rows = Import-Csv $f.FullName
    foreach ($r in $rows) {
        $season = $r.season
        $team = $r.team
        if ([string]::IsNullOrWhiteSpace($team) -or [string]::IsNullOrWhiteSpace($season)) { continue }
        $name = $r.full_name
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        $gsis = $r.gsis_id
        $bd = $r.birth_date
        $pos = $r.position

        if (-not [string]::IsNullOrWhiteSpace($gsis)) {
            $key = "g:" + $gsis
        } else {
            $key = "n:" + $name.Trim().ToLowerInvariant() + "|" + $bd
        }

        $rec = $null
        if (-not $players.TryGetValue($key, [ref]$rec)) {
            $rec = [PlayerRec]::new($name)
            $players[$key] = $rec
        }
        if ($name.Length -gt $rec.Name.Length) { $rec.Name = $name }
        if (-not [string]::IsNullOrWhiteSpace($pos)) {
            if ($rec.Pos.ContainsKey($pos)) { $rec.Pos[$pos]++ } else { $rec.Pos[$pos] = 1 }
        }
        [void]$rec.TS.Add("$team|$season")
    }
    if ($fileCount % 20 -eq 0) { Write-Host "Parsed $fileCount / $($files.Count) files, players so far: $($players.Count)" }
}

Write-Host "Done parsing all files. Total unique player keys: $($players.Count)"

# Build team index
$teamIndex = New-Object 'System.Collections.Generic.Dictionary[string,int]'
$teamList = New-Object 'System.Collections.Generic.List[string]'

function Get-TeamIdx([string]$t) {
    $idx = -1
    if (-not $teamIndex.TryGetValue($t, [ref]$idx)) {
        $idx = $teamList.Count
        $teamList.Add($t)
        $teamIndex[$t] = $idx
    }
    return $idx
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.Append('{"teams":[')
$first = $true

# First pass to register all teams in stable order (sorted) - collect all team codes
$allTeams = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($kv in $players.GetEnumerator()) {
    foreach ($ts in $kv.Value.TS) {
        $parts = $ts.Split('|')
        [void]$allTeams.Add($parts[0])
    }
}
$sortedTeams = $allTeams | Sort-Object
foreach ($t in $sortedTeams) { [void](Get-TeamIdx $t) }
for ($i = 0; $i -lt $teamList.Count; $i++) {
    if (-not $first) { [void]$sb.Append(',') }
    $first = $false
    [void]$sb.Append('"' + $teamList[$i] + '"')
}
[void]$sb.Append('],"players":[')

function JsonEsc([string]$s) {
    return $s.Replace('\','\\').Replace('"','\"')
}

$first = $true
$playerId = 0
foreach ($kv in $players.GetEnumerator()) {
    $rec = $kv.Value
    # group by team -> sorted seasons -> collapse consecutive into ranges
    $byTeam = New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.Generic.List[int]]'
    foreach ($ts in $rec.TS) {
        $parts = $ts.Split('|')
        $team = $parts[0]
        $season = [int]$parts[1]
        $lst = $null
        if (-not $byTeam.TryGetValue($team, [ref]$lst)) {
            $lst = New-Object 'System.Collections.Generic.List[int]'
            $byTeam[$team] = $lst
        }
        $lst.Add($season)
    }
    $stints = New-Object 'System.Collections.Generic.List[string]'
    foreach ($tkv in $byTeam.GetEnumerator()) {
        $seasons = $tkv.Value | Sort-Object -Unique
        $tIdx = Get-TeamIdx $tkv.Key
        $start = $null
        $prev = $null
        foreach ($s in $seasons) {
            if ($null -eq $start) { $start = $s; $prev = $s }
            elseif ($s -eq $prev + 1) { $prev = $s }
            else {
                $stints.Add("[$tIdx,$start,$prev]")
                $start = $s; $prev = $s
            }
        }
        if ($null -ne $start) { $stints.Add("[$tIdx,$start,$prev]") }
    }
    if ($stints.Count -eq 0) { continue }

    # top position
    $topPos = ""
    $topCount = -1
    foreach ($pk in $rec.Pos.GetEnumerator()) {
        if ($pk.Value -gt $topCount) { $topCount = $pk.Value; $topPos = $pk.Key }
    }

    if (-not $first) { [void]$sb.Append(',') }
    $first = $false
    [void]$sb.Append('{"i":' + $playerId + ',"n":"' + (JsonEsc $rec.Name) + '","p":"' + (JsonEsc $topPos) + '","s":[' + ($stints -join ',') + ']}')
    $playerId++
}
[void]$sb.Append(']}')

Write-Host "Total players with stints: $playerId"
Write-Host "Total teams: $($teamList.Count)"

[System.IO.File]::WriteAllText("processed/nfl_graph.json", $sb.ToString())
Write-Host "Wrote processed/nfl_graph.json"
$len = (Get-Item "processed/nfl_graph.json").Length
Write-Host "File size: $([math]::Round($len/1MB,2)) MB"
