#!/bin/bash

if [ ! -e $HOME/.sap-icons ]; then 
	xdg-desktop-icon install /usr/share/applications/YaST2/sap-windows_cheat_sheet.desktop
	xdg-desktop-icon install /usr/share/applications/YaST2/sap-installation-wizard.desktop
	xdg-desktop-icon install --novendor /usr/share/applications/YaST2/customer_center.desktop
	xdg-desktop-icon install --novendor /usr/share/applications/YaST2/suse-connect-program.desktop
	touch $HOME/.sap-icons
fi
