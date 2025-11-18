<h1 align="center">
  <img src="assets/logo.png"/>
  <p align="center">Atomic Framework</p>

  <img src="https://img.shields.io/github/release/TeamMeadows/atomic-framework.svg">
  <img src="https://img.shields.io/github/issues/TeamMeadows/atomic-framework.svg">
  <img src="https://img.shields.io/github/license/TeamMeadows/atomic-framework.svg">
</h1>

Atomic is a flexible, OOP-driven framework for building Garry’s Mod addons and gamemodes with a clean, modular architecture.
Each **package** is a self-contained unit — just like an addon — with built-in dependency management and powerful libraries for writing structured, maintainable Lua code.

---

## Features
- Modular **package-based** architecture
- Built-in **dependency managment**
- Built-in configuration system with in-database saving
- Flexible **OOP** utilities and core libraries
- Expandable with **atomic.\*** libraries (i18n, command, network, etc.)
- Designed for both **addons** and **gamemodes**

## Examples
You can quickly view [examples](./examples/README.md) of packages (addons) made on Atomic Framework to understand how it works.

---

## Documentation
Full documentation, API references, and examples are available here:
👉 **[Atomic Framework Wiki](https://github.com/TeamMeadows/atomic-framework/wiki)**

---

## Installation
Simply place the framework in your `addons/` folder.
Atomic will automatically load available packages.

Optional dependencies:
- For `atomic.mysql` → install [MySQLOO](https://github.com/FredyH/MySQLOO)
- For `atomic.git` → install [gm_git](https://github.com/TeamMeadows/gm_git)

---

## Contributing
We welcome all contributions — bug fixes, improvements, and new libraries are appreciated.
Please follow the [project’s coding style](./CODE_STYLE.md) and submit a pull request through GitHub.
Discussions and proposals are also encouraged in the issue tracker.

---

## License
This project is licensed under the **GNU General Public License v3.0**.
See the [LICENSE](./LICENSE) file for more details.

<!-- "atomic powered" usage -->
<!-- <a href="https://github.com/TeamMeadows/atomic-framework"><img src="assets/powered.png"></a> -->