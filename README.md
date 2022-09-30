<h1 align="center">Eyrie</h1>
<h3 align="center">[ˈɪəri, ˈʌɪri, ˈɛːri]</h3>
<p align="center">Module manager for Pterodactyl addons and themes</p>

---
Eyrie is a command line tool designed for managing addons and themes (modules) for the [Pterodactyl Game Panel](https://pterodactyl.io), using a familiar module file system for ease of management and flexible configuration.

## Installation
Currently unavailable unless building from source.

### From Source
```sh
git clone https://github.com/PteroPackages/Eyrie.git
make
make setup
```

## Setting Up
Once you have installed Eyrie, run the `eyrie setup` command (may require administrative permissions), this will create the necessary directories and lockfile for your modules.

## Usage
This section will cover the usage and processes of commands.

### Init
This initializes a new module file in your curent directory. By default, this command is interactive, but you can skip this by including the `-s` or `--skip` flag. <!-- module-file-doc ref -->

### Install
The Pterodactyl and [Jexactyl](https://jexactyl.com) panel locations are supported by default, but custom panel locations can be specified using the `-r` or `--root` flag. This currently supports installing from local module files/sources and the following external sources: Git (self-hosted sources), Github, Gitlab. The source files are first downloaded and cached so that module validation can take place. Afterwards, the source files will be moved to the respective locations in the panel source, and the module dependencies will be installed and/or removed.<!-- TODO: module-file-doc: depdendencies -->

### List
Lists the modules installed on the system. This can also show details about a specific module using the `-n` or `--name` flag.

### Setup
Creates the necessary directories and lockfile for Eyrie to operate. These files/directories should not be accessed or modified directly by the user.

### Uninstall
Uninstalls a specified module from the system, including removing the files added by the module. This does **not** restore the previous files so you should run the panel's upgrade command to restore them.

### Upgrade
Upgrades a package, or all installed ones if not specified, on the system by checking for upgrades (similar to the [install](#install) command).

## Contributing
1. Fork it (<https://github.com/PteroPackages/Eyrie/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors
- [devnote-dev](https://github.com/devnote-dev) - creator and maintainer

This repository is managed under the MIT license.

© 2022 PteroPackages
