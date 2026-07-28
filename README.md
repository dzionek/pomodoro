# 🍅 Pomodoro

A minimal native macOS pomodoro timer that lives in your menu bar.

## Features

- **Menu bar app** — a small tomato icon in the top-right bar, no Dock icon,
  with the live countdown shown right next to it.
- **Sprints** — a sprint is a loop of *work X min → break Y min* repeated
  *N* times, finished with a long break of *Z* min, then the next sprint
  starts over. Defaults: X=25, Y=5, N=3, Z=15 — all configurable in the
  popover settings.
- **Nothing starts by itself** — every work and break segment is started
  explicitly by you. While a segment runs you see the remaining time and
  the exact time of day it will end. When it finishes, a bell rings loudly
  until you acknowledge it.
- **Progress tracking** — the app knows where you are in the sprint and
  counts completed work sessions, loops, and sprints.
- **Day & week calendar** — an hour-by-hour view of your day or week with
  work (red) and break (green) blocks drawn at their exact minutes. Time
  outside any segment stays blank. Hover a block for its precise times.

## Install

Requires macOS 13+ and the Xcode command line tools to build:

```sh
git clone <this repo>
cd pomodoro
./build.sh
open Pomodoro.app
```

Move `Pomodoro.app` to `/Applications` if you want to keep it around, and
add it to *System Settings → General → Login Items* to start it at login.

## Usage

Click the tomato in the menu bar:

- **Start Work / Start Break** — begin the next segment of the sprint.
- **Cancel segment** — abandon a running segment; the time you already
  spent stays on the calendar (hatched), but the sprint position doesn't
  advance.
- **Stop bell** — acknowledge a finished segment.
- **Statistics…** — open the day/week calendar and totals.
- **⚙** — change work/break/loop durations.

## Data

Session history is stored as plain JSON in
`~/Library/Application Support/Pomodoro/sessions.json`; settings and the
current sprint position live in user defaults. Nothing leaves your Mac.
