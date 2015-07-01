# encoding: utf-8

module Yast
  class FirstbootInstSapClient < Client
    def main
      Yast.import "UI"
      Yast.import "Wizard"
      Yast.import "Package"
      Yast.import "Popup"

      textdomain "firstboot"

      @contents = nil

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
                "&Create SAP file systems and start SAP product installation",
                true
              )
            ),
            Left(
              RadioButton(
                Id("hana_partitioning"),
                "Only create &SAP HANA + B1 file systems, do not install SAP products now",
                false
              )
            ),
            Left(
              RadioButton(
                Id("none"),
                "&Finish wizard and proceed to OS login",
                false
              )
            ),
            HBox(PushButton("&OK"))
          )
        )
      )
      UI.UserInput
      @current = Convert.to_string(UI.QueryWidget(Id(:rb), :CurrentButton))
      UI.CloseDialog
      @info = ""
      if @current == "none"
        return :next
      elsif @current == "sap_install"
        # call the wizard
        WFM.CallFunction("sap-installation-wizard", [true, true])

        # remove some temporary stuff after we finish the wizard
        SCR.Execute(path(".target.bash"), "rm /tmp/may_*")
        SCR.Execute(path(".target.bash"), "rm /tmp/ay_*")
        SCR.Execute(path(".target.bash"), "rm -rf /tmp/mnt1")
        SCR.Execute(path(".target.bash"), "rm -rf /dev/shm/InstMaster_SWPM/")
        return :next
      else
        WFM.CallFunction("sap-installation-wizard", [@current])
        return :next
      end
    end
  end
end

Yast::FirstbootInstSapClient.new.main
