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
  # Creates a gui for selecting the SAP NetWeaver installation mode
  # Which products installation mode can be selected depends on the selected media
  module NWInstallationMode
    include Yast
    include Yast::UI
    include Yast::UIShortcuts
    def select_nw_installation_mode()
      log.info("-- Start select_nw_installation_mode --- for instDir #{@media.inst_dir}" )
      create_content_nw_installation_mode
      do_loop_nw_installation_mode
    end

  private

    # Creates the gui
    def create_content_nw_installation_mode
      log.info("-- Start SelectNWInstallationMode --- for instDir #{@media.inst_dir}" )

      # Reset the the selected product specific parameter
      @product_map    = @media.get_products_for_media(@media.inst_dir )
      log.info("@product_map #{@product_map}")
      @inst_type     = ""
      @DB            = ""
      @PRODUCT_ID    = ""
      @PRODUCT_NAME  = ""

      log.info("known variables " + self.instance_variables.join(" ") )
      log.info("@dialog_text #{@dialog_text}")
      Wizard.SetContents(
        @dialog_text[:nw_inst_type][:name],
        VBox(
          HVSquash(Frame("",
          VBox(
            HBox(
                VBox(
                    Left(Label(_("Installation Type"))),
                    RadioButtonGroup( Id(:type),
                    VBox(
                        RadioButton( Id("STANDARD"),    Opt(:notify, :hstretch), _("SAP Standard System"), false),
                        RadioButton( Id("DISTRIBUTED"), Opt(:notify, :hstretch), _("Distributed System"), false),
                        # RadioButton( Id("SUSE-HA-ST"),  Opt(:notify, :hstretch), _("SUSE HA for SAP Simple Stack"), false),
                        RadioButton( Id("HA"),          Opt(:notify, :hstretch), _("SAP High-Availability System"), false),
                        RadioButton( Id("STANDALONE"),  Opt(:notify, :hstretch), _("SAP Standalone Engines"), false),
                        RadioButton( Id("SBC"),         Opt(:notify, :hstretch), _("System Rename"), false),
                    )),
                ),
                HSpacing(3),
                VBox(
                    Left(Label(_("Back-end Databases"))),
                    RadioButtonGroup( Id(:db),
                    VBox(
                        RadioButton( Id("ADA"),    Opt(:notify, :hstretch), _("SAP MaxDB"), false),
                        RadioButton( Id("HDB"),    Opt(:notify, :hstretch), _("SAP HANA"), false),
                        RadioButton( Id("SYB"),    Opt(:notify, :hstretch), _("SAP ASE"), false),
                        RadioButton( Id("DB6"),    Opt(:notify, :hstretch), _("IBM DB2"), false),
                        RadioButton( Id("ORA"),    Opt(:notify, :hstretch), _("Oracle"), false)
                    ))
                )
            ),
          )
        ))),
        @dialog_text[:nw_inst_type][:help],
        true,
        true
      )
      if !@media.sap_cds_url.empty?
         UI.ChangeWidget(Id("STANDARD"),   :Enabled, false)
         UI.ChangeWidget(Id("STANDALONE"), :Enabled, false)
         UI.ChangeWidget(Id("SBC"),        :Enabled, false)
      end
      adapt_db(@product_map["DB"])
      media = File.read(@media.inst_dir  + "/start_dir.cd")
      if ! media.include?("KERNEL")
         UI.ChangeWidget(Id("STANDARD"),    :Enabled, false)
         UI.ChangeWidget(Id("DISTRIBUTED"), :Enabled, false)
         UI.ChangeWidget(Id("HA"),          :Enabled, false)
         # Does not exists at the time
         # UI.ChangeWidget(Id("SUSE-HA-ST"),  :Enabled, false)
         UI.ChangeWidget(Id("ADA"), :Enabled, false)
         UI.ChangeWidget(Id("HDB"), :Enabled, false)
         UI.ChangeWidget(Id("SYB"), :Enabled, false)
         UI.ChangeWidget(Id("DB6"), :Enabled, false)
         UI.ChangeWidget(Id("ORA"), :Enabled, false)
      end
    end

    # The loop for handling the gui inputs
    # @return [:next or :abort]
    def do_loop_nw_installation_mode
      run = true
      while run
        case UI.UserInput
        when /STANDARD|DISTRIBUTED|SUSE-HA-ST|HA/
          UI.ChangeWidget(Id(:db), :Enabled, true)
          @inst_type = Convert.to_string(UI.QueryWidget(Id(:type), :CurrentButton))
        when /STANDALONE|SBC/
          UI.ChangeWidget(Id(:db), :Enabled, false)
          @inst_type = Convert.to_string(UI.QueryWidget(Id(:type), :CurrentButton))
        when /DB6|ADA|ORA|HDB|SYB/
          @DB = Convert.to_string(UI.QueryWidget(Id(:db), :CurrentButton))
        when :next
          run = false
          if @inst_type == ""
            run = true
            Yast::Popup.Message(_("Please choose an SAP installation type."))
            next
          end
          if @inst_type !~ /STANDALONE|SBC/ and @DB == ""
            run = true
            Yast::Popup.Message(_("Please choose a back-end database."))
            next
          end
        when :back
          return :back
        when :abort, :cancel
          if Yast::Popup.ReallyAbort(false)
              Yast::Wizard.CloseDialog
              run = false
              return :abort
          end
        end
      end
      return :next
    end

    def adapt_db(data_base)
      log.info("-- Start SAPProduct adapt_db --")
      if data_base == ""
         UI.ChangeWidget(Id("STANDARD"), :Enabled, false)
      else
         UI.ChangeWidget(Id("ORA"), :Enabled, false)
         case data_base
         when "ADA"
           UI.ChangeWidget(Id("ADA"), :Value, true)
           UI.ChangeWidget(Id("HDB"), :Enabled, false)
           UI.ChangeWidget(Id("SYB"), :Enabled, false)
           UI.ChangeWidget(Id("DB6"), :Enabled, false)
           UI.ChangeWidget(Id("ORA"), :Enabled, false)
           @DB = data_base
         when "HDB"
           UI.ChangeWidget(Id("HDB"), :Value, true)
           UI.ChangeWidget(Id("ADA"), :Enabled, false)
           UI.ChangeWidget(Id("SYB"), :Enabled, false)
           UI.ChangeWidget(Id("DB6"), :Enabled, false)
           UI.ChangeWidget(Id("ORA"), :Enabled, false)
           @DB = data_base
         when "SYB"
           UI.ChangeWidget(Id("SYB"), :Value, true)
           UI.ChangeWidget(Id("ADA"), :Enabled, false)
           UI.ChangeWidget(Id("HDB"), :Enabled, false)
           UI.ChangeWidget(Id("DB6"), :Enabled, false)
           UI.ChangeWidget(Id("ORA"), :Enabled, false)
           @DB = data_base
         when "DB6"
           UI.ChangeWidget(Id("DB6"), :Value, true)
           UI.ChangeWidget(Id("ADA"), :Enabled, false)
           UI.ChangeWidget(Id("HDB"), :Enabled, false)
           UI.ChangeWidget(Id("SYB"), :Enabled, false)
           UI.ChangeWidget(Id("ORA"), :Enabled, false)
           @DB = data_base
         when "ORA"
           # FATE
           Yast::Popup.Error( _("The Installation of Oracle Databas with SAP Installation Wizard is not supported."))
           return :abort
         end
      end
    end
  end
end
