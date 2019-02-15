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
  module MediaCheck
    include Yast
    def is_instmaster(prod_path)
      instmaster = []
      if File.exist? prod_path + "/tx_trex_content"
	instmaster[0] = "TREX"
	instmaster[1] = prod_path + "/tx_trex_content/TX_LINUX_X86_64/"
	instmaster[2] = ""
	return instmaster
      end
      search_labelfiles(prod_path).each do |label_file|
        filepath = label_file.split("/")
	IO.readlines(label_file).each do |line|
	   fields = line.split(":")
	   fields = line.split(" ") if filepath[-1] == "info.txt"
	   log.info("is_instmaster,search_labelfiles,fields: #{fields}")
	   next if fields.size == 0
	   #Start checking the label
	   if fields[1] =~  /^HANA/
	     instmaster[0] = "HANA"
	     instmaster[1] = File.dirname(label_file)
	     instmaster[2] = ""
	     break
	   end
	   if fields[0] =~ /^B1/
	     instmaster[0] = fields[1]
	     instmaster[1] = File.dirname(label_file)
	     instmaster[2] = ""
	     break
	   end
	   if fields[1] == "SLTOOLSET" && ( fields[5] == @platform + "_" + @arch || fields[5] == "*" )
	     instmaster[0] = "SAPINST"
	     instmaster[1] = File.dirname(label_file)
	     cmd = instmaster[1] + "/sapinst --version 2> /dev/null | grep Version: | gawk '{ print \$2 }'"
	     IO.popen(cmd) { |f| instmaster[2] = f.gets }
	     instmaster[2].chomp!
	     break
	   end
	   if fields[3] == "SAPINST" && ( fields[5] == @platform + "_" + @arch || fields[5] == "*" )
	     instmaster[0] = "SAPINST"
	     instmaster[1] = File.dirname(label_file)
             instmaster[2] = "NW70"
	     break
	   end
	   if fields[1] == "BusinessObjects"
	     instmaster[0] = "BOBJ"
	     instmaster[1] = File.dirname(label_file)
             instmaster[2] = ""
	     break
	   end
	   if fields[1] == "TREX"
             instmaster[0] = ".BOBJ"
	     instmaster[1] = File.dirname(label_file)
             instmaster[2] = ""
	     break
	   end
	   # TODO packed SWPM
	end
	break if instmaster.size > 0
      end
      return instmaster
    end

    def search_labelfiles(prod_path)
      path   = prod_path.chomp
      labels = []
      IO.popen(["find","-L",path,"-name","LABEL.ASC","-o","-name","info.txt"]) {  |io| 
        labels << io.read.chomp
      }
      return labels
    end
  end
end

