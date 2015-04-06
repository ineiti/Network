= Network

This is a collection of modules and classes that allow to do some work with
regard to internet-connections. It's main possibilities include:

- captive interface
- monitoring traffic
- handling internet-devices (usb-modems, ethernet cards)
- operator-specific handling of usb-modems

The device-handling is very ArchLinux-specific and allows for hot-plugging of
usb-modems. The operators supported so far are all Chad-specific, but others
can be added easily.

== Installation

In order for hot-plugging to work, a udev-rule and a ruby-script need to
be installed:

```
require 'network/device'

Network::Device.install_system
```

Or simply run the ```bin/install.rb``` script.

== Devices

The following devices are supported so far:

- Ethernet connections
- Wireless connections
- PPP connections
- HiLink modems (limited because no USSD-support)
- Serial modems

To initialize the devices, you can call simply:

```
require 'network'

Network::Device.start
```

== Operators

Only Chadian operators so far are supported. They are found in the _operators_ directory.
Every operator has the possibility to implement the following functions:

- credit: get, charge
- internet: get, charge

Have a look at the available operators:

- Airtel
- Tigo
- Tawali
- Direct (for ethernet-connections)

== Monitor

The available monitors are:

- traffic - uses rrdtool to generate traffic usage according to networks (hosts, vlans)
- ping - checks if a group of hosts is up or down
- connection - make sure the connection is active by checking a number of states

== Other

Some other modules are also available:

- firewall - implements a speed-limiting set of tc-rules
- mobilecontrol - handles connections and implements a simple interface for SMS-commands