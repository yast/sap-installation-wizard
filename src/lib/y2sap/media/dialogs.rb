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
  # Module contains the specific part of the dialogs
  module MediaDialog
    include Yast
    include Yast::UI
    include Yast::UIShortcuts

    # Function to build a dialog to copy the installation master
    def inst_master_dialog
      @has_back = false
      instmaster_media = local_media.grep(/Instmaster-/)
      create_im_before if !instmaster_media.empty?
      @content_input = HBox(
        ComboBox(Id(:scheme), Opt(:notify), " ", @scheme_list),
        InputField(
          Id(:location),
          Opt(:hstretch),
          _("Prepare SAP installation master"),
          @location_cache
        )
      )
      advanced_ops = [
        Left(
          CheckBox(
            Id(:auto),
            _("Collect installation profiles for SAP products but do not execute installation."), false
          )
        )
      ]
      if !@sap_cds_url.empty?
        # link & export options are not applicable if SAP_CD is mounted from network location
        advanced_ops += [
          Left(
            CheckBox(
              Id(:export),
              _("Serve all installation mediums (including master) to local network via NFS."),
              false
            )
          )
        ]
      end
      @content_advanced_ops = VBox(*advanced_ops)
      @after_advanced_ops = VBox(
        VSpacing(2.0),
        Left(RadioButton(Id(:skip_copy_medium), Opt(:notify), _("Skip copying of medium")))
      )
      @advanced_ops_left = HSpacing(6.0)
    end

    def create_im_before
      @content_before_input = if @sap_cds_url.empty?
        # Otherwise, allow user to enter new installation master
        Frame(
          _("Choose an installation master"),
          ComboBox(Id(:local_im), Opt(:notify), "", ["---"] + instmaster_media)
        )
      else
        # If SAP_CD is mounted from network location, do not allow empty selection
        VBox(
          Frame(
            format(_("Ready for use from: %s"), @sap_cds_url),
            Label(Id(:mediums), Opt(:hstretch), media.join("\n"))
          ),
          Frame(
            _("Choose an installation master"),
            Left(
              ComboBox(Id(:local_im), Opt(:notify), "", instmaster_media)
            )
          )
        )
      end
    end

    # Function to build a dialog to copy a sap media
    def sapmedium_dialog
      product_media = local_media.reject { |name| (name =~ /Instmaster-/) }
      if !product_media.empty?
        media_items = []
        product_media.each do |medium|
          media_items << Item(Id(medium), medium, @selected_media.key?(medium) ? @selected_media[medium] : true)
        end
        @content_before_input = VBox(
          MultiSelectionBox(Id("media"), Opt(:notify), _("Ready for use:"), media_items)
        )
      end
      @content_input = VBox(
        Left(RadioButton(Id(:do_copy_medium), Opt(:notify), _("Copy a medium"), true)),
        Left(
          HBox(
            HSpacing(6.0),
            ComboBox(Id(:scheme), Opt(:notify), " ", @scheme_list),
            InputField(
              Id(:location), Opt(:hstretch),
              _("Prepare SAP installation medium (such as SAP kernel, database and exports)"),
              @location_cache
            ),
            HSpacing(6.0)
          )
        )
      )
      @after_advanced_ops = VBox(
        VSpacing(2.0),
        Left(RadioButton(Id(:skip_copy_medium), Opt(:notify), _("Skip copying of medium")))
      )
    end

    # Function to build a dialog to copy a suplementary media
    def supplement_dialog
      product_media = local_media.reject { |name| (name =~ /Instmaster-/) }
      if !product_media.empty?
        @content_before_input = Frame(
          _("Ready for use:"), Label(Id(:mediums), Opt(:hstretch), product_media.join("\n"))
        )
      end
      @content_input = HBox(
        ComboBox(
          Id(:scheme),
          Opt(:notify),
          " ",
          @scheme_list
        ),
        InputField(
          Id(:location),
          Opt(:hstretch),
          _("Prepare SAP supplementary medium"),
          @location_cache
        )
      )
    end
  end
end
