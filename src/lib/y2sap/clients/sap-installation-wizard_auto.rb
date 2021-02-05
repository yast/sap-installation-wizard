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
require "y2sap/auto"

module SapInst
  # Class to control the auto installation of SAP product on SLES.
  # For the HANA installation only a very simple xml part is neccessary.
  class Auto < ::Installation::AutoClient
    include Yast
    include UIShortcuts
    include I18n
    include Logger

    class << self
	# @return [Boolean] whether the AutoYaST configuration has been
        # modified or not
        attr_accessor :changed
        # @return [Boolean] whether the AutoYaST configuration was imported
        # successfully or not
        attr_accessor :imported
        # @return [Boolean] whether the firewalld service has to be enabled
        # after writing the configuration
        attr_accessor :enable
        # @return [Boolean] whether the firewalld service has to be started
        # after writing the configuration
        attr_accessor :start
        # @return [Hash]
        attr_accessor :profile
        # @return [Boolean] whether the AutoYaST configuration has been
        # modified or not
        attr_accessor :ay_config

        # @return [Class<Y2SAP::Media>] This class instance contains the actual
        # media collection for the product to be installed.
        attr_accessor :sap_autoinst
    end

    def initialize
      super
      textdomain "sap-installation-wizard"
      log.info("-- sap-installation-wizard_auto.initialize Start --- #{@sap_autoinst}")
    end

    # There is only one bool parameter to import.
    def import(profile)
      log.info("-- sap-installation-wizard_auto.import Start --- #{profile}")
      self.class.profile  = profile
      self.class.imported = true
    end

    # There is noting to export.
    # TODO evtl we can export the copied directories and installed products
    def export
      log.info("-- sap-installation-wizard_auto.export Start")
      #return @sap_autoinst.sap_media_todo
      return {}
    end

    # Insignificant to autoyast.
    def modified?
      log.info("-- sap-installation-wizard_auto.modified? Start")
      return true
    end

    # Insignificant to autoyast.
    def modified
      log.info("-- sap-installation-wizard_auto.modified Start")
      return true
    end

    # Return a readable text summary.
    def summary
      return _("SAP Product Automatic Installation.")
    end

    def change
      log.info("-- sap-installation-wizard_auto.change Start")
      AutoMainDialog.new.run
      return :finish
    end

    # Read the status of created SAP installation environments and installed products.
    def read
      log.info("-- sap-installation-wizard_auto.read Start")
      @media.nil? ? :abort : true
    end

    # Write the configuration.
    def write
      log.info("-- sap-installation-wizard_auto.write Start --- #{@sap_autoinst}")
      sap_autoinst = Y2Sap::AutoInst.new
      sap_autoinst.write(self.class.profile)
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
