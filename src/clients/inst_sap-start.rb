# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2015 SUSE LINUX GmbH. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.suse.com.
# ------------------------------------------------------------------------------

# Package:      SAP Installation
# Summary:      Ask for starting sap installation wizard
# Authors:      Peter Varkoly <varkoly@suse.com>
#
# $Id$

module Yast
  class InstSapStart < Client
    def main
      textdomain "users"
      Yast.import "PackagesProposal"
      Yast.import "ProductControl"
      Yast.import "GetInstArgs"
      #MAY BE TODO set the default value
      start = false
      hana  = false
      dont  = false
      @caption = _("SAP product installation")
      @help    = _("<p>Use <b>Start SAP Product Setup after Installation</b> if you want the SAP Installation Wizard to start after the base system was installed.</p>")
      @contents = VBox(
            RadioButtonGroup(
              Id(:rb),
              VBox(
                Heading(_("SAP product installation")),
                Label(
                    _("Start SAP Installation Wizard at the end of installation?")
                ),
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
      Wizard.SetDesktopIcon("sap-installation-wizard")
      Wizard.SetContents(
        @caption,
        @contents,
        @help,
        GetInstArgs.enable_back,
        GetInstArgs.enable_next
      )
      ret = nil
      begin
        ret = Wizard.UserInput

        case ret
        when :abort
          break if Popup.ConfirmAbort(:incomplete)
        when :help
          Wizard.ShowHelp(@help)
        when :next
          sap_start = Convert.to_string(UI.QueryWidget(Id(:rb), :CurrentButton))
          case @sap_start
          when "true"
            IO.write("/root/start_sap_wizard","true");
          when "false"
            IO.write("/root/start_sap_wizard","false");
          when "hana_part"
            IO.write("/root/start_sap_wizard","hana_part");
          end
        end
      end until ret == :next || ret == :back
      ret
    end
  end
end

Yast::InstSapStart.new.main

