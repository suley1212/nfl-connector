# NFL Connector

A puzzle game: connect two NFL players through a chain of shared teammates.

> Tom Brady → **Antonio Brown** → Ben Roethlisberger
> (Brady & Brown: NE 2019, TB 2020–21 · Brown & Roethlisberger: PIT 2010–18)

Two players count as teammates if they appear on the same team's roster in the
same season. Each daily puzzle has a **par** — the fewest links it can be
solved in, found by bidirectional BFS over the roster graph.

Modes: a **daily** puzzle seeded by the date (same for everyone), and **free
play** where you pick either endpoint or shuffle a random pair.

## Layout

```
data/game_data.json     compact teammate graph (committed, ~1.1 MB)
game/template.html      the game; __GAME_DATA__ is replaced at build time
game/index.html         generated artifact source (gitignored)
scripts/                build + local preview
raw/                    nflverse CSVs (gitignored, re-downloaded on demand)
```

## Build

```powershell
./scripts/build_game_data.ps1   # nflverse CSVs -> data/game_data.json
./scripts/build_game.ps1        # + template.html -> game/index.html
./scripts/serve.ps1             # preview at http://localhost:8731/
```

`build_game_data.ps1` downloads anything missing from `raw/`, so a clean
checkout only needs the two build commands.

## Data

Season rosters and draft picks from
[nflverse](https://github.com/nflverse/nflverse-data), covering **2000–2026**:
16,197 players, 40 team codes, ~1.1 MB after processing.

Three things the build has to handle:

- **Player identity.** `gsis_id` is ~100% populated from 2000 on, so players
  merge cleanly across seasons. (Before ~1990 it is absent entirely, which is
  why the window starts at 2000.)
- **Team code aliases.** nflverse uses different abbreviations by era — `ARZ`
  for `ARI`, `BLT` for `BAL`, `CLV`, `HST`, `SL` — but never two codes for one
  franchise in the same season, so teammate detection is unaffected. The game
  maps codes to era-accurate names (`OAK` → Oakland Raiders, `LV` → Las Vegas).
- **Fame vs. window.** `w_av`, Pro Bowls, All-Pros and HOF from `draft_picks`
  score how well-known a player is, used to pick puzzle endpoints and rank
  search. Since those are career-wide but the graph starts in 2000, fame is
  scaled by how many seasons a player actually has *inside* the window —
  otherwise someone like Cris Dishman (one 2000 season, fame 155) shows up as
  a puzzle endpoint. Endpoints also require 4+ in-window seasons.

Undrafted stars are absent from `draft_picks` entirely, so a small hand-set
list in the build script covers them (Warner, Romo, Gates, Welker, Vinatieri…).

## Extending

The window is a parameter — `./scripts/build_game_data.ps1 -StartSeason 1990`
rebuilds against more history. Going before ~1990 needs a name+birthdate
identity fallback, since `gsis_id` is not populated there.
