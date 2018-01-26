#!/bin/bash

if [ -e /usr/bin/xdg-desktop-icon -a ! -e $HOME/.sap-icons ]; then 
	gsettings set org.gnome.desktop.background show-desktop-icons true
	xdg-desktop-icon install /usr/share/applications/YaST2/sap-windows_cheat_sheet.desktop
	xdg-desktop-icon install /usr/share/applications/YaST2/sap-installation-wizard.desktop
	xdg-desktop-icon install --novendor /usr/share/applications/YaST2/customer_center.desktop
	xdg-desktop-icon install --novendor /usr/share/applications/YaST2/suse-connect-program.desktop
	gsettings set org.gnome.desktop.background show-desktop-icons true
	chmod 755 $HOME/Desktop/*
	touch $HOME/.sap-icons
fi
