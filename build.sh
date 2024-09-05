#!/bin/bash

export DIR=ping-chime_1.0-5
# killall ping_chime.pl
# clean-emacs-backups -r
sudo chown -R root:root $DIR
sudo dpkg-deb --build $DIR
sudo dpkg -i $DIR.deb
sudo systemctl status ping-chime
journalctl -u ping-chime -f
