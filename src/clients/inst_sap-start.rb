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
# Summary:      Select basic installation profile.
# Authors:      Peter Varkoly <varkoly@suse.com>
#
# $Id$

require "installation/services"
module Yast
  class InstSapStart < Client
    def main
      textdomain "users"
      Yast.import "Pkg"
      Yast.import "Popup"
      Yast.import "PackagesProposal"
      Yast.import "ProductControl"
      Yast.import "GetInstArgs"
      #MAY BE TODO set the default value
      sles   = false
      sap    = false
      wizard = false
      rdp    = true

      @caption = _("Choose Operation System Edition")
      @help    = _("<p><b>Select operating system edition</b></p>" +
                   "<p>If you wish to proceed with installing SAP softwares right after installing the operating system, tick the checkbox \"Launch SAP product installation wizard right after operating system is installed\".</p>")
      @contents = VBox(
            RadioButtonGroup(
              Id(:rb),
              VBox(
                Frame("",
		  VBox(
                    Left(
                      CheckBox(
                        Id("wizard"),
                        _("Launch SAP product installation wizard right after operating system is installed"),
                        true
                      )
                    ),
                    Left(
                      CheckBox(
                        Id("rdp"),
                        _("Enable RDP (Remote Desktop Protocol) Service and open in Firewall"),
                        true
                      )
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
	   constumize_sap_installation(
	   	Convert.to_boolean( UI.QueryWidget(Id("wizard"), :Value)),
		Convert.to_boolean( UI.QueryWidget(Id("rdp"), :Value))
	   )
        end
      end until ret == :next || ret == :back
      ret
    end

    def constumize_sap_installation(start_wizard,start_rdp)
        to_install = []
        to_remove  = []
	ProductControl.DisableModule("user_first")
        if(start_wizard)
           to_install << 'yast2-firstboot'
	   to_install << 'sap-installation-wizard'
	   to_install << 'sap-installation-start'
	else
	   to_install << 'sap-installation-wizard'
	   to_remove  << 'sap-installation-start'
	   to_remove  << 'yast2-firstboot'
	end
        if(start_rdp)
	   to_install << 'xrdp'
           Installation::Services.enabled << "xrdp"
	else
	   to_remove  << 'xrdp'
           Installation::Services.enabled.delete("xrdp")
	end
        PackagesProposal.AddResolvables('sap-wizard',   :package, to_install)
        if to_remove.size > 0
	   PackagesProposal.RemoveResolvables('sap-wizard',:package, to_remove)
	end
    end

  end
end

Yast::InstSapStart.new.main

