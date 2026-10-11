## FRITZ!-based Presence Detection for HomeMatic - hm_pdetect

[![Release](https://img.shields.io/github/release/homematic-community/hm_pdetect.svg)](https://github.com/homematic-community/hm_pdetect/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/homematic-community/hm_pdetect/latest/total.svg)](https://github.com/homematic-community/hm_pdetect/releases/latest)
[![Issues](https://img.shields.io/github/issues/homematic-community/hm_pdetect.svg)](https://github.com/homematic-community/hm_pdetect/issues)
[![License](http://img.shields.io/:license-lgpl3-blue.svg?style=flat)](http://www.gnu.org/licenses/lgpl-3.0.html)
[![Donate](https://img.shields.io/badge/donate-PayPal-green.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=RAQSDY9YNZVCL)

This CCU-Addon allows to implement a general home presence detection system within a [eQ3 HomeMatic](http://www.homematic.com/) homeautomation system. It regularly queries the WiFi/LAN status of user devices (e.g. Smartphones) logging in/out of [AVM FRITZ!](http://www.avm.de/) WiFi routers (e.g. FRITZ!Box, FRITZ!Repeater). Upon manually configured MAC and IP addresses of user devices this addon is able to set the general home presence status of that user in terms of setting CCU-based system variables. These variables can then be evaluated within the general HomeMatic home automation system. In addition, any device that is not recognized as a configured user devices or known device will otherwise be considered a guest device and a separate system variable set accordingly. This allows to identify any guests being present at the house so that e.g. the heating system of a guest room could be switched on/off accordingly.

## Features
* Querying of several FRITZ!-devices (FRITZ!Box/Repeater) in one run
* User-definable interval for querying FRITZ!-devices regularly
* Support for manually triggering execution via CUxD SystemExec calls.
* Support for FRITZ!Box/Repeater local network login with and without password
* Possibility to remotely query FRITZ!-devices via https
* Support for querying a dedicated guest-WiFi network
* User device definition based on MAC and/or IP address or the device name known to the FRITZ! device (for phones using changing private MAC addresses)
* Possibility to define multiple devices per user
* Configurable away delay to bridge short WiFi drop-outs of phones
* Monitored devices (e.g. computers) with their own online system variable that do not count as users
* Rules to control CCU devices on presence changes (e.g. heating to 21°C when the office computer is online, at most 18°C when nobody is home) including restoring the previous heating settings
* Web based status overview (presence, rules, heating channels, device list of the FRITZ! devices) and form based rule editor
* Automatically generates all necessary CCU system variables
* Additional String and Enum system variable to easily display the general presence status at home
* Guest detection based on unknown devices being identified in a dedicated Guest-WiFi
* Guest detection can be applied to the whole WiFi/LAN environment
* Web based configuration pages accessible via CCU-WebUI

## Supported CCU models
* [HomeMatic CCU3](https://www.eq-3.de/produkte/homematic/zentralen-und-gateways/smart-home-zentrale-ccu3.html) / [RaspberryMatic](http://raspberrymatic.de/)
* [HomeMatic CCU2](https://www.eq-3.de/produkt-detail-zentralen-und-gateways/items/homematic-zentrale-ccu-2.html)
* HomeMatic CCU1

## Supported FRITZ! models
* All models of FRITZ!Box and FRITZ!Repeater running with FRITZ!OS 6 or newer

## Configuration FRITZ! device
1. Open the web configuration of the individual FRITZ!-device (e.g. http://fritz.box/)
2. Create a new dedicated user via *System->FRITZ!Box-User->Add User*
  * Restrict access rights of user to *FRITZ!Box Settings* only
3. Open the Homenetwork-Login configuration at *System->FRITZ!Box-User->Login to Homenetwork*
  * Modify login setting to *Login with FRITZ!Box-Username and Password*

## Installation as CCU Addon
1. Download of recent Addon-Release from [Github](https://github.com/homematic-community/hm_pdetect/releases)
2. Installation of Addon archive (```hm_pdetect-X.X.tar.gz```) via WebUI interface of CCU device
3. Configuration of FRITZ!Box/Repeater (see next section)
4. Configuration of Addon using the WebUI accessible config pages

## Manual Installation as stand-alone script (e.g. on RaspberryPi)
1. Create a new directory for hm_pdetect:

        mkdir /opt/hm_pdetect

2. Change to new directory: 

        cd /opt/hm_pdetect

3. Download latest hm_pdetect.sh:

        wget https://github.com/homematic-community/hm_pdetect/raw/master/hm_pdetect.sh

4. Download of sample config:

        wget https://github.com/homematic-community/hm_pdetect/raw/master/hm_pdetect.conf.sample

5. Rename sample config to active one:

        mv hm_pdetect.conf.sample hm_pdetect.conf

6. Modify configuration according to comments in config file:

        vim hm_pdetect.conf

7. Execute hm_pdetect manually:

        /opt/hm_pdetect/hm_pdetect.sh

8. If you want to automatically start hm_pdetect on system startup a startup script

## Devices and rules
Besides users, hm_pdetect can monitor further devices and run actions on the CCU whenever the presence situation changes. Devices and rules are stored in a separate file `hm_pdetect-rules.conf` next to `hm_pdetect.conf` (see [hm_pdetect-rules.conf.sample](hm_pdetect-rules.conf.sample)). On a CCU they are edited on the addon settings page in the section *Devices & rules*, either with the form based editor or in a text view. The file is re-read in every run, so changes take effect without a restart.

A rule consists of a condition and the actions to run when the condition becomes true (enter) and when it becomes false again (leave):

        [OfficePC_on]='device:OfficePC|temp:room:Office=21|restore'
        [Nobody_home]='nobody|maxtemp:ALL=18|restore'

* Conditions: `device:<Name>`, `user:<Name>`, `anyone`, `nobody`; combine with `&`, negate with `!`
* Actions: `temp:<target>=<°C>`, `maxtemp:<target>=<°C>`, `auto:<target>`, `restore`, `set:<datapoint>=<value>`, `var:<sysvar>=<value>`, `prog:<program>`; separate several with `;`
* Heating targets: `ALL`, `room:<room name>` or comma separated channel names/addresses

Actions only run when a condition changes, so manual changes at a thermostat are kept until the next change. `temp` and `maxtemp` save the previous heating settings, which `restore` sets again. The rule state is kept in `hm_pdetect-rules.state` so that it survives restarts; on the first evaluation of a new rule only its state is recorded. Set `HM_RULES_DRYRUN=true` to only log the actions.

## Using 'system.Exec()'
Instead of automatically calling hm_pdetect on a predefined interval one can also trigger its execution using the `system.Exec()` command within HomeMatic scripts on the CCU following the following syntax:

        system.Exec("/usr/local/addons/hm_pdetect/run.sh <iterations> <waittime> &");
 
Please note the &lt;iterations&gt; and &lt;waittime&gt; which allows to additionally specify how many times hm_pdetect should be executed with a certain amount of wait time in between. One example of such an execution can be:

        system.Exec("/usr/local/addons/hm_pdetect/run.sh 5 2 &");

This will execute hm_pdetect for a total amount of 5 times with a waittime of 2 seconds between each execution.

## Support
In case of problems/bugs or if you have any feature requests please feel free to open a [new ticket](https://github.com/homematic-community/hm_pdetect/issues) at the Github project pages. To seek for help for configuring/using this Addon please use the following german language based fora thread: [hm_pdetect](http://homematic-forum.de/forum/viewtopic.php?f=18&t=23907).

## License
The use and development of this addon is based on version 3 of the LGPL open source license.

## Authors
Copyright (c) 2015-2023 Jens Maus &lt;mail@jens-maus.de&gt;

## Notice
This Addon uses KnowHow that was developed throughout the following projects:
* https://github.com/jollyjinx/homematic
* https://github.com/max2play/webinterface
