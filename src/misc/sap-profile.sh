
if [ -e /usr/bin/xdg-desktop-icon -a ! -e $HOME/.sap-icons ]; then 
	#gsettings set org.gnome.desktop.background show-desktop-icons true
	xdg-desktop-icon install /usr/share/applications/sap-windows_cheat_sheet.desktop
	xdg-desktop-icon install /usr/share/applications/YaST2/sap-installation-wizard.desktop
	xdg-desktop-icon install --novendor /usr/share/applications/YaST2/customer_center.desktop
	xdg-desktop-icon install --novendor /usr/share/applications/YaST2/suse-connect-program.desktop
	#chmod 755 /root/Desktop/*
	#echo "Trusted=true" >> /root/Desktop/customer_center.desktop
	#gsettings set org.gnome.desktop.background show-desktop-icons true
	touch $HOME/.sap-icons
fi
