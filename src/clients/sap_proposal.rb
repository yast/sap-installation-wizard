module Yast

  class SAPProposalClient < Client
    SAP_ENABLE_LINK  = "sap_enable"
    SAP_DISABLE_LINK = "sap_disable"
    SAP_ACTION_ID    = "sap"

    def main
      func = WFM.Args[0]
      param = WFM.Args[1] || {}
      @sap_enabled = true;
      if File.exists?("/root/start_sap_wizard")
         start = IO.read("/root/start_sap_wizard")
         if start == "false"
	    @sap_enabled = false;
         end
      else
         IO.write("/root/start_sap_wizard","true");
      end
    
      case func
      when "MakeProposal"
        ret = {
          "preformatted_proposal" => proposal_text,
          "links"                 => [SAP_ENABLE_LINK, SAP_DISABLE_LINK],
          # TRANSLATORS: help text
          "help"                  => _(
            "<p>Use <b>Start SAP Product Setup after Installation</b> if you want the SAP Installation Wizard to start after the base system was installed.</p>"
          )
        }

      when "AskUser"
        chosen_id = Ops.get(param, "chosen_id")
        case chosen_id
        when SAP_DISABLE_LINK
          @sap_enabled = false
          IO.write("/root/start_sap_wizard","false");
        when SAP_ENABLE_LINK
          IO.write("/root/start_sap_wizard","true");
          @sap_enabled = true
        when SAP_ACTION_ID
          @sap_enabled = Popup.YesNo(
            _("Start SAP Installation Wizard at the end of installation?")
          )
          if @sap_enabled
            IO.write("/root/start_sap_wizard","true");
	  else
            IO.write("/root/start_sap_wizard","false");
	  end
        else
          raise "Unexpected value #{chosen_id}"
        end
	ret = { "workflow_sequence" => :next }

      when "Description"
        ret = {
          # this is a heading
          "rich_text_title" => _("Start SAP Installation Wizard at the End Installation"),
          # this is a menu entry
          "menu_title"      => _("Start SAP Installation &Wizard at the End Installation"),
          "id"              => SAP_ACTION_ID
        }

      when "Write"
      else
        raise "Unsuported action #{func}"
      end
      ret
    end

    def proposal_text
      ret = "<ul><li>\n"

      if @sap_enabled
        ret << Builtins.sformat(
          # TRANSLATORS: Installation overview
          # IMPORTANT: Please, do not change the HTML link <a href="...">...</a>, only visible text
          _(
            "The SAP Installation Wizard <a href=\"%1\">will be started</a> at the end of the installation."
          ),
          SAP_DISABLE_LINK
        )
      else
        ret << Builtins.sformat(
          # TRANSLATORS: Installation overview
          # IMPORTANT: Please, do not change the HTML link <a href="...">...</a>, only visible text
          _(
            "The SAP Installation Wizard <a href=\"%1\">will not be started</a> at the end of the installation."
          ),
          SAP_ENABLE_LINK
        )
      end

      ret << "</li></ul>\n"
    end
  end unless defined? (SAPProposalClient) # avoid class redefinition if reevaluated
end

Yast::SAPProposalClient.new.main
