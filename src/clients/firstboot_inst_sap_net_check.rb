module Yast
  # Check if the hostname was set for the server
  class FirstbootInstSapNetCheckClient < Client
    def main
      Yast.import "UI"
      Yast.import "Wizard"
      Yast.import "Popup"
      Yast.import "Service"

      # MAIN
      textdomain "sap-installation-wizard"

      @contents  = nil
      @help_text = ""
      @close_me  = false

      if !Wizard.IsWizardDialog
        Wizard.CreateDialog
        @close_me = true
      end

      # Check if hostname -f is set
      @out = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "hostname -f")
      )
      @hostname = Ops.get_string(@out, "stdout", "")
      if @hostname == ""
        if Popup.AnyQuestion(
          _("The fully qualified hostname (FQHN) could not be detected."),
          _("Do you want to return to network setup or abort the SAP product installation and start the installed system?"),
          _("Return to Network Setup"),
          _("Abort"),
          :focus_yes
        )
          return :back
        else
          return :next
        end
      end
      Wizard.CloseDialog() if @close_me
      return :next
    end
  end
end

Yast::FirstbootInstSapNetCheckClient.new.main
