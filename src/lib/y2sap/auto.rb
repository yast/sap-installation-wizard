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

require "open3"
require "yast"
require "y2sap/configuration/media"
require "y2sap/media/copy"
require "y2sap/media/copy"
require "y2sap/media/find"
require "y2sap/media/mount"

module Y2Sap
  # Represent an AutoYaST module for the installation of SAP products
  class AutoInst < Y2Sap::Configuration::Media
    include Yast
    include Yast::Logger
    include Yast::I18n
    include Y2Sap::MediaCopy
    include Y2Sap::MediaFind
    include Y2Sap::MediaMount

    # Initialize the the global varialbes
    # @return the value of the initialize function of the super class Y2Sap::Configuration::Media
    def initialize
      textdomain "sap-installation-wizard"
      super
    end

    # Implementing the impot function for the auto installation
    # Imports the SAP installation part of the autoyast installation
    # @return [true]
    def import(settings)
      @sap_media_todo = settings
      log.info("-- SAPMedia.Import Start --- #{@sap_media_todo}")
      true
    end

    # Implementing the write function for the auto installation
    # Executes the installation.
    def write
      SCR.Execute(path(".target.bash"), "groupadd sapinst; usermod --groups sapinst root; ")
      @product_count = -1
      @sap_media_todo["products"].each do |prod|
        if !prod.key?("media")
          Yast::Popup.Error("You have to define the location of the installation media in the autoyast xml.")
          next
        end

        reset_variables
        next if !copy_product_media(prod["media"])
        case @inst_master_type
        when "SAPINST"
          prepare_sapinst(prod)
        when "HANA"
          prepare_hana(prod)
        when /^B1/
          prepare_b1(prod)
        when "TREX"
          prepare_trex(prod)
        end
        next if @ERROR
        @script << " -m '#{@inst_dir}/Instmaster' -i '#{@product_id}' -t '#{@DB}' -y '#{@inst_master_type}' -d '#{@inst_dir}'"
	log.info("Starting Installation : #{script}")
        run_script
      end
    end

  private
    # As it is possible to install more then one SAP product in one autoyast
    # installation this function resets the global variables in each loop
    # an increase the @product_count.
    def reset_variables
      @media_list       = []
      @script           = ""
      @product_count    = @product_count.next
      @sid              = ""
      @inst_master_type = ""
      @inst_master_path = ""
      @inst_dir         = "%s/%s" % [ @inst_dir_base, @product_count ]
      @db               = ""
      @product_name     = ""
      @product_id       = ""
      @error            = false
    end

    # Copies the installation media needed for one SAP product.
    def copy_product_media(media)
      media.each do |medium|
        url = medium["url"].split("://")
        url_apth = mount_source(url[0],url[1])
        if "ERROR:" == url_apth[0,6]
          log.info("Can not mount medium #{medium["url"]}. Reason #{url_apth}")
          Yast::Popup.Error("Can not mount medium #{medium["url"]}. Reason #{url_apth}")
          return false
        else
          case medium["type"].downcase
          when "supplement"
            copy_dir(@mount_point, @inst_dir, "Supplement")
            # TODO EXECUTE profile.xml ON MEDIa
          when "sap"
            inst_master_list = is_instmaster(@mount_point)
            if inst_master_list.empty?
              sap_media = find_sap_media(@mount_point)
              sap_media.each { |path,label|
                copy_dir(path, @media_dir, label)
                @media_list << @media_dir + "/" + label
              }
            else
              @inst_master_type = inst_master_list[0]
              @inst_master_path = inst_master_list[1]
              copy_dir(@inst_master_path, @inst_dir, "Instmaster")
              @media_list << @inst_dir + "/" + "Instmaster"
            end
          end
        end
        umount_source()
      end
    end

    # Sets the global variables for an sapinst (NetWeaver) installation evaluated
    # from the autoyast hash.
    def prepare_sapinst(prod)
      @db           = prod.key?("DB")          ? prod["DB"]          : ""
      @product_name = prod.key?("productName") ? prod["productName"] : ""
      @product_id   = prod.key?("productID")   ? prod["productID"]   : ""
      if prod.key?("iniFile")
         File.write(@inst_dir + "/inifile.params",  prod["iniFile"])
      end
      if @product_id == ""
         Yast::Popup.Error("The SAP product_id is not defined.")
         @error = true
         return
      end
      SCR.Execute(path(".target.bash"), "cp " + @ay_dir_base + "/doc.dtd " + @inst_dir)
      SCR.Execute(path(".target.bash"), "cp " + @ay_dir_base + "/keydb.dtd " + @inst_dir)
      File.write(@inst_dir + "/start_dir.cd" , @media_list.join("\n"))
      SCR.Execute(path(".target.bash"), "chgrp sapinst " + @inst_dir + ";" + "chmod 770 " + @inst_dir)
      @script = @ay_dir_base + "/sap_inst_nodb.sh"
    end

    # Sets the global variables for a HANA installation evaluated
    # from the autoyast hash.
    def prepare_hana(prod)
      @db           = "HANA"
      @product_name = @inst_master_type
      @product_id   = @inst_master_type
      if ! prod.key?("sapMasterPW") or ! prod.key?("sid") or ! prod.key?("sapInstNr")
        Yast::Popup.Error("Some of the required parameters are not defined.")
        @error = true
        next
      end
      if ! prod.key?("sapMDC")
        prod["sapMDC"] = "no"
      end
      File.write(@inst_dir + "/ay_q_masterpass", prod["sapMasterPW"])
      File.write(@inst_dir + "/ay_q_sid",        prod["sid"])
      File.write(@inst_dir + "/ay_q_sapinstnr",  prod["sapInstNr"])
      File.write(@inst_dir + "/ay_q_sapmdc",     prod["sapMDC"])
      if prod.key?("sapVirtHostname")
         File.write(@inst_dir + "/ay_q_virt_hostname",     prod["sapVirtHostname"])
      end
      @sid = prod["sid"]
      SCR.Execute(path(".target.bash"), "chgrp sapinst " + @instDir + ";" + "chmod 775 " + @instDir)
      @script = @ay_dir_base + "/hana_inst.sh -g"
    end

    # Sets the global variables for a Busines One installation evaluated
    # from the autoyast hash.
    def prepare_b1(prod)
      prepare_hana(prod)
      @script = @ay_dir_base + "/b1_inst.sh -g"
    end

    # Sets the global variables for a TREX installation evaluated
    # from the autoyast hash.
    def prepare_trex(prod)
      prepare_hana(prod)
      @script = @ay_dir_base + "/trex_inst.sh"
    end

    # Runs the sap installation script.
    def run_script()
      date = `date +%Y%m%d-%H%M`
      logfile = "/var/log/sap_inst." + date + ".log"
      f = File.new(logfile,"w")
      exit_status = nil
      Wizard.SetContents( _("SAP Product Installation"),
        LogView(Id("LOG"),"",30,400),
        "Help",
        true,
        true
      )
      Open3.popen2e(script) do |i,o,t|
        i.close
        n=0
        text=""
        o.each_line do |line|
          f << line
          text << line
          if n > 30
            UI::ChangeWidget(Id("LOG"), :LastLine, text );
            n    = 0
            text = ""
          else
            n = n.next
          end
	end
        exit_status = t.value.exitstatus
      end
      f.close
      log.info("Exit code of script : #{exit_status}")
      if exit_status != 0
        Yast::Popup.Error("Installation failed. For details please check log files at /var/tmp and /var/adm/autoinstall/logs.")
      end
    end
  end
end
