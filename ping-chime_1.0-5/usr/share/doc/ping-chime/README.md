# Ping Chime Service

## Overview

Ping Chime is a utility service designed to help users maintain awareness of their system's network connectivity status. It's particularly useful for systems that are typically air-gapped but occasionally connected to a network.

## Purpose

The primary goal of this service is to:

1. Regularly check the connection status to a specified network host.
2. Provide audible notifications (chimes) based on the connection status.
3. Help users avoid inadvertently leaving a typically air-gapped system connected to a network.

## Key Features

- Configurable ping intervals for network checks
- Distinct audio cues for different connection states (connected, disconnected, transitioning)
- Adjustable notification frequencies and volumes
- Runs as a background service for continuous monitoring

## Preparation

- In etc/systemd/system/ping-chime.service
  - Please replace `<USERNAME>` with your primary username
  - Please replace `<UID>` with your primary user's UID
- In etc/ping-chime/ping-chime.cfg
  - Please replace `<IP_ADDRESS>`  with the IP of machine on the internet (such as a personal VPS)

## Requirements

- A Debian-based operating system with systemd
- Perl interpreter
- PulseAudio sound system
- Network connectivity (for the ping functionality)


## Configuration

The service is highly configurable, allowing users to set:

- Target host for ping checks
- Ping and notification intervals
- Audio output settings
- Sound files for different notification types

Configuration files can be placed in system-wide or user-specific locations for flexibility.

## Usage

Once installed, the service starts automatically and runs in the background. Users will receive audio notifications based on the configured settings and current network status.

The service can be managed using standard systemd commands:

```
sudo systemctl start|stop|restart|status ping-chime
```

## Customization

Users can customize the behavior of Ping Chime by modifying the configuration file. This allows for adjusting the service to fit specific needs or preferences.

## Note

This service is designed with security-conscious users in mind, particularly those who need to ensure their systems are not inadvertently left connected to a network. Always follow your organization's security policies when using network-related tools.

For detailed installation instructions, configuration options, and troubleshooting, please refer to the full documentation included with the package.
