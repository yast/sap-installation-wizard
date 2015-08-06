# encoding: utf-8

module Yast
  class InstSapClient < Client
    def main
      Yast.import "UI"
      Yast.import "IP"
      Yast.import "Wizard"
      Yast.import "Package"
      Yast.import "Stage"
      Yast.import "Popup"
      Yast.import "SAPInst"

      # MAIN

      textdomain "autoinst"

      @contents = nil
      @help_text = ""

      # Check if we have to start at the end of the installation
      if File.exists?("/root/start_sap_wizard")
         start = IO.read("/root/start_sap_wizard")
         File.delete("/root/start_sap_wizard")
	 if start == "false"
	   return :next
	 end
      end

      # We have to restart network in 2. stage and set gnome as default WM and DM
      if Stage.cont
        SCR.Execute(path(".target.bash"), "/etc/init.d/network restart")
        SCR.Write(path(".sysconfig.windowmanager.DEFAULT_WM"), "gnome")
        SCR.Write(path(".sysconfig.displaymanager.DISPLAYMANAGER"), "gdm")
        SCR.Write(path(".sysconfig.windowmanager"), nil)
        SCR.Write(path(".sysconfig.displaymanager"), nil)
      end

      # Check if hostname -f is set
      @out = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "hostname -f")
      )
      @hostname = Ops.get_string(@out, "stdout", "")
      if @hostname == ""
        @out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            "ip addr show eth0 | gawk '/inet / { print $2 }' | gawk -F/ '{ print $1 }'"
          )
        )
        @valid_domain_chars = ".0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-"
        @valid_ip_chars = ".0123456789"
        @fqhn = Convert.to_string(
          SCR.Read(path(".target.string"), "/etc/HOSTNAME")
        )
        @ip = Ops.get_string(@out, "stdout", "")
        @fqhn = Builtins.filterchars(@fqhn, @valid_domain_chars)
        @ip = Builtins.filterchars(@ip, @valid_ip_chars)
        Builtins.y2milestone("fqhn %1 ip %2 test", @fqhn, @ip)
        @help_text = _(
          "<p>The fully qualified hostname (FQHN) could not be dectected.</p>"
        ) +
          _(
            "<p>Please check the proposed values and correct these if necessary!</p>"
          )
        @contents = VBox(
          TextEntry(Id(:fqhn), "Proposed FQHN", @fqhn),
          TextEntry(Id(:ip), "Proposed IP-Address", @ip)
        )
        Wizard.SetContents(
          _("Error by detecting the fully qualified hostname (FQHN)"),
          @contents,
          @help_text,
          false,
          true
        )
        UI.ChangeWidget(Id(:fqhn), :ValidChars, @valid_domain_chars)
        UI.ChangeWidget(Id(:ip), :ValidChars, @valid_ip_chars)
        while true
          @button = UI.UserInput
          @fqhn = Convert.to_string(UI.QueryWidget(Id(:fqhn), :Value))
          @ip = Convert.to_string(UI.QueryWidget(Id(:ip), :Value))
          if @button == :abort
            return :abort if Popup.ReallyAbort(false)
            next
          end
          @lfqhn = Builtins.splitstring(@fqhn, ".")
          if Ops.less_or_equal(Builtins.size(@fqhn), 1)
            Popup.Error(_("The hostname is incorrect"))
            UI.SetFocus(Id(:fqhn))
            next
          end
          if !IP.Check4(@ip)
            Popup.Error(_("The IP address is incorrect"))
            UI.SetFocus(Id(:ip))
            next
          end
          SCR.Execute(
            path(".target.bash"),
            "echo " + @ip + " " + @fqhn + " " + Ops.get_string(@lfqhn, 0, "") + ">> /etc/hosts"
          )
          SCR.Execute(
            path(".target.bash"),
            "hostname " + Ops.get_string(@lfqhn, 0, "")
          )
          break
        end
      end

      SCR.Execute(path(".target.bash"), "rm -rf /tmp/may_*")
      SCR.Execute(path(".target.bash"), "rm -rf /tmp/ay_*")
      SCR.Execute(path(".target.bash"), "rm -rf /tmp/mnt1")
      SCR.Execute(path(".target.bash"), "rm -rf /tmp/current_media_path")
      SCR.Execute(path(".target.bash"), "rm -rf /dev/shm/InstMaster_SWPM/")
      if Stage.cont
        # for BOne users ask to do partitioning and install
        UI.OpenDialog(
          RadioButtonGroup(
            Id(:rb),
            VBox(
              Heading("SAP product installation"),
              Label(
                "The standard installation of the Operating System has settled." + "\n" +
                  "Would you like to continue with SAP products now?"
              ),
              Left(
                RadioButton(
                  Id("sap_install"),
                  "&Create SAP file systems and start SAP product installation.",
                  true
                )
              ),
              Left(
                RadioButton(
                  Id("hana_partitioning"),
                  "Only create &SAP Business One file systems, do not install SAP products now.",
                  false
                )
              ),
              Left(
                RadioButton(
                  Id("none"),
                  "&Finish wizard and proceed to OS login.",
                  false
                )
              ),
              HBox(PushButton("&OK"))
            )
          )
        )
        UI.UserInput
        @current = Convert.to_string(UI.QueryWidget(Id(:rb), :CurrentButton))
	Builtins.y2milestone("CURRENT %1", @current)
        UI.CloseDialog
        if @current == "none"
          return :next
        elsif @current == "hana_partitioning"
	  Builtins.y2milestone("Starting SAPInst.CreateHANAPartitions")
	  SAPInst.CreateHANAPartitions("")
          return :next
        end
      end
      WFM.CallFunction("sap-installation-wizard", [true, true])
      SCR.Execute(path(".target.bash"), "rm /tmp/may_*")
      SCR.Execute(path(".target.bash"), "rm /tmp/ay_*")
      SCR.Execute(path(".target.bash"), "rm -rf /tmp/mnt1")
      SCR.Execute(path(".target.bash"), "rm -rf /dev/shm/InstMaster_SWPM/")

      :next
    end
  end
end

Yast::InstSapClient.new.main
