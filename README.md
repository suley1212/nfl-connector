# Move The Chains

A daily NFL puzzle: link two players through the teammates they shared a
roster with.

> Tom Brady → **Antonio Brown** → Ben Roethlisberger
> (Brady & Brown: NE 2019, TB 2020–21 · Brown & Roethlisberger: PIT 2010–18)

Two players are teammates if they appear on the same team's roster in the same
season. Reaching the target is a **touchdown**, however many links it took;
getting there with no wrong guesses and no hints is a **perfect drive**.

There is deliberately no par. Your chain length is reported, never graded —
the number is there so people can compare drives with each other, not so the
game can tell you that you fell short of some ideal.

The shortest possible chain is still computed by bidirectional BFS, but only
to *choose* the pair: it keeps a drive from being trivially already-teammates
or a slog. It is never shown. Internally that target is 1 on roughly a third
of days and 2 on the rest — never 3, because sampling the graph, no two
players recognisable enough to be endpoints are ever three links apart at any
era gap. Widening the season window backwards is what would change that.

## How it plays

**Downs.** A wrong guess costs a down. Convert a link and the chains move —
four fresh downs. Burn all four on one link and it is a turnover. Downs are on
in the **daily** and on **hard**; easy and medium free play have none.

**Difficulty** (free play only) controls how much the board gives away:

| | Plates and connectors show | Downs |
|---|---|---|
| Easy | team + seasons | no |
| Medium | team only | no |
| Hard | position only — rosters from memory | yes |

Finishing reveals every connection regardless of setting. The daily is always
full detail, and always four downs.

**Share** encodes the drive without naming anyone, so posting a result cannot
spoil the puzzle:

```
Move The Chains · Sep 7
🔵🟩🟨🟡
2 links · 🚩1 · 💡2
```

Start, one square per link (green clean, yellow after a miss, 🏈 if the whole
run was perfect), target. The strip's length *is* the score — that is the
number friends compare.

## Layout

```
data/game_data.json     compact teammate graph (committed, ~1.1 MB)
game/template.html      the game; __GAME_DATA__ is replaced at build time
game/index.html         generated artifact source (gitignored)
design/                 design direction the current build came from
scripts/                build + local preview
raw/                    nflverse CSVs (gitignored, re-downloaded on demand)
```

## Build

```powershell
./scripts/build_game_data.ps1   # nflverse CSVs -> data/game_data.json
./scripts/build_game.ps1        # + template.html -> game/index.html
./scripts/serve.ps1             # preview at http://localhost:8731/
```

## Data

Season rosters and draft picks from
[nflverse](https://github.com/nflverse/nflverse-data), covering **2000–2026**:
16,197 players, 35 team codes, ~1.1 MB after processing.

Four things the build and the game have to handle:

- **Player identity.** `gsis_id` is ~100% populated from 2000 on, so players
  merge cleanly across seasons. Before ~1990 it is absent entirely, which is
  why the window starts at 2000.
- **Team code aliases.** nflverse uses different abbreviations by era — `ARZ`
  for `ARI`, `BLT` for `BAL`, plus `CLV`, `HST`, `SL` — but never two codes for
  one franchise in the same season, so teammate detection was never affected.
  Left alone they still read wrong (a career showing "ARZ 2008–15, ARI 2016" as
  two teams), so the build folds them before collapsing stints, merging the
  adjoining seasons into one run. Real relocations stay distinct and
  era-accurate: `OAK` → Oakland Raiders, `LV` → Las Vegas.
- **Fame vs. window.** `w_av`, Pro Bowls, All-Pros and HOF from `draft_picks`
  score how well-known a player is. Those are career-wide but the graph starts
  in 2000, so fame is scaled by in-window seasons and endpoints need 4+ —
  otherwise Cris Dishman (one 2000 season, fame 155) turns up as a puzzle
  endpoint. Undrafted stars are absent from `draft_picks` entirely, so a small
  hand-set list covers them (Warner, Romo, Gates, Welker, Vinatieri…).
- **Era proximity.** Endpoints must be within 6 years of each other, and the
  daily draws from a stricter top-300 pool. Without it you get pairings like
  Penei Sewell (2021–) and Gus Frerotte (–2008): a legal two-link path exists,
  but solving it means knowing which twenty-year journeyman bridges the gap.

Hints run their own BFS from the target and pick the **highest-fame** player
that still keeps the chain at par, since the raw shortest path usually routes
through a special-teamer nobody has heard of.

## Extending

The window is a parameter — `./scripts/build_game_data.ps1 -StartSeason 1990`
rebuilds against more history. Going before ~1990 needs a name+birthdate
identity fallback, since `gsis_id` is not populated there.
