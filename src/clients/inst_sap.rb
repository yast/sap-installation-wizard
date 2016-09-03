# encoding: utf-8

module Yast
  class InstSapClient < Client
    def main
      Yast.import "Service"
      Yast.import "SuSEFirewall"

      # MAIN
      textdomain "autoinst"
      if File.exists?("/root/inst-sys/start_rdp_service")
         rdp = IO.read("/root/inst-sys/start_rdp_service")
	 rdp.strip
	 if rdp != "false"
	    Service.Enable("xrdp")
	    SuSEFirewall.ReadCurrentConfiguration
	    SuSEFirewall.SetServicesForZones(["service:xrdp"], ["INT", "EXT", "DMZ"], true)
	 end
      end
      # Check if we have to start at the end of the installation
      if !File.exists?("/root/inst-sys/start_sap_wizard")
	 return :next
      end
      start = IO.read("/root/inst-sys/start_sap_wizard")
      start.strip!
      if start != "false"
         SCR.Execute(path(".target.bash"), "touch /var/lib/YaST2/reconfig_system")
	 SCR.Write(path(".sysconfig.firstboot.FIRSTBOOT_CONTROL_FILE"), "/etc/YaST2/firstboot-sap.xml")
	 SCR.Write(path(".sysconfig.firstboot.LICENSE_REFUSAL_ACTION"), "continue")
	 SCR.Write(path(".sysconfig.firstboot"), nil)
      end
      :next
    end
  end
end

Yast::InstSapClient.new.main
