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
  # Select basic installation profile
  class InstSapStart < Client
    include Yast::Logger
    BONE_REQUIRED_MODULES = [
      "sle-module-desktop-applications",
      "sle-module-development-tools",
      "sle-module-legacy",
      "sle-module-server-applications"
    ]
    BONE_REQUIRED_ADD_ONS = [
      "Module-Desktop-Applications",
      "Module-Development-Tools",
      "Module-Legacy",
      "Module-Server-Applications"
    ]

    def main
      textdomain "sap-installation-wizard"
      Yast.import "Arch"
      Yast.import "Package"
      Yast.import "Popup"
      Yast.import "PackagesProposal"
      Yast.import "ProductControl"
      Yast.import "GetInstArgs"

      set_variable
      Wizard.SetDesktopIcon("sap-installation-wizard")
      Wizard.SetContents(
        @caption,
        @contents,
        @help,
        GetInstArgs.enable_back,
        GetInstArgs.enable_next
      )
      ret = nil
      loop do
        ret = Wizard.UserInput
        case ret
        when :abort
          break if Popup.ConfirmAbort(:incomplete)
        when :help
          Wizard.ShowHelp(@help)
        when :next
          customize_sap_installation(
            Convert.to_boolean(UI.QueryWidget(Id("wizard"), :Value)),
            Convert.to_boolean(UI.QueryWidget(Id("rdp"), :Value))
          )
          break
        when :back
          break
        end
      end
      ret
    end

    def customize_sap_installation(start_wizard, start_rdp)
      to_install = []
      to_remove  = []
      ProductControl.DisableModule("user_first")
      if start_wizard
        to_install << "yast2-firstboot"
        to_install << @wizard
        to_install << "sap-installation-start"
      else
        to_install << @wizard
        to_remove  << "sap-installation-start"
        to_remove  << "yast2-firstboot"
      end
      if start_rdp
        to_install << "xrdp"
        ::Installation::Services.enabled << "xrdp"
      else
        to_remove << "xrdp"
        ::Installation::Services.enabled.delete("xrdp")
      end
      if @wizard == "bone-installation-wizard"
        install_bone_required_modules
        to_install << "patterns-sap-bone"
      end
      PackagesProposal.AddResolvables("sap-wizard", :package, to_install)
      PackagesProposal.RemoveResolvables("sap-wizard", :package, to_remove) if !to_remove.empty?
    end

    def set_variable
      @wizard  = Package.PackageAvailable("sap-installation-wizard") ? "sap-installation-wizard" : "bone-installation-wizard"
      @caption = _("Choose Operating System Edition")
      @help    = _("<p><b>Select operating system edition</b></p> \
         <p>If you wish to proceed with installing SAP softwares right after installing the operating system, tick\
         the checkbox \"Launch SAP product installation wizard right after operating system is installed\".</p>")
      @contents = VBox(
        RadioButtonGroup(
          Id(:rb),
          VBox(
            Frame(
              "",
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
                    _("Enable Remote Desktop Protocol (RDP) Service and open port in Firewall"),
                    true
                  )
                )
              )
            )
          )
        )
      )
    end

    def install_bone_required_modules
      require "registration/registration"
      require "registration/storage"
      if Registration::Registration.is_registered?
        options = Registration::Storage::InstallationOptions.instance
        version = Yast::OSRelease.ReleaseVersion
        arch = Yast::Arch.rpm_arch
        reg = Registration::Registration.new
        BONE_REQUIRED_MODULES.each do |product|
          product_data = {
            "name"     => product,
            "reg_code" => options.reg_code,
            "arch"     => arch,
            "version"  => version
          }
          log.info("Bone register SLE Module: #{product} #{arch} #{version}")
          reg.register_product(product_data)
        end
      else
        BONE_REQUIRED_ADD_ONS.each do |product|
          log.info("Bone add source for: #{product}")
          Pkg.SourceCreate("dvd:///" + product, "/")
        end
      end
    end
  end
end

Yast::InstSapStart.new.main
