
# Dungeons-of-Lua

2D Adventure GAME


# Screenshots

![image](screenshots/Screenshot%20From%202026-10-25%2021-04-39.png)

![image](screenshots/Screenshot%20From%202026-10-25%2021-05-15.png)


## Getting Started

These instructions will give you a copy of the project up and running on
your local machine for development and testing purposes. See deployment
for notes on deploying the project on a live system.

### Prerequisites

Requirements for the software and other tools to build, test and push 
- Lua
- Code editor

### Navigation

- main.lua <- contains all the stuff
- libraries DIR <- contains 3rd party libraries used for the game
- assets DIR <- assets used in the game
- src DIR <- contains other files and environments

- TODO: publish v0.0.1

## License

This project is licensed under the [CC0 1.0 Universal](LICENSE)
Creative Commons License - see the [LICENSE](LICENSE) file for
details


## Running

Requires [LÖVE 11.5](https://love2d.org/):

```
love .
```

## Playing in the browser

The repo ships with a prebuilt browser version in `web/` — the same game compiled
to WebAssembly with [love.js](https://github.com/Davidobot/love.js) (LÖVE 11.5,
compatibility build).

### Play locally

Serve the folder over HTTP (WebAssembly doesn't run from `file://` URLs):

```
python3 -m http.server 8000 -d web
# open http://localhost:8000
```

### Upload online

Deploy the **contents of `web/`** (index.html, game.data, game.js, love.js,
love.wasm) as plain static files — any of these work:

1. **[itch.io](https://itch.io/)** *(recommended — easiest)*
   - Zip the contents of `web/` (index.html must be at the zip root, not inside a folder).
   - Upload as a new project with kind of project = "HTML", tick
     "This file will be played in the browser", set viewport to ~800×600.
2. **GitHub Pages** — commit `web/` and publish it as a Pages site (or point
   Pages at the `web` folder). No special headers needed with the compatibility build.
3. **Netlify / Cloudflare Pages / Vercel** — drag-and-drop or point at `web/`.

### Rebuilding (after changing game code)

```
./build-web.sh
```

Re-zips the game and recompiles `web/` without touching your custom
`web/index.html` theme. Requirements: `zip`, `npm` (love.js is fetched via npx).

### Notes for the web build

- Uses the **compatibility** (single-threaded) build: works on every host and
  browser without requiring `SharedArrayBuffer`/cross-origin-isolation headers.
  (The threaded "regular" build has slightly better audio, but only works on
  hosts that send `Cross-Origin-Opener-Policy: same-origin` +
  `Cross-Origin-Embedder-Policy: require-corp` headers.)
- Keybindings/settings persist in the browser via IndexedDB (love.filesystem).

