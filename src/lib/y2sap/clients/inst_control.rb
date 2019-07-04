# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.
require "yast"

module Y2Sap
  module Clients
    # Client to control the SAP installation
    class InstControl
      def main
        include Yast::Logger
        Yast.import "Service"
        Yast.import "SuSEFirewall"
        # MAIN
        textdomain "sap-installation-wizard"
        if File.exist?("/root/inst-sys/start_rdp_service")
          rdp = IO.read("/root/inst-sys/start_rdp_service")
          rdp.strip
          if rdp != "false"
            Service.Enable("xrdp")
            Service.Start("xrdp")
            SuSEFirewall.ReadCurrentConfiguration
            SuSEFirewall.SetServicesForZones(["service:xrdp"], ["INT", "EXT", "DMZ"], true)
            SuSEFirewall.WriteConfiguration
          end
        end
        # Check if we have to start at the end of the installation
        if !File.exist?("/root/inst-sys/start_sap_wizard")
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
end
