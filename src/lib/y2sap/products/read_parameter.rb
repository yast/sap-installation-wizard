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
require "autoinstall/clients/ayast_setup"

module Y2Sap
  # Read the installation parameter.
  # The product  ay_xml will executed to read the SAP installation parameter
  # The product.data file will be written
  module ReadParameter
    include Yast
    include Yast::UI
    include Yast::UIShortcuts
    include Y2Autoinstall::Clients::AyastSetup

    def read_product_parameter
      log.info("Start read_product_parameter")
      init_envinroment
      log.info("@db #{@db} @product_name #{@product_name} @product_id #{@product_id}")
      eval_product_ay
      setup_installation_enviroment
      if Yast::Popup.YesNo(_("Installation profile is ready.\n" +
          "Are there more SAP products to be prepared for installation?"))
        @media.product_count = @media.product_count.next
        @media.inst_dir = "%s/%d" % [ @media.inst_dir_base, @media.product_count ]
        SCR.Execute(path(".target.bash"), "mkdir -p " + @media.inst_dir )
        log.info("read_product_parameter returned :read_im")
        return :read_im
      end
      return :next
    end

    # initialize some variables
    def init_envinroment
       @sid          =""
       @inst_number  =""
       hostname_out = Convert.to_map( SCR.Execute(path(".target.bash_output"), "hostname"))
       @my_hostname = Ops.get_string(hostname_out, "stdout", "")
       @my_hostname.strip!

      # For HANA B1 and  TREX there is no @db @product_name and @product_id set at this time
      case @media.inst_master_type
        when /^HANA/
           @db           = "HDB"
           @product_name = "HANA"
	   @product_id   = @media.inst_master_version == "1.0" ? "HANA1.0" : "HANA"
        when /^B1/
           @db           = ""
           @product_name = "B1"
           @product_id   = "B1"
        when "TREX"
           @db           = ""
           @product_name = "TREX"
           @product_id   = "TREX"
      end
    end

  private

    # Evaluates the autoyast file of the product
    def eval_product_ay
      # Display the empty dialog before running external SAP installer program
      Wizard.SetContents(
        _("Collecting installation profile for SAP product"),
        VBox(
            Top(Left(Label(_("Please follow the on-screen instructions of SAP installer (external program)."))))
        ),
        "",
        true,
        true
      )
      Wizard.RestoreAbortButton()
      # First we execute the autoyast xml file of the product if this exeists
      xml_path = get_product_parameter("ay_xml") == "" ? "" : @media.ay_dir_base + "/" +  get_product_parameter("ay_xml")
      if @product_name == "B1"
              SCR.Execute(path(".target.bash"), @media.sapinst_path + "/b1_hana_list.sh " + @media.inst_dir + " " + @media.ay_dir_base )
      end
      if File.exist?( xml_path )
        SCR.Execute(path(".target.bash"), "sed -i s/##VirtualHostname##/" + @my_hostname + "/g " + xml_path )
	#WFM.CallFunction("ayast_setup", ["setup","filename="+xml_path, "dopackages=yes" ] )
        ret = openFile({ "filename" => xml_path, "dopackages" => "yes" })
        log.info("ayast_setup returned for: " + xml_path)
        if File.exist?("/tmp/ay_q_sid")
           @sid = IO.read("/tmp/ay_q_sid").chomp
        end
        if File.exist?("/tmp/ay_q_sapinstnr")
           @inst_number = IO.read("/tmp/ay_q_sapinstnr").chomp
        end
        SCR.Execute(path(".target.bash"), "mv /tmp/ay_* " + @media.inst_dir )
      end
    end

    # writes the product parameter in the product directory
    # This is @media.inst_dir
    # For SAP NW products the initfile.params file will be adapted.
    # Furthermore doc.dtd and keydb.dtd files will be copied into @media.inst_dir
    # For all SAP products the @media.inst_dir/product.data hash will be written
    def setup_installation_enviroment
      inifile_params = get_product_parameter("inifile_params") == "" ? ""   : @media.ay_dir_base + "/" +  get_product_parameter("inifile_params")

      # inifile_params can be contains db-name
      inifile_params = inifile_params.gsub("##DB##",@db)

      # Create the parameter.ini file
      if File.exist?(inifile_params)
        inifile = File.read(inifile_params)
        Dir.glob(@media.inst_dir + "/ay_q_*").each do |param|
           par = param.gsub(/^.*\/ay_q_/,"")
           val = IO.read(param).chomp
           pattern = "##" + par + "##"
           inifile.gsub!(/#{pattern}/,val)
        end
        # Replace ##VirtualHostname## by the real hostname.
        inifile.gsub!(/##VirtualHostname##/,my_hostname)
        # Replace kernel base
        File.readlines(@media.inst_dir + "/start_dir.cd").each do |path|
          if path.include?("KERNEL")
            inifile.gsub!(/##kernel##/,path.chomp)
            break
          end
        end
        File.write(@media.inst_dir + "/inifile.params",inifile)
      end
      if @media.inst_master_type == "SAPINST"
        SCR.Execute(path(".target.bash"), "cp " + @media.ay_dir_base + "/doc.dtd "   + @media.inst_dir)
        SCR.Execute(path(".target.bash"), "cp " + @media.ay_dir_base + "/keydb.dtd " + @media.inst_dir)
      end

      #Write the product.data file
      script_name    = @media.sapinst_path + "/" +  get_product_parameter("script_name")
      partitioning   = get_product_parameter("partitioning")   == "" ? "NO" : get_product_parameter("partitioning")
      SCR.Write( path(".target.ycp"), @media.inst_dir + "/product.data",  {
        "inst_dir"     => @media.inst_dir,
        "inst_master"  => @media.inst_dir + "/Instmaster",
        "type"         => @media.inst_master_type,
        "db"           => @db,
        "product_name" => @product_name,
        "product_id"   => @product_id,
        "partitioning" => partitioning,
        "sid"          => @sid,
        "instnumber"   => @inst_number,
        "script_name"  => script_name
      })

      @products_to_install << @media.inst_dir
      # Adapt the rights of the installation directory
      inst_dir_mode = @media.inst_master_type == "SAPINST" ? "770" : "775"
      cmd = "groupadd sapinst; " +
            "usermod --groups sapinst root; " +
            "chgrp sapinst " + @media.inst_dir + ";" +
            "chmod " + inst_dir_mode + " " + @media.inst_dir + ";"
      log.info("-- Prepare sapinst #{cmd}" )
      SCR.Execute(path(".target.bash"), cmd)
    end

    # @return [String] read a value from the product list
    def get_product_parameter(product_parameter)
      log.info("get_product_parameter #{product_parameter} #{@product_id}")
      @product_list.each do |p|
        if p["id"] == @product_id
          log.info("get_product_parameter foud parameter #{p[product_parameter]}")
          return p.key?(product_parameter) ? p[product_parameter] : ""
        end
      end
      return ""
    end
  end
end
