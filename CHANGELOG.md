# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Changed
- D-pad navigation is currently disabled due to ongoing changes for the upcoming Android TV build.

## [1.0.1] - 2026-04-07

### Changed
- Windows playback smoothness: set mpv properties `video-sync=display-resample`, `gpu-api=d3d11`, `interpolation=yes`, and `hwdec=d3d11va` (keeps embedded video output; does not force `vo=gpu-next`).
- Player input: mouse wheel volume works anywhere over the player surface (including over overlays/controls).
- Player overlays: subtitles are non-interactive so pointer signals can pass through.
- Next Up: requests 2 items and excludes the current episode id so the Next Up UI does not show the currently playing episode.
- Feedback: adds a top-right “Feedback” button (hidden on the player) that opens the Discord link, with a settings toggle to disable it.
- First-time setup: exposes app preferences (language/playback defaults/feedback toggle) on the setup screen so users can set them before login.
