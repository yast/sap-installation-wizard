# encoding: utf-8

module Yast
  class FirstbootInstSapClient < Client
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

      @contents  = nil
      @help_text = ""
      @closeMe   = false

      if !Wizard.IsWizardDialog
         Wizard.CreateDialog
         @closeMe = true
      end

      # Check if hostname -f is set
      @out = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "hostname -f")
      )
      @hostname = Ops.get_string(@out, "stdout", "")
      if @hostname == ""
        if( Popup.AnyQuestion(_("The fully qualified hostname (FQHN) could not be detected."),
                              _("Do you want to return to network setup or break the SAP product installation and start the installed system?"),
                              _("Return to Network Setup"),
                              _("Abort"),
                              :focus_yes
                              ))
            return :back
         else
            return :next
         end
      end
      @caption = _("Product Installation Mode")
      @help    = _("The standard installation of the Operating System has settled.") + "<br>" +
                 _("Now you can start the SAP Product Installation")
      @content = RadioButtonGroup(
            Id(:rb),
            VBox(
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
                  "Only create &SAP HANA file systems, do not install SAP products now.",
                  false
                )
              ),
              Left(
                RadioButton(
                  Id("none"),
                  "&Finish wizard and proceed to OS login.",
                  false
                )
              )
            )
          )
      Wizard.SetDesktopIcon("sap-installation-wizard")
      Wizard.SetContents(
        @caption,
        @content,
        @help,
        true,
        true
      )

      ret = nil
      begin
        ret = Wizard.UserInput
        Builtins.y2milestone("ret %1",ret)
        case ret
        when :abort
          break if Popup.ConfirmAbort(:incomplete)
        when :help
          Wizard.ShowHelp(@help)
        when :next
          install   = Convert.to_string(UI.QueryWidget(Id(:rb), :CurrentButton))
          case install
          when "sap_install"
              WFM.CallFunction("sap-installation-wizard", [])
	      ret = :next
          when "hana_partitioning"
              SAPInst.CreateHANAPartitions("")
	      ret = :next
          end
          SCR.Execute(path(".target.bash"), "rm -rf /tmp/may_*")
          SCR.Execute(path(".target.bash"), "rm -rf /tmp/ay_*")
          SCR.Execute(path(".target.bash"), "rm -rf /tmp/mnt1")
          SCR.Execute(path(".target.bash"), "rm -rf /tmp/current_media_path")
          SCR.Execute(path(".target.bash"), "rm -rf /dev/shm/InstMaster_SWPM/")
        end
      end until ret == :next || ret == :back
      Wizard.CloseDialog() if @closeMe
      return ret
    end
  end
end

Yast::FirstbootInstSapClient.new.main
