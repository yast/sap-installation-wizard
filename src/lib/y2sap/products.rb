# encoding: utf-8
  
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

require "yast"
require "y2sap/media"
require "y2sap/products/variables"
require "y2sap/products/nw_installation_mode"
require "y2sap/products/nw_products"

module Y2Sap
  # Represents a class for SAP NetWeaver Product handling and for the
  # installation of all SAP products
  class Products
    include Yast
    include Yast::I18n
    include Y2Sap::ProductsVariables
    include Y2Sap::NWInstallationMode
    include Y2Sap::NWProducts

    # @return [Map<String,String>] The product counter.
    attr_accessor :dialogs

    # @return [List<Map<String,String>>] The product counter.
    attr_accessor :product_list

    # @return [String] The selected data base.
    attr_accessor :DB

    # @return [String] The selected installation mode.
    attr_accessor :inst_type

    # @return [String] The ID of the selected product.
    attr_accessor :PRODUCT_ID

    # @return [String] The name of selected product.
    attr_accessor :PRODUCT_NAME

    # @return [Map<String,String>] The list of the products can be installed 
    # and the data base.
    attr_accessor :product_map

    # @return [List<String>] List of the directories to the products
    # to be installed
    attr_accessor :products_to_install
    
    # @return [Class<Y2SAP::Media>] This class instance contains the actual 
    # media collection for the product to be installed. 
    attr_reader   :media

    def initialize(media)
      textdomain "sap-installation-wizard"
      @media = media
      init_variables()
    end

    def nw_installation_mode
      select_nw_installation_mode()
    end

    def nw_product
      select_nw_product()
    end

    def install_sap
    end 
  end
end
