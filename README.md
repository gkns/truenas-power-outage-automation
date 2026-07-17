# TrueNAS Power Outage & Recovery Automation

This repository contains an event-driven monitoring setup that bridges a "dumb" UPS to a TrueNAS SCALE server using Home Assistant and a PiKVM (This pikvm is connected to control the very same TrueNAS server).

It utilizes network presence detection as a proxy for utility power status to cleanly manage the TrueNAS lifecycle (shutdown and automated wake) without modifying the core TrueNAS OS.

## Architecture

**NOTE**: Both the TrueNAS and pikvm are connected to the same dumb UPS (that lasts approximately 15 minutes.) And the two routers that are monitored are directly connected to wall power. The main router and switch which handles network connectivity, DHCP, DNS etc. are connected to a DC-UPS which lasts much longer (~3 hours). Additionally the whole setup is covered by a larger home inverter UPS. So this system will likely kick-in only if the outage lasts longer than 3-4 hours. This automation is tested by manually disconnecting power to the routers that are monitored.



1. **Shutdown (Home Assistant):** Monitors two wall-connected routers (Archer AX10) via ICMP. If both routers drop offline for 2 minutes, Home asisstant confirms a grid power failure, dispatches an email alert, and initiates a graceful shutdown of the TrueNAS host via an SSH tunnel and `midclt`. (The new websocket APIs for TrueNAS are cumbersome for home-asistant, hence the `midclt`)

2. **Wake (PiKVM):** Runs a persistent systemd watchdog daemon. Once utility power is restored (either router coming online is sufficient) while TrueNAS is safely powered off, the PiKVM waits for 1 hour of continuous stable grid-power (to recharge the UPS and avoid power fluctuations) before broadcasting a Wake-on-LAN (WOL) packet to boot the storage array.



## Repository Structure

```sh
.
├── config
│   ├── home-assistant-configuration.yaml
│   └── truenas_emergency_shutdown_midclt.sh
├── etc
│   └── systemd
│       └── system
│           └── truenas-watchdog.service
├── home-assistant-power-outage-monitor.yaml
└── usr
    └── local
        └── bin
            └── truenas_watchdog.sh
```

## 1. Home Assistant Setup (Shutdown Phase)

- **SSH Key Requirement:** Generate an RSA key inside the Home Assistant container at `/config/truenas_rsa` and add the public key to the `user` desginated for this  on the TrueNAS (here it is `gkns`).

- **Shell Script:** Place `config/truenas_emergency_shutdown_midclt.sh` in your HA config directory and ensure it is executable. This script calls the TrueNAS `midclt` API/cli-tool over SSH to dispatch a mail alert, delays for 10 seconds to flush the SMTP queue, and triggers `system.shutdown`.

- **Configuration:** Append `config/home-assistant-configuration.yaml` to your HA `configuration.yaml` to register the `truenas_emergency_shutdown` shell command. Remember to restart the home-assistant container for this new shell command to be visible to the main app.

- **Automation:** Import `home-assistant-power-outage-monitor.yaml` into Home Assistant (. This template-based automation triggers the shell command and a local notification if both dummy sensors stay `off` for 2 minutes (dummy in the sense that these are not actual sensors, but just monitoring the ping-ability of both routers being monitored).



## 2. PiKVM Setup (Recovery Phase)

Ensure the PiKVM filesystem is in read-write mode (`rw`) before applying these files, and switch back to read-only (`ro`) afterward.

- **Watchdog Script:** Place `usr/local/bin/truenas_watchdog.sh` in the correct directory and make it executable (`chmod +x`).

- **Systemd Daemon:** Place `etc/systemd/system/truenas-watchdog.service` in the systemd directory.

- **Enable Service:**

```sh
rw # If not done already, to switch the pikvm temporarily to read-write mode.
systemctl daemon-reload
systemctl enable truenas-watchdog.service
systemctl start truenas-watchdog.service
ro # To switch back the pikvm to read-only default mode
```

The service is configured to start after the network target and will automatically restart if the daemon fails.
