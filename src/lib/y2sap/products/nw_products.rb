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

module Y2Sap
  # Creates a gui for selecting the SAP NetWeaver product to install
  # Which products can be selected depends on the selected media
  module NWProducts
    Yast.import "SAPXML"
    def select_nw_product()
      create_content
      do_loop
    end

    private
    def create_content()
      :next
    end

    def do_loop()
      :next
    end
  end
end

