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

module Y2Sap
  module MediaComplex
    include Yast
    include Y2Sap::MediaDialog
    include Y2Sap::MediaCopy
    include Y2Sap::MediaFind

    def installation_master
      log.info("Start Y2Sap MediaComplex installation_master ---")
      ret = nil
      run = true
      while run
        ret = media_dialog("inst_master")
        if ret == :abort || ret == :cancel
          if Yast::Popup.ReallyAbort(false)
            Yast::Wizard.CloseDialog
            return :abort
          end
        end
        log.info("looking for instmaster in #{@source_dir}")
        inst_master_list    = is_instmaster(@source_dir)
        @inst_master_type   = Ops.get(inst_master_list, 0, "")
        @inst_master_path   = Ops.get(inst_master_list, 1, "")
        @inst_master_version= Ops.get(inst_master_list, 2, "")

        log.info("found SAP instmaster at #{@inst_master_path} type #{@inst_master_type} version #{@inst_master_version}")
        if @inst_master_path.nil? || @inst_master_path.size == 0
          Yast::Popup.Error(_("The location has expired or does not point to an SAP installation master.\nPlease check your input."))
        else
          run = false
        end
      end
      case @inst_master_type
        when "SAPINST"
          ret = :SAPINST
        when "HANA"
          @inst_master_type = 'HANA'
          ret = :HANA
        when /^B1/
	  @inst_master_type = 'B1'
          ret = :B1
        when "TREX"
          ret = :TREX
      end
      if @inst_master_type == 'HANA' || @inst_master_type == 'B1'
        # HANA and B1 instmaster must copied directly into @inst_dir
        copy_dir(@inst_master_path, @inst_dir, "Instmaster")
        @inst_master_path = @inst_dir + "/Instmaster"
      else
        if ! File.exist?(@media_dir + "/Instmaster-" + @inst_master_type + '-' + @inst_master_version  )
           #Make a local copy of the installation master
           copy_dir(@inst_master_path, @media_dir, "Instmaster-" + @inst_master_type + "-" + @inst_master_version)
        end
        copy_dir(@inst_master_path, @inst_dir, "Instmaster")
        @inst_master_path = @inst_dir + "/Instmaster"
      end
      umount_source()
      return ret
    end

    def net_weaver
      log.info("-- Start net_weaver ---")
      if !@sap_cds_url.empty?
        # Skip the dialog all together if SAP_CD is already mounted from network location
        # There is no chance for user to copy new mediums to the location
        return :next
      end
      run = true
      while run
        case media_dialog("sapmedium")
        when :abort, :cancel
          if Yast::Popup.ReallyAbort(false)
            Yast::Wizard.CloseDialog
            return :abort
          end
        when :back
           return :back
        when :forw
           run = Yast::Popup.YesNo(_("Are there more SAP product mediums to be prepared?"))
        when :next
           #media=Y2Sap::MediaFind.find_sap_media()
           media=find_sap_media()
           media.each { |path,label|
             if File.exist?(@media_dir + "/" + label)
               Yast::Popup.Warning("The selected medium '%s' was already copied." % label)
               next
             end
             #Y2Sap::MediaCopy.copy_dir(path, @media_dir, label)
             copy_dir(path, @media_dir, label)
             @selected_media[label] = true;
           }
           run = Yast::Popup.YesNo(_("Are there more SAP product mediums to be prepared?"))
        end
      end
      mediaList = []
      @selected_media.each_key { |medium|
        if @selected_media[medium]
          mediaList << @media_dir + "/" + medium
        end
      }
      mediaList << @inst_dir + "/" + "Instmaster"
      IO.write(@inst_dir + "/start_dir.cd" , mediaList.join("\n"))
      log.info("End net_weaver #{@inst_dir}" )
      return :next
    end

    def suplementary
      log.info("-- Start ReadSupplementMedium ---")
      run = Yast::Popup.YesNo(_("Do you use a Supplement/3rd-Party SAP software medium?"))
      while run
        ret = media_dialog("supplement")
        if ret == :abort || ret == :cancel
          if Yast::Popup.ReallyAbort(false)
            Yast::Wizard.CloseDialog
            return :abort
          end
        end
        return :back  if ret == :back
        #Y2Sap::MediaCopy.copy_dir(@source_dir, @inst_dir, "Supplement")
        copy_dir(@source_dir, @inst_dir, "Supplement")
        parse_xml(@inst_dir + "/Supplement/product.xml")
        run = Yast::Popup.YesNo(_("Are there more supplementary mediums to be prepared?"))
      end
      return :next
    end
  end
end
