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

require "sap/dialogs"

module Yast
  module SapInstallationWizardWizardsInclude
    include SapInstallationWizardDialogsInclude
    extend self
    def initialize_sap_installation_wizard_wizards(include_target)
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
      aliases = {
        "read"    => lambda { ReadDialog()  },
        "readIM"  => lambda { ReadInstallationMaster()   },
        "selectI" => lambda { SelectNWInstallationMode() },
        "selectP" => lambda { SelectNWProduct() },
        "copy"    => lambda { CopyNWMedia() },
        "3th"     => lambda { ReadSupplementMedium() },
        "readP"   => lambda { ReadParameter() },
        "write"   => lambda { WriteDialog() }
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
                        :SAPINST => "selectI"
                      },
        "selectI"  => {
                        :abort => :abort,
                        :back  => "readIM",
                        :next  => "selectP"
                      },
        "selectP"  => {
                        :abort => :abort,
                        :back  => "selectI",
                        :next  => "copy"
                      },
        "copy"     => {
                        :abort => :abort,
                        :back  => "selectP",
                        :next  => "3th"
                      },
        "3th"      => {
                        :abort => :abort,
                        :back  => "copy",
                        :next  => "readP"
                      },
        "readP"    => {
                        :abort   => :abort, 
                        :back    => "3th",
                        :next    => "write",
                        :selectP => "selectP",
                        :readIM  => "readIM" 
                      },
        "write"    => {
                        :abort => :abort,
                        :next => :next
                      }
      }

      if Stage.cont
        Wizard.CreateDialog
      else
        Wizard.OpenNextBackDialog
        Wizard.HideAbortButton
      end
      Wizard.SetDesktopTitleAndIcon("sap")

      ret = Sequencer.Run(aliases, sequence)
      Wizard.CloseDialog
      Convert.to_symbol(ret)
    end

  end
end

