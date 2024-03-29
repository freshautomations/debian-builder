# Debian-builder
Utility to embed the `preseed.cfg` file into the Debian NetInstall image.

## Overview
RedHat has Kickstart, SuSE has AutoYaST and [Debian](https://wiki.debian.org/AutomatedInstallation) has a `preseed.cfg`
file to automate operating system installations. You can either attach a second drive to your machine while installing
and manually tell the installer where the file is located, or you can burn the `preseed.cfg` file into the ISO image.
(See [here](https://www.debian.org/releases/stable/i386/apb.en.html) and [here](https://wiki.debian.org/DebianInstaller/Preseed#Preseeding_methods).)

All the options are slightly cumbersome. This utility automates the process of embedding your `preseed.cfg` into an ISO image.
You just have to [write your own preseed](https://wiki.debian.org/DebianInstaller/Preseed#Default_preseed_files). And
know how to run Docker...

## How to use
After [installing Docker](https://docs.docker.com/desktop/) to your favorite operating system and
[creating your preseed](https://wiki.debian.org/DebianInstaller/Preseed#Default_preseed_files) file, you run the following
command in the folder where you put your `preseed.cfg`.
```bash
docker run -it --rm -v $(pwd):/mnt freshautomations/debian-builder
```
The execution will show you Docker downloading the Debian netinstaller, unpacking it, adding your preseed file as well
as making changes to the boot loader so the file is automatically loaded. Then it recompiles the ISO file. At the end
you will see a few new files in your file system:
* debian-11.6.0-amd64-netinst.iso or similar: the downloaded official netinstaller.
* **debian-11.6.0-amd64-custom.iso**: the customized netinstaller ISO that contains and executes the preseed file.

Burn the custom ISO to a CD, DVD or USB stick with your favorite application. My current favorite is [balenaEtcher](https://www.balena.io/etcher)
because it works so well on my macOS.

## Custom configuration
* If you already have the official ISO downloaded in your folder, it will automatically will be used and it will not be re-downloaded.
In this case it's the user's responsibility to make sure that the ISO is valid.
* You can add `-e VERSION=11.6.0` environment variable to the docker execution to download a different Debian version.
* You can add `-e NAME=custom` environment variable that will be used to name the output image. (Well the last section of it.)
* You can add `-e TIMEOUT=5` environment variable that will be used to set the bootloader menu timeout _in seconds_.
* You can add `-e NOMODESET=1` environment variable that will be used to disable graphics card acceleration for the installer. (Unset by default.)

## I don't have Docker
Docker is only used to simplify the environment setup. You can run the embedded script without Docker, if you set up your
own environment. The main components:
* Install [`xorriso`](https://www.gnu.org/software/xorriso/) in your environment. This is used unpack/repack the ISO image.
* Download the Official Debian Netinstall image or have `wget`, `sha512sum` and `gnupg` installed so the script can
download and verify it for you.
* Have a generic set of Linux commands available: `cpio`, `sed`, `md5sum`, `gzip`/`gunzip`, `find`, `dd`.

Additional environment variables are available to configure the script:
* `DEBUG=1` will enable tracing the script line-by-line as well as not removing some temporary files. (Unset by default.)
* `MNT=/mnt` will tell the script where the input files (preseed.cfg and optionally an official ISO image) are located
on the file system
* `MEDIA=/media` will tell the script where to expand the official ISO image.
* `TMP=/tmp` will mount the temporary folder somewhere else.
* `FORCE=1` will force ALL the boot menu items to be automated installations with the `preseed.cfg` set.
If this is not set, only the "Automated ..." items are set and the boot menu defaults to the automated graphical installation. (Unset by default.)
