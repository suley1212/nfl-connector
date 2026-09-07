# NFL Connector

A puzzle game: connect two NFL players through a chain of teammates
(e.g. Tom Brady -> Antonio Brown -> Ben Roethlisberger).

## Data

`data/nfl_graph.json` is a compact teammate graph built from
[nflverse](https://github.com/nflverse/nflverse-data) season roster data,
covering 1920-2026 (33k+ players, 86 team codes).

Regenerate it with:

```powershell
./scripts/process_rosters.ps1
```

This downloads season roster CSVs from nflverse-data releases into
`raw_rosters/`, dedupes each player's team stints, collapses consecutive
seasons into ranges, and writes the compact graph to
`processed/nfl_graph.json`.

## Game

The playable game is published as a Claude Artifact (single-page HTML/JS),
built from `data/nfl_graph.json`.
