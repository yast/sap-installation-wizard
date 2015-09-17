# encoding: utf-8

module Yast
  class InstSapClient < Client
    def main

      # MAIN

      textdomain "autoinst"

      @xinitrc = ""

      # Check if we have to start at the end of the installation
      if ! File.exists?("/root/start_sap_wizard")
	 return :next
      end
      start = IO.read("/root/start_sap_wizard")
      start.strip!
      File.delete("/root/start_sap_wizard")
      case start
      when "false"
        return :next
      when "true"
	@xinitrc ="#!/bin/bash
yast2 sap-installation-wizard &
sed -i 's/^DISPLAYMANAGER_AUTOLOGIN.*/DISPLAYMANAGER_AUTOLOGIN=\"\"/' /etc/sysconfig/displaymanager
rm /root/.xinitrc
/etc/X11/xinit/xinitrc"
      when "hana_part"
	@xinitrc ="#!/bin/bash
yast2 sap-installation-wizard hana_partitioning&
sed -i 's/^DISPLAYMANAGER_AUTOLOGIN.*/DISPLAYMANAGER_AUTOLOGIN=\"\"/' /etc/sysconfig/displaymanager
rm /root/.xinitrc
/etc/X11/xinit/xinitrc"
      end
      
      IO.write("/root/.xinitrc",@xinitrc) 
      SCR.Write(path(".sysconfig.displaymanager.DISPLAYMANAGER_AUTOLOGIN"), "root")
      SCR.Write(path(".sysconfig.displaymanager"), nil)

      :next
    end
  end
end

Yast::InstSapClient.new.main
