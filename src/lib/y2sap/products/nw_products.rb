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
    def select_nw_product
      create_content
      do_loop
    end

  private

    def create_content
     log.info("-- Start SelectNWProduct ---")
      run = true

      product_item_table = []
      if @inst_type == 'STANDALONE'
        @DB = 'IND'
      end
      @product_list = SAPXML.get_nw_products(SAPMedia.instDir,@inst_type,@DB,@productMAP["productDir"])
      if @product_list.nil? or @product_list.empty?
         Popup.Error(_("The medium does not contain SAP installation data."))
         return :back
      end
      @product_list.each { |map|
         name = map["name"]
         id   = map["id"]
         product_item_table << Item(Id(id),name,false)
      }
      log.info("@product_list #{@product_list}")

      Wizard.SetContents(
        @dialog_text["nw_select_product"]["name"],
        VBox(
          SelectionBox(Id(:products),
            _("Your SAP installation master supports the following products.\n"+
              "Please choose the product you wish to install:"),
            product_item_table
          )
        ),
        @dialog_text["nw_select_product"]["help"],
        true,
        true
      )
    end

    def do_loop
      run = true
      while run
        case UI.UserInput
        when :next
          @PRODUCT_ID = Convert.to_string(UI.QueryWidget(Id(:products), :CurrentItem))
	  if @PRODUCT_ID.nil?
            run = true
            Popup.Message(_("Select a product!"))
          else
            run = false
            @product_list.each { |map|
               @PRODUCT_NAME = map["name"] if @PRODUCT_ID == map["id"]
            }
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
  end
end

