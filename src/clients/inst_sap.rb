# encoding: utf-8

module Yast
  class InstSapClient < Client
    def main

      # MAIN
      textdomain "autoinst"

      # Check if we have to start at the end of the installation
      if !File.exists?("/root/start_sap_wizard")
	 return :next
      end
      start = IO.read("/root/start_sap_wizard")
      start.strip!
      if start != "false"
         SCR.Execute(path(".target.bash"), "touch /var/lib/YaST2/reconfig_system")
	 SCR.Write(path(".sysconfig.firstboot.FIRSTBOOT_CONTROL_FILE"), "/etc/YaST2/firstboot-sap.xml")
	 SCR.Write(path(".sysconfig.firstboot"), nil)
      end
      :next
    end
  end
end

Yast::InstSapClient.new.main
