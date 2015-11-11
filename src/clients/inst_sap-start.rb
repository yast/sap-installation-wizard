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
      sles   = false
      sap    = false
      wizard = false
      @caption = _("Product Installation Mode")
      @help    = _("<p>Use <b>Start SAP Product Setup after Installation</b> if you want the SAP Installation Wizard to start after the base system was installed.</p>")
      @contents = VBox(
            RadioButtonGroup(
              Id(:rb),
              VBox(
                Heading(_("Select the Mode of the Product Installation!")),
                Left(
                  RadioButton(
                    Id("sles"),
                    Opt(:notify),
                    _("Proceed normal SLES installation."),
                    sles
                  )
                ),
                Left(
                  RadioButton(
                       Id("sap"),
                       Opt(:notify),
                       _("Proceed SAP customized SLES installation."),
                       sap
                     )
                   ),
                Frame("",
                    Left(
                      CheckBox(
                        Id("wizard"),
                        _("Start the SAP Installation Wizard at the end of installation."),
                        wizard
                      )
                    )
               )
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
      UI.ChangeWidget(Id("wizard"),:Enabled,false)
      ret = nil
      begin
        ret = Wizard.UserInput
        Builtins.y2milestone("ret %1",ret)
        case ret
        when :abort
          break if Popup.ConfirmAbort(:incomplete)
        when :help
          Wizard.ShowHelp(@help)
	when "sles"
	  UI.ChangeWidget(Id("wizard"),:Enabled,false)
	when "sap"
	  UI.ChangeWidget(Id("wizard"),:Enabled,true)
        when :next
          install   = Convert.to_string(UI.QueryWidget(Id(:rb), :CurrentButton))
          case install
          when "sap"
	    constumize_sap_installation(Convert.to_boolean( UI.QueryWidget(Id("wizard"), :Value)) )
          when "sles"
	    constumize_sles_installation
          end
        end
      end until ret == :next || ret == :back
      ret
    end

    def constumize_sap_installation(start_wizard)
        ProductControl.ReadControlFile("/sap-control.xml")
        if(start_wizard)
           PackagesProposal.AddResolvables('sap-wizard',:package,['yast2-firstboot','sap-installation-wizard'])
           ProductControl.EnableModule("sap")
	else
           PackagesProposal.AddResolvables('sap-wizard',:package,['sap-installation-wizard'])
           ProductControl.DisableModule("sap")
	end
    end

    def constumize_sles_installation()
        ProductControl.ReadControlFile("/control.xml")
        PackagesProposal.RemoveResolvables('sap-wizard',:package,['yast2-firstboot','sap-installation-wizard'])
    end
  end
end

Yast::InstSapStart.new.main

