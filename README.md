<div align="center">
  <img src="assets/logo.png"/>
  <h1 align="center">Atomic Framework</h1>

  <img src="https://img.shields.io/github/actions/workflow/status/TeamMeadows/atomic-framework/build.yml">
  <img src="https://img.shields.io/github/release/TeamMeadows/atomic-framework.svg">
  <img src="https://img.shields.io/github/issues/TeamMeadows/atomic-framework.svg">
  <img src="https://img.shields.io/github/license/TeamMeadows/atomic-framework.svg">

  [<kbd> <br> Download <br> </kbd>][Download] | [<kbd> <br> Getting Started <br> </kbd>][Getting Started] | [<kbd> <br> Documentation (DeepWiki) <br> </kbd>][Documentation]
</div>

[Download]: https://github.com/TeamMeadows/atomic-framework/releases/latest
[Getting Started]: https://deepwiki.com/TeamMeadows/atomic-framework/1.2-quick-start-guide
[Documentation]: https://deepwiki.com/TeamMeadows/atomic-framework/

## About
The Atomic Framework is a framework for Garry's Mod that manages the loading and lifecycle of your addons.

Instead of working with traditional addons, Atomic uses the concept of a package.\
A package is a logical unit that may depend on other packages.

### Dependency Management
During development, you can specify which packages your project needs.\
Atomic automatically determines the loading order and ensures that all dependencies are fully ready for use before your code runs.

This eliminates the need to write additional checks, timers, or hooks to wait for third-party libraries and other addons to load.

### Other features
Atomic Framework includes built-in APIs for:
- Configuration
- Networking
- Localization (i18n)
- Webview (DHTML based UI)
- Commands

```lua
local package = current()

package:listen(function(self, player)
  self.logger:info("%s has been dead :(", player)
end, "PlayerDeath")
```
###### Example of addon based on Atomic

Also see the [other examples](./examples/lua/atomic/packages)

---

## Installation
1. Download [the latest release of Atomic Framework](https://github.com/TeamMeadows/atomic-framework/releases/latest), and extract it to the `garrysmod/lua/menu` folder.\
2. Add this to `main.lua`
```lua
include("autorun_atomicmenu.lua")
```

## Ecosystem
Our ecosystem already includes awesome packages such as:
- [MeadowsORM](https://github.com/TeamMeadows/orm) - [Prisma](https://prisma.io)-like [ORM](https://en.wikipedia.org/wiki/Object%E2%80%93relational_mapping)
- [MeadowsUI](https://github.com/TeamMeadows/ui) - UI library
- [Zen](https://github.com/TeamMeadows/zen) - Administration system
- [CameraAPI](https://github.com/TeamMeadows/camera-api) - Shared interface for player view managment
- [Meadows Bundler](https://github.com/TeamMeadows/bundler) - GitHub Action for automatically minifying addons and packages
- [RNDX for Atomic](https://github.com/TeamMeadows/rndx-atomic) - Port of [RNDX](https://github.com/Srlion/RNDX) for Atomic Framework
---

## Contributing
We welcome all contributions - bug fixes, improvements, and new libraries are appreciated.
Please follow the [project’s coding style](./CODE_STYLE.md) and submit a pull request through GitHub.