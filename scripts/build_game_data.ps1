# Builds the NFL Connector game data file from nflverse roster + draft data.
#
#   ./scripts/build_game_data.ps1
#
# Downloads any missing source CSVs into raw/, then writes data/game_data.json:
# a compact teammate graph (players -> team stints) plus a fame score used to
# pick puzzle endpoints and rank search results.

param(
    [int]$StartSeason = 2000,
    [int]$EndSeason = 2026,
    [string]$RawDir = "raw",
    [string]$OutFile = "data/game_data.json"
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
if (-not (Test-Path $RawDir)) { New-Item -ItemType Directory -Path $RawDir | Out-Null }
if (-not (Test-Path (Split-Path $OutFile))) { New-Item -ItemType Directory -Path (Split-Path $OutFile) | Out-Null }

# ---------------------------------------------------------------- downloads --
foreach ($season in $StartSeason..$EndSeason) {
    $dest = Join-Path $RawDir "roster_$season.csv"
    if (-not (Test-Path $dest)) {
        Write-Host "Downloading roster_$season.csv"
        Invoke-WebRequest -Uri "https://github.com/nflverse/nflverse-data/releases/download/rosters/roster_$season.csv" -OutFile $dest
    }
}
$draftCsv = Join-Path $RawDir "draft_picks.csv"
if (-not (Test-Path $draftCsv)) {
    Write-Host "Downloading draft_picks.csv"
    Invoke-WebRequest -Uri "https://github.com/nflverse/nflverse-data/releases/download/draft_picks/draft_picks.csv" -OutFile $draftCsv
}

# ------------------------------------------------------------ name helpers --
function ToInt($v) {
    $out = 0
    if ($null -eq $v) { return 0 }
    if ([int]::TryParse(([string]$v).Trim(), [ref]$out)) { return $out }
    return 0
}

function Normalize-Name([string]$n) {
    if ([string]::IsNullOrWhiteSpace($n)) { return "" }
    $s = $n.ToLowerInvariant()
    $s = $s -replace "[.'`�]", ""
    $s = $s -replace "[-]", " "
    $s = $s -replace "\s+(jr|sr|ii|iii|iv|v)$", ""
    $s = $s -replace "\s+", " "
    return $s.Trim()
}

# -------------------------------------------------------------- draft picks --
# gsis_id joins cleanly for 2000+ players; name is the fallback for the rest.
$draftByGsis = @{}
$draftByName = @{}
foreach ($d in (Import-Csv $draftCsv)) {
    $rec = [PSCustomObject]@{
        Hof      = ($d.hof -eq 'TRUE')
        AllPro   = ToInt $d.allpro
        ProBowls = ToInt $d.probowls
        Wav      = ToInt $d.w_av
        Games    = ToInt $d.games
        Started  = ToInt $d.seasons_started
        Round    = ToInt $d.round
        Pick     = ToInt $d.pick
        Season   = ToInt $d.season
    }
    if ($d.gsis_id -like "00-*") { $draftByGsis[$d.gsis_id] = $rec }
    $nn = Normalize-Name $d.pfr_player_name
    if ($nn -ne "") {
        if (-not $draftByName.ContainsKey($nn)) { $draftByName[$nn] = New-Object System.Collections.ArrayList }
        [void]$draftByName[$nn].Add($rec)
    }
}
Write-Host "Draft records: byGsis=$($draftByGsis.Count) byName=$($draftByName.Count)"

# Modern stars who went undrafted (absent from draft_picks) or whose value the
# draft table understates. Scores are hand-set on the same scale as the formula.
$undraftedBoost = @{
    "kurt warner" = 300; "tony romo" = 250; "antonio gates" = 300; "wes welker" = 260
    "adam vinatieri" = 240; "james harrison" = 240; "arian foster" = 210; "priest holmes" = 200
    "jeff saturday" = 210; "john randle" = 220; "rod smith" = 200; "warren moon" = 200
    "london fletcher" = 230; "jason peters" = 250; "brian waters" = 190; "chris harris" = 200
    "malcolm butler" = 150; "danny amendola" = 150; "doug baldwin" = 180; "adam thielen" = 200
    "austin ekeler" = 200; "legarrette blount" = 150; "fred jackson" = 150; "willie parker" = 150
    "cameron wake" = 210; "wayne chrebet" = 150; "sam mills" = 180; "everson walls" = 150
    "mike rucker" = 130; "david akers" = 170; "shayne graham" = 120; "phil dawson" = 160
    "jermichael finley" = 120; "victor cruz" = 170; "chris ivory" = 130; "james develin" = 100
    "brandon browner" = 130; "benny cunningham" = 100; "robert turbin" = 100; "mike daniels" = 130
    "jamaal charles" = 0
}

# ------------------------------------------------------------------ parsing --
class PlayerRec {
    [string]$Name
    [string]$Gsis
    [System.Collections.Generic.Dictionary[string, int]]$Pos
    [System.Collections.Generic.HashSet[string]]$TS
    PlayerRec([string]$name, [string]$gsis) {
        $this.Name = $name
        $this.Gsis = $gsis
        $this.Pos = New-Object 'System.Collections.Generic.Dictionary[string,int]'
        $this.TS = New-Object 'System.Collections.Generic.HashSet[string]'
    }
}

$players = New-Object 'System.Collections.Generic.Dictionary[string,PlayerRec]'

foreach ($season in $StartSeason..$EndSeason) {
    $path = Join-Path $RawDir "roster_$season.csv"
    if (-not (Test-Path $path)) { continue }
    $rows = Import-Csv $path
    foreach ($r in $rows) {
        $team = $r.team
        $name = $r.full_name
        if ([string]::IsNullOrWhiteSpace($team) -or [string]::IsNullOrWhiteSpace($name)) { continue }

        $gsis = $r.gsis_id
        if (-not [string]::IsNullOrWhiteSpace($gsis)) { $key = "g:" + $gsis }
        else { $key = "n:" + (Normalize-Name $name) + "|" + $r.birth_date }

        $rec = $null
        if (-not $players.TryGetValue($key, [ref]$rec)) {
            $rec = [PlayerRec]::new($name, $gsis)
            $players[$key] = $rec
        }
        if ($name.Length -gt $rec.Name.Length) { $rec.Name = $name }
        $pos = $r.position
        if (-not [string]::IsNullOrWhiteSpace($pos)) {
            if ($rec.Pos.ContainsKey($pos)) { $rec.Pos[$pos]++ } else { $rec.Pos[$pos] = 1 }
        }
        [void]$rec.TS.Add("$team|$season")
    }
    Write-Host "  $season parsed (running unique players: $($players.Count))"
}
Write-Host "Unique players $StartSeason-${EndSeason}: $($players.Count)"

# ------------------------------------------------------------ team indexing --
$allTeams = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($kv in $players.GetEnumerator()) {
    foreach ($ts in $kv.Value.TS) { [void]$allTeams.Add($ts.Split('|')[0]) }
}
$teamList = @($allTeams | Sort-Object)
$teamIndex = @{}
for ($i = 0; $i -lt $teamList.Count; $i++) { $teamIndex[$teamList[$i]] = $i }
Write-Host "Team codes: $($teamList.Count) -> $($teamList -join ',')"

# ---------------------------------------------------------------- emit JSON --
function JsonEsc([string]$s) { return $s.Replace('\', '\\').Replace('"', '\"') }

$sb = New-Object System.Text.StringBuilder
[void]$sb.Append('{"startSeason":' + $StartSeason + ',"endSeason":' + $EndSeason)
[void]$sb.Append(',"teams":[')
for ($i = 0; $i -lt $teamList.Count; $i++) {
    if ($i -gt 0) { [void]$sb.Append(',') }
    [void]$sb.Append('"' + $teamList[$i] + '"')
}
[void]$sb.Append('],"players":[')

$first = $true
$idx = 0
$famed = 0
foreach ($kv in ($players.GetEnumerator() | Sort-Object { $_.Value.Name })) {
    $rec = $kv.Value

    # stints: group seasons by team, collapse consecutive runs into ranges
    $byTeam = New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.Generic.List[int]]'
    foreach ($ts in $rec.TS) {
        $parts = $ts.Split('|')
        $lst = $null
        if (-not $byTeam.TryGetValue($parts[0], [ref]$lst)) {
            $lst = New-Object 'System.Collections.Generic.List[int]'
            $byTeam[$parts[0]] = $lst
        }
        $lst.Add([int]$parts[1])
    }
    $stints = New-Object System.Collections.ArrayList
    foreach ($tkv in $byTeam.GetEnumerator()) {
        $tIdx = $teamIndex[$tkv.Key]
        $seasons = @($tkv.Value | Sort-Object -Unique)
        $start = $null; $prev = $null
        foreach ($s in $seasons) {
            if ($null -eq $start) { $start = $s; $prev = $s }
            elseif ($s -eq $prev + 1) { $prev = $s }
            else { [void]$stints.Add("[$tIdx,$start,$prev]"); $start = $s; $prev = $s }
        }
        if ($null -ne $start) { [void]$stints.Add("[$tIdx,$start,$prev]") }
    }
    if ($stints.Count -eq 0) { continue }

    # primary position
    $topPos = ""; $topCount = -1
    foreach ($pk in $rec.Pos.GetEnumerator()) {
        if ($pk.Value -gt $topCount) { $topCount = $pk.Value; $topPos = $pk.Key }
    }

    # fame: weighted AV carries the signal, accolades sharpen the top end
    $nn = Normalize-Name $rec.Name
    $d = $null
    if ($rec.Gsis -ne "" -and $draftByGsis.ContainsKey($rec.Gsis)) { $d = $draftByGsis[$rec.Gsis] }
    elseif ($draftByName.ContainsKey($nn)) {
        # disambiguate same-name draftees by career overlap with the draft year
        $firstSeason = ($rec.TS | ForEach-Object { [int]$_.Split('|')[1] } | Measure-Object -Minimum).Minimum
        foreach ($cand in $draftByName[$nn]) {
            if ($firstSeason -ge $cand.Season -and $firstSeason -le ($cand.Season + 5)) { $d = $cand; break }
        }
    }
    $fame = 0
    if ($null -ne $d) {
        $fame = [int](60 * [int]$d.Hof + 8 * $d.ProBowls + 12 * $d.AllPro + 1.0 * $d.Wav + 0.08 * $d.Games + 3 * $d.Started)
    }
    if ($undraftedBoost.ContainsKey($nn) -and $undraftedBoost[$nn] -gt $fame) { $fame = $undraftedBoost[$nn] }
    if ($fame -gt 0) { $famed++ }

    if (-not $first) { [void]$sb.Append(',') }
    $first = $false
    [void]$sb.Append('{"n":"' + (JsonEsc $rec.Name) + '","p":"' + (JsonEsc $topPos) + '","f":' + $fame + ',"s":[' + ($stints -join ',') + ']}')
    $idx++
}
[void]$sb.Append(']}')

[System.IO.File]::WriteAllText((Join-Path $root $OutFile), $sb.ToString())
$sizeMb = [math]::Round((Get-Item $OutFile).Length / 1MB, 2)
Write-Host ""
Write-Host "Wrote $OutFile"
Write-Host "  players: $idx  (with fame score: $famed)"
Write-Host "  teams:   $($teamList.Count)"
Write-Host "  size:    $sizeMb MB"
