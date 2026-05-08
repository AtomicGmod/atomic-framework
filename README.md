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

Atomic is a flexible, OOP-driven framework for building Garry’s Mod addons and gamemodes with a clean, modular architecture.
Each **package** is a self-contained unit - just like an addon - with built-in dependency management and powerful libraries for writing structured, maintainable Lua code.

```lua
local package = current()
local libui = package:getDependency("com.developername.libui")

package:listen(function(self)
  libui:drawText(self:getPhrase("en", "hello_world"), libui.textSize.small, ScrW() / 2, ScrH() / 2, libui.color.white, libui.position.center)
end, "HUDPaint")

package:listen(function(self)
  self.logger:info("package successfully enabled")
end, "onEnable")
```
###### Example of addon based on Atomic

---

## Installation
Simply place the framework in your `addons/` folder.
Atomic will automatically load available packages.

Optional dependencies:
- `MySQL` support / [MySQLOO](https://github.com/FredyH/MySQLOO)
- `git` support / [gm_git](https://github.com/TeamMeadows/gm_git)

---

## Contributing
We welcome all contributions — bug fixes, improvements, and new libraries are appreciated.
Please follow the [project’s coding style](./CODE_STYLE.md) and submit a pull request through GitHub.