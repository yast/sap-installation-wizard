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
require "y2sap/media/dialogs"
Yast.import "UI"

module Y2Sap
  # Module containing the main part of dialogs for the wizard
  module MediaDialog
    include Yast
    include Yast::UI
    include Yast::UIShortcuts

    # Function to build a dialog to copy the media
    def media_dialog(wizard)
      log.info("-- Start media_dialog ---")
      @has_back = true
      content = Empty()
      @content_before_input = Empty()
      @content_input        = Empty()
      @content_advanced_ops = Empty()
      @after_advanced_ops   = Empty()
      @advanced_ops_left    = Empty()
      @selected_media       = {}
      case wizard
      when "inst_master"
        inst_master_dialog
      when "sapmedium"
        sapmedium_dialog
      when "supplement"
        supplement_dialog
      end
      # Render the wizard
      if @content_advanced_ops == Empty()
        content = VBox(
          Left(@content_before_input),
          VSpacing(2),
          Left(@content_input),
          VSpacing(2),
          Left(@after_advanced_ops)
        )
      else
        content = VBox(
          Left(@content_before_input),
          VSpacing(2),
          Left(@content_input),
          VSpacing(2),
          HBox(@advanced_ops_left, Frame(_("Advanced Options"), Left(@content_advanced_ops))),
          Left(@after_advanced_ops)
        )
      end
      Wizard.SetContents(
        _("SAP Installation Wizard"),
        content,
        "",
        @has_back,
        true
      )
      Wizard.RestoreAbortButton()
      UI.ChangeWidget(:scheme, :Value, @scheme_cache)
      do_default_values(wizard)
      do_loop(wizard)
    end

    # Sets the default value for location if the scheme was changed
    def do_default_values(wizard)
      @scheme_cache = Convert.to_string(UI.QueryWidget(Id(:scheme), :Value))
      log.info("do_default_values #{@location_cache} #{@scheme_cache} #{@location_cache}")
      case @scheme_cache
      when "device"
        @location_cache = "sda1/directory/"
      when "nfs"
        @location_cache = "nfs.server.com/directory/"
      when "usb"
        @location_cache = "directory/"
      when "local"
        @location_cache = "/directory/"
      when "smb"
        @location_cache = "[username:passwd@]server/path-on-server[?workgroup=my-workgroup]"
      when /cdrom/
        @location_cache = "//"
      end
      UI.ChangeWidget(:location, :Value, @location_cache)
      if !@sap_cds_url.empty? && wizard == "inst_master"
        # Activate the first installation master option
        location = @media_dir + "/" + Convert.to_string(UI.QueryWidget(Id(:local_im), :Value))
        UI.ChangeWidget(Id(:scheme), :Value, "dir")
        UI.ChangeWidget(Id(:scheme), :Enabled, false)
        UI.ChangeWidget(Id(:location), :Value, location)
        UI.ChangeWidget(Id(:location), :Enabled, false)
      end
    end

    def do_loop(wizard)
      loop do
        user_input = UI.UserInput
        log.info("User Input #{user_input}")
        case user_input
        when :back
          return :back
        when :abort, :cancel
          return :abort
        when :skip_copy_medium
          [:scheme, :location].each { |widget| UI.ChangeWidget(Id(widget), :Enabled, false) }
          UI.ChangeWidget(Id(:do_copy_medium), :Value, false)
        when :do_copy_medium
          [:scheme, :location].each { |widget| UI.ChangeWidget(Id(widget), :Enabled, true) }
          UI.ChangeWidget(Id(:skip_copy_medium), :Value, false)
        when :local_im
          # Choosing an already prepared installation master
          im = UI.QueryWidget(Id(:local_im), :Value)
          if im == "---"
            # Re-enable media input
            UI.ChangeWidget(Id(:scheme), :Enabled, true)
            UI.ChangeWidget(Id(:location), :Enabled, true)
            next
          end
          # Write down media location and disable media input
          location = @media_dir + "/" + Convert.to_string(UI.QueryWidget(Id(:local_im), :Value))
          UI.ChangeWidget(Id(:scheme), :Value, "dir")
          UI.ChangeWidget(Id(:scheme), :Enabled, false)
          UI.ChangeWidget(Id(:location), :Value, location)
          UI.ChangeWidget(Id(:location), :Enabled, false)
        when :scheme
          # Basically re-render layout
          log.info("scheme changed")
          do_default_values(wizard)
        when "media"
          # We have modified the list of selected media
          UI.ChangeWidget(Id(:skip_copy_medium), :Value, true)
          UI.ChangeWidget(Id(:do_copy_medium), :Value, false)
          [:scheme, :location].each { |widget| UI.ChangeWidget(Id(widget), :Enabled, false) }
        when :next
          ret = do_next
          return ret if !ret.nil?
        end # Case user input
      end # While true
      return :next
    end

    def do_next
      # Set the selected Items
      if UI.WidgetExists(Id("media"))
        @selected_media.each_key { |medium| @selected_media[medium] = false }
        UI.QueryWidget(Id("media"), :SelectedItems).each { |medium| @selected_media[medium] = true }
        log.info("selected_media #{@selected_media}")
      end

      # Export locally stored mediums over NFS
      @export_sap_cds = true if !!UI.QueryWidget(Id(:export), :Value)
      # Set installation mode to preauto so that only installation profiles are collected
      @inst_mode      = "preauto" if !!UI.QueryWidget(Id(:auto), :Value)

      scheme          = Convert.to_string(UI.QueryWidget(Id(:scheme), :Value))
      @location_cache = Convert.to_string(UI.QueryWidget(Id(:location), :Value))
      @cource_dir     = @location_cache

      return :forw if UI.QueryWidget(Id(:skip_copy_medium), :Value)

      # Break the loop for a choosen installation master, without executing check_media
      if UI.WidgetExists(Id(:local_im)) && UI.QueryWidget(Id(:local_im), :Value).to_s != "---"
        @source_dir = @media_dir + "/" + Convert.to_string(UI.QueryWidget(Id(:local_im), :Value))
        return :forw
      end
      url_path = mount_source(scheme, @location_cache)
      if url_path.start_with?("ERROR")
        Popup.Error(_("Failed to mount the location: ") + url_path)
        return nil
      end
      if scheme != "local"
        @source_dir = @mount_point + "/" + url_path
      elsif url_path != ""
        @source_dir = url_path
      end
      @umount_source = true
      log.info("end url_path #{url_path}, @source_dir #{@source_dir}, scheme #{scheme}")
      return :next
    end
  end
end
