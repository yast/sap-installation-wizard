# Copyright (c) [2018] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may
# find current contact information at www.novell.com.
=begin
textdomain "sap-installation-wizard"
=end

require "nokogiri"

module Y2Sap
  # Module for the global variables in the Y2SAP::Products class
  module ProductsVariables
    # Initialize the global variables
    def init_variables
      begin
        @product_definitions_reader = Nokogiri::XML(File.read(@media.product_definitions))
        @product_list = init_product_list
      rescue StandardError
        log.error("Can not read #{@media.product_definitions}")
      end
      @dialog_text = {
        nw_inst_type: {
          help:  _("<p>Choose SAP product installation and back-end database.</p>") +
            "<p><b>" + _("SAP Standard System") + "</p></b>" +
            _("<p>Installation of a SAP NetWeaver system with all servers on the same host.</p>") +
            "<p><b>" + _("SAP Standalone Engines") + "</p></b>" +
            _("<p>Standalone engines are SAP Trex, SAP Gateway, and Web Dispatcher.</p>") +
            "<p><b>" + _("Distributed System") + "</p></b>" +
            _("Installation of SAP NetWeaver with the servers distributed on separate hosts.</p>") +
            "<p><b>" + _("High-Availability System") + "</p></b>" +
            _("Installation of SAP NetWeaver in a high-availability setup.</p>") +
            "<p><b>" + _("System Rename") + "</p></b>" +
            _("Change the SAP system ID, database ID, instance number, or host name of a SAP system.</p>"),
          name: _("Choose the Installation Type!")
        },
        nw_select_product: {
          help: _("<p>Please choose the SAP product you wish to install.</p>"),
          name: _("Choose a Product")
        }
      }

      @db            = ""
      @inst_type     = ""
      @product_id    = ""
      @product_name  = ""
      @product_map   = {}
      @products_to_install = []
    end

  private

    # @product_list contains a list of hashes of the parameter of the products which can be installed
    def init_product_list
      return [
        {
          "name"        => "HANA",
          "id"          => "HANA",
          "ay_xml"      => config_value("HANA", "ay_xml"),
          "partitioning"=> config_value("HANA", "partitioning"),
          "script_name" => config_value("HANA", "script_name")
        }, {
          "name"        => "HANA",
          "id"          => "HANA1.0",
          "ay_xml"      => config_value("HANA1.0", "ay_xml"),
          "partitioning"=> config_value("HANA1.0", "partitioning"),
          "script_name" => config_value("HANA1.0", "script_name")
        }, {
          "name"        => "B1",
          "id"          => "B1",
          "ay_xml"      => config_value("B1", "ay_xml"),
          "partitioning"=> config_value("B1", "partitioning"),
          "script_name" => config_value("B1", "script_name")
        }, {
          "name"        => "TREX",
          "id"          => "TREX",
          "ay_xml"      => config_value("TREX", "ay_xml"),
          "partitioning"=> config_value("TREX", "partitioning"),
          "script_name" => config_value("TREX", "script_name")
        }
      ]
    end
  end
end
