# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2015 SUSE LINUX GmbH.
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
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

# File: sap-installation-wizard/wizards.rb
# Module:       Configuration of SAP Products.
# Summary:      Configuration of SAP Products.
# Authors:      Peter Varkoly <varkoly@suse.com>
#

require "sap/add_repo_dialog"
require "hanafirewall/hanafirewall_conf"

module Yast
  import "Arch"
  module SapInstallationWizardWizardsInclude
    extend self
    def initialize_sap_installation_wizard_wizards(include_target)
      # Do not remove the empty function
      # I do not understand - removing it will cause weird failures
    end

    # If installation master is HANA, run HANAFirewall.Write to apply firweall settings.
    def ApplyHANAFirewall
        hana_fw = HANAFirewallConfInst.gen_config
	HANAFirewallConfInst.hana_sys = hana_fw[:hana_sys]
	HANAFirewallConfInst.open_ssh = hana_fw[:open_ssh]
	HANAFirewallConfInst.ifaces   = hana_fw[:ifaces]
        HANAFirewallConfInst.save_config
	HANAFirewallConfInst.set_state(true)
	#TODO Please report the customer what we have done
        return :next
    end

    def TuneTheSystem
        if Arch.x86_64
           require "saptune/saptune_conf"
           SaptuneConf.auto_config 
        end
    end

    # SAP Installation Main Sequence
    # @return sequence result
    def SAPInstSequence
      Yast.import "UI"

      textdomain "sap-installation-wizard"

      Yast.import "Sequencer"
      Yast.import "Wizard"
      Yast.import "Label"
      Yast.import "Stage"
      Yast.import "SAPMedia"

      # mark if the dialog must be closed at the and.
      close_dialog = false

      aliases = {
        "read"          => lambda { SAPMedia::Read()  },
        "readIM"        => lambda { SAPMedia::ReadInstallationMaster()   },
        "copy"          => lambda { SAPMedia::CopyNWMedia() },
        "3th"           => lambda { SAPMedia::ReadSupplementMedium() },
        "selectInstMode"=> lambda { SAPProduct::SelectNWInstallationMode() },
        "selectProduct" => lambda { SAPProduct::SelectNWProduct() },
        "readParameter" => lambda { SAPProduct::ReadParameter() },
        "write"         => lambda { SAPProduct::Write() },
        "add_repo"      => lambda { SAPInstaller::AddRepoWizardDialog.new.run },
        "tuning"        => lambda { TuneTheSystem() },
        "hanafw"        => lambda { ApplyHANAFirewall() }
      }

      sequence = {
        "ws_start" => "read",
        "read"     => {
                        :abort => :abort,
                        :auto  => "write",
                        :next  => "readIM"
                      },
        "readIM"   => {
                        :abort   => :abort, 
                        :HANA    => "3th",
                        :B1      => "3th",
                        :SAPINST => "copy"
                      },
        "copy"     => {
                        :abort => :abort,
                        :back  => "readIM",
                        :next  => "selectInstMode"
                      },
        "selectInstMode"  => {
                        :abort => :abort,
                        :back  => "copy",
                        :next  => "selectProduct"
                      },
        "selectProduct"  => {
                        :abort => :abort,
                        :back  => "selectInstMode",
                        :next  => "3th"
                      },
        "3th"      => {
                        :abort => :abort,
                        :back  => "copy",
                        :next  => "add_repo"
                      },
        "add_repo" => {
                        :abort => :abort,
                        :back => "copy",
                        :auto  => "write",
                        :next  => "readParameter"
                      },
        "readParameter"    => {
                        :abort   => :abort, 
                        :back    => "3th",
                        :next    => "write",
                        :readIM  => "readIM" 
                      },
        "write"    => {
                        :abort => :abort,
                        :next => "tuning"
                      },
        "tuning"     => {
                        :abort => :abort,
                        :next  => "hanafw"
                      },
        "hanafw" => {
                        :abort => :abort,
                        :next  => :next
                      }
      }

      if !Wizard.IsWizardDialog
        Wizard.CreateDialog
        close_dialog = true
      else
        Wizard.OpenNextBackDialog
        Wizard.HideAbortButton
      end
      Wizard.SetDesktopTitleAndIcon("sap")

      ret = Sequencer.Run(aliases, sequence)
      if close_dialog
         Wizard.CloseDialog
      end
      Convert.to_symbol(ret)
    end

    # SAP Media Handling Sequence to Create a SAP Intallation Envinroment
    # @return sequence result
    def SAPMediaSequence
      Yast.import "UI"

      textdomain "sap-installation-wizard"

      Yast.import "Sequencer"
      Yast.import "Wizard"
      Yast.import "Label"
      Yast.import "Stage"

      # mark if the dialog must be closed at the and.
      close_dialog = false
      aliases = {
        "read"    => lambda { SAPMedia::Read()  },
        "readIM"  => lambda { SAPMedia::ReadInstallationMaster()   },
        "copy"    => lambda { SAPMedia::CopyNWMedia() },
        "3th"     => lambda { SAPMedia::ReadSupplementMedium() },
	"add_repo"=> lambda { SAPInstaller::AddRepoWizardDialog.new.run },
        "write"   => lambda { SAPMedia::Write() }
      }

      sequence = {
        "ws_start" => "read",
        "read"     => {
                        :abort => :abort,
                        :auto  => "write",
                        :next  => "readIM"
                      },
        "readIM"   => {
                        :abort   => :abort, 
                        :HANA    => "3th",
                        :B1      => "3th",
                        :SAPINST => "copy"
                      },
        "copy"     => {
                        :abort => :abort,
                        :next  => "3th"
                      },
        "3th"      => {
                        :abort => :abort,
                        :back  => "copy",
                        :next  => "write"
                      },
        "write"     => {
                        :abort => :abort,
                        :back  => "copy",
                        :next  => "add_repo"
                      },
        "add_repo" => {
                        :abort => :abort,
                        :back  => "copy",
                        :auto  => "write",
                        :next  => :next
                      }
      }

      if !Wizard.IsWizardDialog
        Wizard.CreateDialog
        close_dialog = true
      else
        Wizard.OpenNextBackDialog
        Wizard.HideAbortButton
      end
      Wizard.SetDesktopTitleAndIcon("sap")

      ret = Sequencer.Run(aliases, sequence)
      if close_dialog
         Wizard.CloseDialog
      end
      Convert.to_symbol(ret)
    end
  end
end

