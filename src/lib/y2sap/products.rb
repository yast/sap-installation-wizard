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
require "y2sap/products/nw_installation_mode"

module Y2Sap
  # Represents a class for SAP NetWeaver Product handling and for the
  # installation of all SAP products
  class Products
    include Yast
    include Yast::UI
    include Yast::UIShortcuts
    include Y2Sap::NWInstallationMode
    include Y2Sap::NWProduct

    def initialize(media)
      textdomain "sap-installation-wizard"
      @media = media
      Y2Sap::ProductsVariables.init
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
