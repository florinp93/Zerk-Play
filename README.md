# Zerk-Cloud
Zerk Play is a couch-friendly Emby desktop client with built-in *seerr request integration.
<img width="1266" height="713" alt="image" src="https://github.com/user-attachments/assets/1b318a5e-7785-4873-8c21-26083f32e0df" />
Zerk Play is a custom Emby desktop front-end designed for fast browsing, big-screen use, and seamless requests via your \*seerr instance.


[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/florinp93)
On first launch, you configure:

- Emby Server URL
- \*seerr URL (or Jellyseerr)
- \*seerr API key (or Jellyseerr)

Then you sign in with your Emby username + password on the next screen.

### What You Get

- A clean home experience for Movies and Shows
- Artwork-forward lists
- Search that shows what you already have and what you can request
- One-click requests via \*seerr
- Playback powered by media\_kit / mpv on Windows that doesn't force your server to transcode
- Built-in auto-updater to keep you on the latest release


<img width="1266" height="713" alt="image" src="https://github.com/user-attachments/assets/7abc6c6e-583a-4fdb-bca9-433af370eccf" />
Note - The application currently supports English and Romanian for the UI

-----------------------------------------------------------------------------------------------

<img width="1266" height="713" alt="image" src="https://github.com/user-attachments/assets/9b48626c-2c47-4038-a3bb-bfe802e7c72b" />
Note - The Metadata language in your Emby server controls the names and descriptions for the Media Items inside the application.

-----------------------------------------------------------------------------------------------
<img width="1266" height="713" alt="image" src="https://github.com/user-attachments/assets/d11012e5-fc7a-4a78-a5f0-ccac23895e10" />

Note - "Latest Movies" filters your movie library and displays the latest added movies to your server / "Recently Released Movies" filters your movies library and displays them based on release date (Same logic applies to the Series sections).

-----------------------------------------------------------------------------------------------
<img width="1266" height="713" alt="image" src="https://github.com/user-attachments/assets/3537c2cc-1682-4c29-8aed-3cca5488dc42" />
Note - "Trending Movies" is built dynamically using your Emby library + the *seerr integragion. It is build using the Trending section from *seerr. Items that are available on the server are playable, items that are not available in the library are requestable. The "Top Rated Movies" section is build dynamically and displays the 10 Highest rated movies in your Library. (Same logic applies to Series)


-----------------------------------------------------------------------------------------------
<img width="1266" height="713" alt="image" src="https://github.com/user-attachments/assets/ce08d7a0-edf1-4718-838f-45dc63909fd0" />
Dynamic rows like "Because you've watched" / "You Might Enjoy" / "Your next binge" are build based on logged in user's Watch history in Emby

-----------------------------------------------------------------------------------------------
Series episodes can be viewed in a List/Grid
<img width="1266" height="713" alt="image" src="https://github.com/user-attachments/assets/5517db5c-ea49-4f19-b4e2-87916c61e99d" />

The *seerr integration allows you to easily request content for your server. Items to request can either be discovered from the library or using by using Search.
<img width="1266" height="713" alt="image" src="https://github.com/user-attachments/assets/fc6fd813-f7fe-44ae-95f9-5b816f1e35ff" />
<img width="1266" height="713" alt="image" src="https://github.com/user-attachments/assets/156066d7-502c-4401-b4a9-b27885c0eb39" />

MPV Play with easy to use UI (Skip Intro and Autoplay for next episodes is available)
<img width="1266" height="713" alt="image" src="https://github.com/user-attachments/assets/b13d7152-d2b8-4243-911d-7dda281bed36" />
<img width="1266" height="713" alt="image" src="https://github.com/user-attachments/assets/bbf59799-8870-4bb7-a925-568a11338b0f" />
-----------------------------------------------------------------------------------------------

### The Deities (How It’s Built)

- **Janus**: Emby authentication and session state
- **Hermes**: Library and metadata fetching
- **Apollo**: Playback registration and playback engine wiring
- **Artemis**: \*seerr integration (recommendations, search, requests)
- **Hephaestus**: Forge and updates (built-in auto-updater service)
- **Iris**: The UI layer (pages, theming, localization)

### Notes

- You bring your own servers and API key; nothing is hardcoded.
- This project is not affiliated with Emby, Jellyseerr, Overseerr, or TMDB.

## Roadmap (Next Up)

- **High priority**: Android & Android TV version
- **Medium priority**: Emby Live TV & Music libraries
