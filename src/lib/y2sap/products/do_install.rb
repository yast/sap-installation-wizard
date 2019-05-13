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
require "open3"
require "y2sap/partitioning/product_partitioning"

module Y2Sap

  # Install the selected products.
  module DoInstall
    include Yast
    include ProductPartitioning

    def do_install
      do_collect
      ret = create_partitions(@partitioning_list, @product_list)
      if( ret == "abort" )
        return :abort
      end
      start_install_process
      return :next
    end

    def do_collect
      log.info("-- Start SAPProduct Write --")
      @script_list       = []
      @partitioning_list = []
      @product_list      = []
      @products_to_install.each do |instDir|
        product_data = Convert.convert(
          SCR.Read(path(".target.ycp"), instDir + "/product.data"),
          :from => "any",
          :to   => "map <string, any>"
        )
        params = Builtins.sformat(
          " -m \"%1\" -i \"%2\" -t \"%3\" -y \"%4\" -d \"%5\"",
          Ops.get_string(product_data, "instMaster", ""),
          Ops.get_string(product_data, "product_id", ""),
          Ops.get_string(product_data, "db", ""),
          Ops.get_string(product_data, "type", ""),
          Ops.get_string(product_data, "inst_dir", ""),
        )
        log.info("product_data: #{product_data}")
        # Add script
        @script_list << "/bin/sh -x " + Ops.get_string(product_data, "script_name", "") + params

        # Add product to install
        @product_list << Ops.get_string(product_data, "product_id", "")

        # Add product partitioning
        ret = Ops.get_string(product_data, "partitioning", "")
        if ret == nil
          # Default is base_partitioning
          ret = "base_partitioning"
        end
        @partitioning_list << ret if ret != "NO"
      end
      log.info("To partition: #{@partitioning_list}")
      log.info("To install: #{@product_list}")
      log.info("To execute: #{@script_list}")
    end

    # Start execute the install scripts
    def start_install_process
      require "open3"
      @script_list.each do |intall_script|
	run_script(intall_script)
      end
    end

    # Runs the sap installation script.
    def run_script(script)
      date = `date +%Y%m%d-%H%M`
      logfile = "/var/adm/autoinstall/logs/sap_inst." + date + ".log"
      f = File.new(logfile, "w")
      exit_status = nil
      Wizard.SetContents(
        _("SAP Product Installation"),
        LogView(Id("LOG"), "", 30, 400),
        "Help",
        true,
        true
      )
      Open3.popen2e(script) do |i, o, t|
        i.close
        n = 0
        text = ""
        o.each_line do |line|
          f << line
          text << line
          if n > 30
            UI::ChangeWidget(Id("LOG"), :LastLine, text)
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
        Yast::Popup.Error(
          _("Installation failed. For details please check log files at \
            /var/tmp and /var/adm/autoinstall/logs.")
        )
      end
    end

  end
end
