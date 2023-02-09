# Debian-builder
Utility to embed the `preseed.cfg` file into the Debian NetInstall image.

# Overview
RedHat has Kickstart, SuSE has AutoYaST and [Debian](https://wiki.debian.org/AutomatedInstallation) has a `preseed.cfg`
file to automate operating system installations. You can either attach a second drive to your machine while installing
and manually tell the installer where the file is located, or you can burn the `preseed.cfg` file into the ISO image.
(See [here](https://www.debian.org/releases/stable/i386/apb.en.html) and [here](https://wiki.debian.org/DebianInstaller/Preseed#Preseeding_methods).)

All the options are slightly cumbersome. This utility automates the process of embedding your `preseed.cfg` into an ISO image.
You just have to [write your own preseed](https://wiki.debian.org/DebianInstaller/Preseed#Default_preseed_files). And
know how to run Docker...

# How to use
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

# Custom configuration
* If you already have the official ISO downloaded in your folder, it will automatically will be used and it will not be re-downloaded.
In this case it's the user's responsibility to make sure that the ISO is valid.
* You can add `-e VERSION=11.6.0` environment variable to the docker execution to download a different Debian version.
* You can add `-e NAME=custom` environment variable that will be used to name the output image. (Well the last section of it.)
