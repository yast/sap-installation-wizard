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

=begin
textdomain "sap-installation-wizard"
=end

require "yast"
Yast.import "UI"

module Y2Sap
  # Creates a gui for selecting the SAP NetWeaver product to install
  # Which products can be selected depends on the selected media
  module NWProducts
    include Yast::Logger
    include Yast
    include Yast::UI
    include Yast::UIShortcuts
    def select_nw_product
      create_content_nw_product
      do_loop_nw_product
    end

  private

    def create_content_nw_product
      log.info("-- Start SelectNWProduct ---")
      product_item_table = []
      @db = "IND" if @inst_type == "STANDALONE"
      @product_list = get_nw_products(@media.inst_dir, @inst_type, @db, @product_map["product_dir"])
      if @product_list.nil? || @product_list.empty?
        Yast::Popup.Error(_("The medium does not contain SAP installation data."))
        return :back
      end
      @product_list.each do |map|
        name = map["name"]
        id   = map["id"]
        product_item_table << Item(Id(id), name, false)
      end
      log.info("@product_list #{@product_list}")

      Wizard.SetContents(
        @dialog_text[:nw_select_product][:name],
        VBox(
          SelectionBox(
            Id(:products),
            _("Your SAP installation master supports the following products.\n \
              Please choose the product you wish to install:"),
            product_item_table
          )
        ),
        @dialog_text[:nw_select_product][:help],
        true,
        true
      )
    end

    def do_loop_nw_product
      run = true
      while run
        case UI.UserInput
        when :next
          @product_id = Convert.to_string(UI.QueryWidget(Id(:products), :CurrentItem))
          if @product_id.nil?
            run = true
            Yast::Popup.Message(_("Select a product!"))
          else
            @product_name = product_name
            run = false
          end
        when :back
          return :back
        when :abort, :cancel
          if Yast::Popup.ReallyAbort(false)
            Yast::Wizard.CloseDialog
            return :abort
          end
        end
      end
      :next
    end

    def product_name
      @product_list.each do |map|
        return map["name"] if @product_id == map["id"]
      end
    end
  end
end
