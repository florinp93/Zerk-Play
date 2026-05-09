# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2026-05-09

### Added

#### Playback
- **ASS/SSA subtitle rendering** — embedded ASS and SSA subtitles now render using libass with the subtitle file's own styling (fonts, colours, positioning) instead of the player-enforced style. The player's style override (`sub-ass-override`) is set to `no` for ASS/SSA tracks and `force` for plain-text tracks.
- **Subtitle pre-selection fix** — subtitles chosen in the pre-player UI are now correctly active at the very start of playback. A race condition where mpv had not yet enumerated embedded tracks was resolved with format-aware polling (up to 6 s for image-based formats such as PGS/PGSSUB, 4 s for text-based formats).
- **Audio passthrough (Atmos / TrueHD / DTS)** — a new "Passthrough codecs (audio-spdif)" dropdown in the MPV Settings → Audio tab lets users select a bitstream passthrough preset. Choices include AC-3, E-AC-3, TrueHD (Atmos), DTS, DTS-HD, and common combinations. When a passthrough codec is configured, the Emby device profile includes it in direct-play so the raw bitstream reaches mpv without server-side transcoding.
- **Display refresh rate matching** — mpv can now switch the Windows display refresh rate to match the video frame rate at the start of playback. Two settings are exposed on the main Settings screen: "Match display refresh rate to video" and "Only while fullscreen". The refresh rate is **not** reverted when playback ends, matching the user's preferred behaviour.

#### MPV Settings UI & Configuration
- **`mpv.conf` support** — Zerk Play now creates, manages, and loads a persistent `mpv.conf` file stored in the application support directory. This gives users (and power users who prefer editing the file directly) full control over every libmpv option. The file is created with sensible defaults on first launch and is loaded into the player before every playback session, so changes take effect without restarting the app. An "Open config folder" shortcut in the App tab lets users open the file in Explorer.
- **Full tabbed MPV settings dialog** — rather than exposing the raw config file as a text editor, a comprehensive tabbed UI (Video, Audio, Subtitles, Network, App) is provided. Every control reads from and writes to `mpv.conf`; the file remains the single source of truth so manual edits and UI changes coexist correctly.
- **Video tab** — hardware decoding (`hwdec`), GPU API (`gpu-api`), video output (`vo`), sync mode (`video-sync`), interpolation, scaling filters (scale/dscale/cscale), debanding, HDR peak detection, tone-mapping, and seek options.
- **Audio tab** — pitch correction, normalise downmix, volume ceiling, audio delay, and the new passthrough section.
- **Subtitles tab** — ASS override mode, font size, scale, margins, border, shadow, blur, position offset, and timing fix.
- **Network & Cache tab** — network timeout, TLS verification, cache enable/size, demuxer read-ahead, and on-disk cache.
- **App tab** — display refresh rate toggles (moved here from playback settings) and a shortcut to open the config folder in Explorer.

#### Collections
- **Collection detail page** — tapping any collection (grid tile or "View all" button in card view) opens a dedicated cinematic page. The page features a full-bleed backdrop image with a darkening gradient, a glassmorphic header showing the collection logo (or title), a "N titles" badge, and the overview text. Below the header a responsive poster grid (3–8 columns) lists every movie and series in the collection, each tile showing the poster, title, watch-progress bar, and a "watched" checkmark. Tapping a tile navigates to the existing details page.
- **Collections view toggle** — the Collections screen now has a toggle button to switch between the original large-card view (backdrop + horizontal movie scroll) and a compact cover-art grid identical in style to the movie/series library. The chosen layout is persisted between sessions.
- **"View all" button on card-view sections** — each collection card in the card view now shows a "View all →" button in the header area that opens the collection detail page.

#### Library
- **Sort by in library filter sheet** — a "Sort by" dropdown has been added to the filter panel on the Movies and Series library pages. Available sorts: Name A–Z, Name Z–A, Date added (newest), Date added (oldest), Year (newest), Year (oldest), Rating. The selection is applied immediately and resets when the library type changes or on refresh.

#### App
- **Permanent fullscreen** — a "Start in fullscreen" toggle in the main Settings screen puts the application window into native fullscreen on launch. The setting is applied immediately when saved, and on every subsequent launch. Implemented via the `window_manager` package.
- **Smooth scrolling** — mouse-drag scrolling and bouncing scroll physics are applied globally, making list and grid navigation feel natural with a mouse or trackpad.

### Changed
- **MPV configuration applied before opening media** — `mpv.conf` (including `audio-spdif` and all other options) is now loaded into libmpv **before** `player.open()` is called, eliminating audio-output re-initialisation mid-demux. This resolves the black-screen and silent-audio symptoms seen with TrueHD and other high-channel-count formats.
- **TrueHD / DTS-HD only direct-played when passthrough is active** — the Emby device profile is now built dynamically at playback-request time. TrueHD and DTS-HD are included in the direct-play audio codec list only when the user has configured SPDIF passthrough for those codecs. Without passthrough, Emby transcodes them to E-AC-3, which plays correctly through WASAPI on any Windows audio device. This mirrors the behaviour of Emby Theater and Jellyfin Media Player.
- **`video-sync=display-resample` and `interpolation=yes` no longer forced as defaults** — these settings significantly increase CPU/GPU load on high-refresh-rate displays. They are now commented-out opt-in entries in the generated `mpv.conf` template, with an explanatory note.
- **Selecting "None" for passthrough no longer writes `audio-spdif=` to the config** — an explicit empty-string value for list-type mpv options (`audio-spdif`, `audio-device`, `af`) is now omitted from the saved file rather than written as `key=`, avoiding unnecessary audio-output resets on the next playback session.
- **Refresh rate settings moved to main Settings screen** — the "Match display refresh rate" toggles were removed from the MPV Settings dialog and are now alongside other display options in the main Settings dialog, making them easier to discover.
- **Display refresh rate no longer reverted on playback end** — previously the refresh rate was restored to its original value when leaving the player. It now stays at the matched rate, as users on dedicated media-PC setups expect.

### Fixed
- Subtitles selected before playback (ASS, SSA, PGS, PGSSUB) are now active from the first frame instead of requiring manual re-selection after the player starts.
- TrueHD 7.1 playback no longer produces silence on standard stereo Windows systems (server now transcodes to E-AC-3 when passthrough is not configured).
- Selecting a passthrough codec when the audio device does not support IEC 61937 no longer causes a black screen; mpv initialises audio before opening the file so failures are handled before playback begins.
- `AppPrefs` construction in the setup wizard updated to use `AppPrefs.defaults.copyWith(...)` so newly added preference fields are always initialised to their defaults.
- Filter chips in the library page now correctly re-apply the active sort order when a genre or year chip is removed.

---

## [1.0.1] - 2026-04-07

### Changed
- Windows playback smoothness: set mpv properties `video-sync=display-resample`, `gpu-api=d3d11`, `interpolation=yes`, and `hwdec=d3d11va`.
- Player input: mouse wheel volume works anywhere over the player surface (including over overlays/controls).
- Player overlays: subtitles are non-interactive so pointer signals can pass through.
- Next Up: requests 2 items and excludes the current episode id so the Next Up UI does not show the currently playing episode.
- Feedback: adds a top-right "Feedback" button (hidden on the player) that opens the Discord link, with a settings toggle to disable it.
- First-time setup: exposes app preferences (language/playback defaults/feedback toggle) on the setup screen so users can set them before login.
