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
module Yast
  # Proposal modul for the SLES4SAP product to select the installation mode
  class SAPProposalClient < Client
    SAP_ENABLE_LINK    = "sap_enable"
    SAP_DISABLE_LINK   = "sap_disable"
    SAP_HANA_PART_LINK = "sap_hana_part"
    SAP_ACTION_ID      = "sap"
    @sap_start         = "true"

    def main
      textdomain "sap-installation-wizard"

      Yast.import "PackagesProposal"
      Yast.import "ProductControl"

      func = WFM.Args[0]
      param = WFM.Args[1] || {}
      log.info("sap_proposal called with #{WFM.Args} func: #{func}");
      if File.exists?("/root/start_sap_wizard")
        @sap_start = IO.read("/root/start_sap_wizard")
      else
        IO.write("/root/start_sap_wizard","true");
      end
      case func
      when "MakeProposal"
        return make_proposal
      when "AskUser"
        return ask_user(param)
      when "Description"
        return description
      when "Write"
      else
        raise "Unsuported action #{func}"
      end
    end

    def make_proposal
      PackagesProposal.AddResolvables('sap-wizard',:package,['sap-installation-wizard'])
      if @sap_start == "false"
        PackagesProposal.RemoveResolvables('sap-wizard',:package,['yast2-firstboot'])
        ProductControl.DisableModule("sap")
      else
        PackagesProposal.AddResolvables('sap-wizard',:package,['yast2-firstboot'])
        ProductControl.EnableModule("sap")
      end
      return {
        "preformatted_proposal" => proposal_text,
        "links"                 => [SAP_ENABLE_LINK, SAP_DISABLE_LINK, SAP_HANA_PART_LINK],
        # TRANSLATORS: help text
        "help"                  => _(
          "<p>Use <b>Start SAP Product Setup after Installation</b> if you want the SAP Installation Wizard to start after the base system was installed.</p>"
        )
      }
    end

    def ask_user(param)
      chosen_id = Ops.get(param, "chosen_id")
      case chosen_id
      when SAP_DISABLE_LINK
        IO.write("/root/start_sap_wizard","false")
      when SAP_ENABLE_LINK
        IO.write("/root/start_sap_wizard","true")
      when SAP_HANA_PART_LINK
        IO.write("/root/start_sap_wizard","hana_part")
      when SAP_ACTION_ID
        start = @sap_start == "true"
        hana  = @sap_start == "hana_part"
        dont  = @sap_start == "false"
        UI.OpenDialog(
          RadioButtonGroup(
            Id(:rb),
            VBox(
              Heading(_("SAP product installation")),
              Label(_("Start SAP Installation Wizard at the end of installation?")),
              Left(
                RadioButton(
                  Id("true"),
                  _("Create SAP file systems and start SAP product installation."),
                  start
                )
              ),
              Left(
                RadioButton(
                  Id("hana_part"),
                  _("Only create SAP Business One file systems, do not install SAP products now."),
                  hana
                )
              ),
              Left(
                RadioButton(
                  Id("false"),
                  _("Do not start SAP Product installation. Proceed to OS login."),
                  dont
                )
              ),
              HBox(PushButton("&OK"))
            )
          )
        )
        UI.UserInput
        @sap_start = Convert.to_string(UI.QueryWidget(Id(:rb), :CurrentButton))
        UI.CloseDialog()
        case @sap_start
        when "true"
          IO.write("/root/start_sap_wizard","true");
        when "false"
          IO.write("/root/start_sap_wizard","false");
        when "hana_part"
          IO.write("/root/start_sap_wizard","hana_part");
        end
      else
        raise "Unexpected value #{chosen_id}"
      end
      return { "workflow_sequence" => :next }
    end

    def description
      return {
        # this is a heading
        "rich_text_title" => _("Start SAP Installation Wizard at the End of Installation"),
        # this is a menu entry
        "menu_title"      => _("Start SAP Installation &Wizard at the End of Installation"),
        "id"              => SAP_ACTION_ID
      }
    end

    def proposal_text
      ret = "<ul><li>\n"

      case @sap_start
      when "true"
        ret << Builtins.sformat(
          # TRANSLATORS: Installation overview
          # IMPORTANT: Please, do not change the HTML link <a href="...">...</a>, only visible text
          _(
            "<a href=\"%1\">Create SAP file systems and start SAP product installation.</a>"
          ),
          SAP_HANA_PART_LINK
        )
      when "hana_part"
        ret << Builtins.sformat(
          # TRANSLATORS: Installation overview
          # IMPORTANT: Please, do not change the HTML link <a href="...">...</a>, only visible text
          _(
            "<a href=\"%1\">Only create SAP Business One file systems, do not install SAP products now.</a>"
          ),
          SAP_DISABLE_LINK
        )
      when "false"
        ret << Builtins.sformat(
          # TRANSLATORS: Installation overview
          # IMPORTANT: Please, do not change the HTML link <a href="...">...</a>, only visible text
          _(
            "<a href=\"%1\">Do not start SAP Product installation. Proceed to OS login.</a>"
          ),
          SAP_ENABLE_LINK
        )
      end

      ret << "</li></ul>\n"
    end
  end unless defined? (SAPProposalClient) # avoid class redefinition if reevaluated
end

