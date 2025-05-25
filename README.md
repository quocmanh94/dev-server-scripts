# dev-server-scripts

A set of scripts for convenient launching and restarting of local server with mods or diagnostics

## Contact Information:

- Discord: https://discord.gg/pww4zwz6rM
- GitHub: https://github.com/MPG-DayZ/dev-server-scripts

## Features

- 🚀 Launch DayZ server and client together or separately
- 🎮 Support for presets for server settings and mod lists, so you don't have to write different mod sets for connection each time
- 🌍 Multilingual support (Russian and English)
- 🧹 Automatic cleanup of server and client logs on startup
- 🔧 Proper DayzDiag launch with mods
- 📦 Support for experimental game version
- 🛠️ Automatic config and shortcut creation on first script launch

## How to Use

> [!IMPORTANT]
> PowerShell 7 is required for the script to work [powershell 7](https://aka.ms/PowerShell)
>
> PowerShell 7.5 release: https://github.com/PowerShell/PowerShell/releases/tag/v7.5.0

1. [Download release](https://github.com/MPG-DayZ/dev-server-scripts/releases/latest)
2. Extract archive to any folder
3. Run the `start.ps1` file
4. Follow the initial config setup instructions
5. Launch what you need through the automatically created shortcuts

## What the Script Does

### File Structure After First Launch

```
dev-server-scripts/        # Project root folder
│
├── start.ps1              # Main launch script
├── config.json            # Configuration file
│
├── scripts/               # Scripts folder
│   ├── config.ps1         # Launch configuration script
│   ├── clearlogs.ps1      # Log cleanup script
│   ├── kill.ps1           # Process termination script
│   ├── locales.json       # Localization file
│   │
│   └── icons/             # Icons folder for shortcuts
│       ├── server-start.ico
│       ├── server-stop.ico
│       ├── client-start.ico
│       ├── client-stop.ico
│       ├── all-start.ico
│       └── all-stop.ico
│   
└── links/                 # Launch shortcuts folder
    ├── Start Server.lnk
    ├── Start Client.lnk
    ├── Start All.lnk
    ├── Kill Server.lnk
    ├── Kill Client.lnk
    └── Kill All.lnk
```

### config.json

> [!IMPORTANT]
>
> All paths in the file must use forward slashes `/`, not backslashes like in Windows paths `\`
>
> This is done for convenience since in JSON backslashes need to be escaped with backslashes 🤡 which is very inconvenient

config.json - created on first script launch and requires configuration!

#### config.json Structure

```
config.json
│
├── active                 # Active settings
│   ├── serverPreset       # Active server preset name
│   ├── modPreset          # Active mod preset name
│   ├── autoCloseTime      # Auto-close time in seconds
│   └── lang               # Interface language (auto, ru, en)
│
├── serverPresets          # Server settings presets
│   ├── release            # Release version preset example
│   │   ├── gamePath       # Game path
│   │   ├── serverPath     # Server path
│   │   ├── profilePath    # Profiles path
│   │   ├── missionPath    # Mission path
│   │   ├── serverPort     # Server port
│   │   ├── serverConfig   # Server config name
│   │   ├── isDiagMode     # Diagnostic mode
│   │   ├── isDisableBE    # No BattlEye mode (see below)
│   │   ├── isExperimental # Experimental version
│   │   ├── isFilePatching # FilePatching mode
│   │   ├── cleanLogs      # Log cleanup mode
│   │   └── workshop       # Mod paths
│   │       ├── steam      # Steam Workshop path
│   │       └── local      # Local mods path
│   │
│   └── experimental       # Experimental version preset example
│       └── ...            # Same parameters
│
└── modsPresets            # Mod set presets
    ├── vanilla            # No mods preset example
    │   ├── client         # Client mod list
    │   └── server         # Server mod list
    │
    └── modded             # Modded preset example
        ├── client         # Client mods
        └── server         # Server mods
```

#### Parameter Description

**active**

- `serverPreset`: preset name from serverPresets
- `modPreset`: preset name from modsPresets
- `autoCloseTime`: time until console closes (0 - close without delay)
- `lang`: interface language (auto, ru, en)

**serverPresets**

- `gamePath`: absolute path to game folder
- `serverPath`: absolute path to server folder
- `profilePath`: absolute path to profiles folder
- `missionPath`: absolute path to mission folder (for DayzDiag launch)
- `serverPort`: server port
- `serverConfig`: server configuration file name
- `isDiagMode`: enable diagnostic mode
- `isExperimental`: use experimental version
- `isFilePatching`: enable FilePatching mode
- `cleanLogs`: log cleanup mode (all, server, client, none)
- `workshop`: mod paths
    - `steam`: absolute path to Steam Workshop folder
    - `local`: absolute path to local mods folder

**modsPresets**

- `client`: mod list for client
- `server`: mod list for server

**Mod Path Prefixes**

- `$steam/` = path relative to `workshop.steam`
- `$local/` = path relative to `workshop.local`
- no prefix = path will be used as is

**Mod Path Transformation Examples**

```
"$steam/@CF" -> "e:/SteamLibrary/steamapps/common/DayZ/!Workshop/@CF"
"$local/@MyMod" -> "e:/DayZMods/@MyMod"
"e:/Mods/CustomMod" -> "e:/Mods/CustomMod"
"ServerCustomMod" -> "ServerCustomMod"
```

### Script Launch Options

1. First launch (`.\start.ps1`)
    - Search for installed game
    - Create configuration
    - Create shortcuts
    - Display instructions

2. Simple launch (`.\start.ps1`)
    - Stop server and client
    - Clear server and client logs
    - Launch server and then client

3. Server only launch (`.\start.ps1 server`)
    - Stop server
    - Clear server logs only
    - Launch server only

4. Client only launch (`.\start.ps1 client`)
    - Stop client
    - Clear client logs only
    - Launch client only

## No BattlEye Mode (isDisableBE)

When the `isDisableBE` parameter is enabled, launch will occur for:

- server from `DayZServer_x64_NoBe.exe` file instead of `DayZServer_x64.exe`.
- client from `DayZ_x64.exe` file instead of  `DayZ_BE.exe`.

This way the BattlEye service will not be involved and server and client will start much faster.

With very frequent server/client restarts, which happens almost always when debugging mods, BattlEye starts causing problems, including acting up and checking for updates. The update itself can take quite a long time and cannot be skipped. This causes a lot of inconvenience.

To solve this problem, it's enough to use a patcher for the server executable file.

It's important to understand that this patcher removes the BattlEye service from the server and using such a server as the main one where people will play would violate game distribution rules and be completely unsafe since cheaters will come and nothing can be done about it. Use this patcher at your own risk.

### Instructions for launching without BattlEye:

- Download patcher https://github.com/JonathanEke/DayZ-Server-Battleye-Remover
- Copy and rename `DayZServer_x64.exe` file to `DayZServer_x64_NoBe.exe`
- Drag `DayZServer_x64_NoBe.exe` onto the patcher executable.
- Set `isDisableBE` parameter to `true`

## Read to the end? Well done! 🎉

If you made it to the end of the instructions, it means that for you, like for me, instructions are not just empty words and you know how much effort is usually put into this.

If this script saved you some amount of resources (time/money/nerves) and you would like to thank the author, go here: https://boosty.to/pafnuty/donate
