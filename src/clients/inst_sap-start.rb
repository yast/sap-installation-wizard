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
      Yast.import "Pkg"
      Yast.import "PackagesProposal"
      Yast.import "ProductControl"
      Yast.import "GetInstArgs"
      #MAY BE TODO set the default value
      sles   = false
      sap    = false
      wizard = false
      @sap_control = Pkg.SourceProvideOptionalFile(
        0, # optional
        1,
        "/sap-control.xml"      )

      @caption = _("Product Installation Mode")
      @help    = _("<p><b>Select basic installation profile:</b> Select which installation template you want to use: Option \"Proceed with standard SLES installation\" will result in a standard SLES installation - all default values are those of a standard SLES installation. Option \"Proceed with standard SLES for SAP Applications installation\" will result in an installation workflow which is prepared for the installation of SAP products. Default package selection and partitioning profiles are adapted. In case of the SLES for SAP Applications installation profile it is possible to select the \"Installation Wizard\" to be started automatically after the installation of the Operating System has settled. Select if you want the Installation Wizard to be started autmatically.</p>")
      @contents = VBox(
            RadioButtonGroup(
              Id(:rb),
              VBox(
                Heading(_("Select the Profile of the Product Installation!")),
                Left(
                  RadioButton(
                    Id("sles"),
                    Opt(:notify),
                    _("Proceed with standard SLES installation."),
                    sles
                  )
                ),
                Left(
                  RadioButton(
                       Id("sap"),
                       Opt(:notify),
                       _("Proceed with standard SLES for SAP Applications installation."),
                       sap
                     )
                   ),
                Frame("",
                    Left(
                      CheckBox(
                        Id("wizard"),
                        _("Start the SAP Installation Wizard right after the OS installation."),
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
        ProductControl.ReadControlFile( @sap_control )
        if(start_wizard)
           PackagesProposal.AddResolvables('sap-wizard',:package,['yast2-firstboot','sap-installation-wizard'])
	   IO.write("/root/start_sap_wizard","true");
           ProductControl.EnableModule("sap")
	else
           PackagesProposal.AddResolvables('sap-wizard',:package,['sap-installation-wizard'])
           PackagesProposal.RemoveResolvables('sap-wizard',:package,['yast2-firstboot'])
           ProductControl.DisableModule("sap")
	end
    end

    def constumize_sles_installation()
        ProductControl.ReadControlFile("/control.xml")
        PackagesProposal.RemoveResolvables('sap-wizard',:package,['yast2-firstboot','sap-installation-wizard'])
        ProductControl.DisableModule("sap")
    end
  end
end

Yast::InstSapStart.new.main

