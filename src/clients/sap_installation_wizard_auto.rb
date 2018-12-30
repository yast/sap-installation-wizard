# encoding: utf-8
# ------------------------------------------------------------------------------
# Copyright (c) 2016 SUSE LINUX GmbH, Nuernberg, Germany.
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
# this program; if not, contact SUSE Linux GmbH.
#
# ------------------------------------------------------------------------------
# Author: Peter Varkoly <varkoly@suse.com>

require "yast"
require "installation/auto_client"
require "y2sap/media"
require "y2sap/media/auto.rb"

module SapInst
  # Class to control the auto installation of SAP product on SLES.
  # For the HANA installation only a very simple xml part is neccessary.
  class AutoClient < Installation::AutoClient
    include Yast
    include UIShortcuts
    include I18n
    include Logger

    def initialize
      super
      textdomain "sap-installation-wizard"
    end

    def run
      progress_orig = Progress.set(false)
      ret = super
      Progress.set(progress_orig)
      ret
    end

    # There is only one bool parameter to import.
    def import(exported)
      log.info("-- sap-installation-wizard_auto.import Start --- #{exported}")
      return SAPMedia.Import(exported)
    end

    # There is noting to export.
    # TODO evtl we can export the copied directories and installed products
    def export
      return {}
    end

    # Insignificant to autoyast.
    def modified?
      return true
    end

    # Insignificant to autoyast.
    def modified
      return true
    end

    # Return a readable text summary.
    def summary
      return _("SAP Product Automatic Installation.")
    end

    def change
      AutoMainDialog.new.run
      return :finish
    end

    # Read the status of created SAP installation environments and installed products.
    def read
      @media = Y2Sap::Media.new
      if @media == nil
        return :abort
      end
      return true
    end

    # Write the configuration.
    def write
      SAPMedia.Write
    end

    # Set SapInst to "to be disabled".
    def reset
      # TODO, find a sence for it
      return true
    end

    # Return package dependencies
    def packages
      return { "install" => ["sap-installation-wizard"], "remove" => [] }
    end
  end
end

SapInst::AutoClient.new.run
