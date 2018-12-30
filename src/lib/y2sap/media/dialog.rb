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
  module MediaDialog
    include Yast
    include Yast::UI
    include Yast::UIShortcuts

    def parse_xml(file)
       ret =  WFM.CallFunction("ayast_setup", ["setup","filename="+file, "dopackages=yes" ] )
       log.info("ayast_setup returned '" + ret + "' for: " + file)
       return ret
    end

    #Function to build a dialog to copy the media
    def media_dialog(wizard)
      log.info("-- Start media_dialog ---")
      @has_back = true
      content = Empty()
      @content_before_input = Empty()
      @content_input        = Empty()
      @content_advanced_ops = Empty()
      @after_advanced_ops   = Empty()
      @advanced_ops_left    = Empty()
      case wizard
      when "inst_master"
        inst_master_dialog()
      when "sapmedium"
        sapmedium_dialog()
      when "supplement"
        supplement_dialog()
      end
      # Render the wizard
      if( @content_advanced_ops == Empty() )
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
      #@dialogs[wizard]["help"],
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

    #Function to build a dialog to copy the installation master
    def inst_master_dialog
      @has_back = false
      instmaster_media = local_media().select {|name| name =~ /Instmaster-/}
      if !instmaster_media.empty?
        if !@sap_cds_url.empty?
          # If SAP_CD is mounted from network location, do not allow empty selection
          @content_before_input = VBox(
            Frame(_("Ready for use from:  " + @sap_cds_url),
                  Label(Id(:mediums), Opt(:hstretch), media.join("\n"))),
            Frame(_("Choose an installation master"),
                  Left(ComboBox(Id(:local_im), Opt(:notify),"", instmaster_media))),
          )
        else
          # Otherwise, allow user to enter new installation master
          @content_before_input = Frame(
            _("Choose an installation master"),
            ComboBox(Id(:local_im), Opt(:notify),"", ["---"] + instmaster_media)
          )
        end
      end
      @content_input = HBox(
        ComboBox(Id(:scheme), Opt(:notify), " ", @scheme_list),
        InputField(Id(:location),Opt(:hstretch),
        _("Prepare SAP installation master"),
        @location_cache)
      )
      advanced_ops = [Left(CheckBox(Id(:auto),_("Collect installation profiles for SAP products but do not execute installation."), false))]
      if !@sap_cds_url.empty?
        # link & export options are not applicable if SAP_CD is mounted from network location
        advanced_ops += [
          Left(CheckBox(Id(:export),_("Serve all installation mediums (including master) to local network via NFS."), false))
        ]
      end
      @content_advanced_ops = VBox(*advanced_ops)
      @after_advanced_ops = VBox(
        VSpacing(2.0),
        Left(RadioButton(Id(:skip_copy_medium), Opt(:notify), _("Skip copying of medium")))
      )
      @advanced_ops_left = HSpacing(6.0)
    end

    #Function to build a dialog to copy a sap media
    def sapmedium_dialog
      product_media = local_media().select {|name| !(name =~ /Instmaster-/)}
      if !product_media.empty?
        mediaItems = []
        product_media.each {|medium|
           mediaItems << Item(Id(medium),  medium,  @selected_media.has_key?(medium) ? @selected_media[medium] : true )
        }
        @content_before_input = VBox( MultiSelectionBox(Id("media"), Opt(:notify), _("Ready for use:"), mediaItems) )
      end
      @content_input = VBox(
        Left(RadioButton(Id(:do_copy_medium), Opt(:notify), _("Copy a medium"), true)),
        Left(HBox(
          HSpacing(6.0),
          ComboBox(Id(:scheme), Opt(:notify), " ", @scheme_list),
          InputField(Id(:location),Opt(:hstretch),
              _("Prepare SAP installation medium (such as SAP kernel, database and exports)"),
              @location_cache),
          HSpacing(6.0))),
      )
    end

    #Function to build a dialog to copy a suplementary media
    def supplement_dialog
      product_media = local_media().select {|name| !(name =~ /Instmaster-/)}
      if !product_media.empty?
        @content_before_input = Frame(_("Ready for use:"), Label(Id(:mediums), Opt(:hstretch), product_media.join("\n")))
      end
      @content_input = HBox(
        ComboBox(Id(:scheme), Opt(:notify), " ", @scheme_list),
        InputField(Id(:location),Opt(:hstretch),
        _("Prepare SAP supplementary medium"),
         @location_cache)
      )
    end

    #Sets the default value for location if the scheme was changed
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
      UI.ChangeWidget( :location, :Value, @location_cache )
      if !@sap_cds_url.empty? && wizard == "inst_master"
          # Activate the first installation master option
          UI.ChangeWidget(Id(:scheme), :Value, "dir")
          UI.ChangeWidget(Id(:scheme), :Enabled, false)
          UI.ChangeWidget(Id(:location), :Value, @media_dir + "/" + Convert.to_string(UI.QueryWidget(Id(:local_im), :Value)))
          UI.ChangeWidget(Id(:location), :Enabled, false)
      end
    end

    def do_loop(wizard)
      while true
	user_input = UI.UserInput
        log.info("User Input #{user_input}")
	case user_input
        when :back
            return :back
        when :abort, :cancel
            return :abort
        when :skip_copy_medium
          [:scheme, :location].each { |widget|
            UI.ChangeWidget(Id(widget), :Enabled, false)
          }
          UI.ChangeWidget(Id(:do_copy_medium), :Value, false)
        when :do_copy_medium
          [:scheme, :location].each { |widget|
            UI.ChangeWidget(Id(widget), :Enabled, true)
          }
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
            UI.ChangeWidget(Id(:scheme), :Value, "dir")
            UI.ChangeWidget(Id(:scheme), :Enabled, false)
            UI.ChangeWidget(Id(:location), :Value, @media_dir + "/" + Convert.to_string(UI.QueryWidget(Id(:local_im), :Value)))
            UI.ChangeWidget(Id(:location), :Enabled, false)
        when :scheme
            # Basically re-render layout
            log.info("scheme changed")
            do_default_values(wizard)
        when "media"
          #We have modified the list of selected media
          UI.ChangeWidget(Id(:skip_copy_medium), :Value, true)
          UI.ChangeWidget(Id(:do_copy_medium), :Value, false)
          [:scheme, :location].each { |widget|
            UI.ChangeWidget(Id(widget), :Enabled, false)
          }
        when :next
          #Set the selected Items
          if UI.WidgetExists( Id("media") )
            @selected_media.each_key { |medium|
               @selected_media[medium] = false
            }
            UI.QueryWidget(Id("media"),:SelectedItems).each {|medium|
               @selected_media[medium] = true
            }
            log.info("selected_media #{@selected_media}")
          end

          # Export locally stored mediums over NFS
          @exportSAPCDs = true if !!UI.QueryWidget(Id(:export), :Value)
          # Set installation mode to preauto so that only installation profiles are collected
          @inst_mode = "preauto" if !!UI.QueryWidget(Id(:auto), :Value)

          scheme          = Convert.to_string(UI.QueryWidget(Id(:scheme), :Value))
          @location_cache = Convert.to_string(UI.QueryWidget(Id(:location), :Value))
          @cource_dir     = @location_cache

          if UI.QueryWidget(Id(:skip_copy_medium), :Value)
              return :forw
          end
          # Break the loop for a chosen installation master, without executing check_media
          if UI.WidgetExists(Id(:local_im)) && UI.QueryWidget(Id(:local_im), :Value).to_s != "---"
              return :forw
          end
          urlPath = mount_source(scheme, @location_cache)
          if urlPath != ""
              ltmp    = Builtins.regexptokenize(urlPath, "ERROR:(.*)")
              if Ops.get_string(@ltmp, 0, "") != ""
                  Popup.Error( _("Failed to mount the location: ") + Ops.get_string(@ltmp, 0, ""))
                  next
              end
          end
          if scheme != "local"
              @source_dir = @mount_point +  "/" + urlPath
          elsif urlPath != ""
              @source_dir = urlPath
          end
          @umountSource = true
          log.info("end urlPath #{urlPath}, @source_dir #{@source_dir}, scheme #{scheme}")
          break # No more input
        end # Case user input
      end # While true
      return :next
    end
  end
end
