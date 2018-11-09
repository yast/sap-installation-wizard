# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2014 SUSE Linux GmbH. All Rights Reserved.
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
# ------------------------------------------------------------------------------
# File: clients/sap-installation-wizard.rb
# Module:       SAP Installation Wizard
# Summary:      Client file, including commandline handlers
# Authors:      Peter Varkoly <varkoly@suse.com>
#

# <h3>YAST Module to Install SAP Applications on SLE4SAP</h3>

require "sap/wizards"

module Yast
  class SapInstallationWizard < Client
    include SapInstallationWizardWizardsInclude
    def main
      textdomain "sap-installation-wizard"
      Yast.import "SAPMedia"
      Yast.import "SAPProduct"
      Yast.import "SAPPartitioning"
      Yast.import "CommandLine"
      Yast.import "RichText"
      log.info("sap-installation-wizard called with #{WFM.Args}")

      @ret = :auto
      # the command line description map
      @cmdline = {
        "id"   => "sap-installation-wizard",
	"help" => _("YAST Module to Install SAP Applications on SLES for SAP Applications."),
	"guihandler" => fun_ref(method(:SAPInstSequence),  "symbol ()"),
#	"initialize" => fun_ref(SAPInst.method(:Read), "boolean ()"),
#	"finish"     => fun_ref(SAPInst.method(:Write),"boolean ()"),
	"actions"    => {
            "hana_partitioning"   => {
               "handler" => fun_ref(SAPPartitioning.method(:CreateHANAPartitions),"void ()"),
               "help"    => _("Create HANA Partitionint.")
            }
	}
      }
      @ret = CommandLine.Run(@cmdline)
      deep_copy(@ret)
      if SAPMedia.importSAPCDs
         SCR.Execute(path(".target.bash"), "umount " + SAPMedia.mediaDir)
      end
    end
  end
end
Yast::SapInstallationWizard.new.main

