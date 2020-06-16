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
  # Functions for checking the sap media
  module MediaCheck
    include Yast

    def is_instmaster(prod_path)
      log.info("Started MediaCheck is_instmaster #{prod_path}")
      instmaster = []
      if File.exist? prod_path + "/tx_trex_content"
        instmaster[0] = "TREX"
        instmaster[1] = prod_path + "/tx_trex_content/TX_LINUX_X86_64/"
        instmaster[2] = ""
        return instmaster
      end
      log.info("platform arch #{@platform} #{@arch}")
      platform_arch = @platform + "_" + @arch
      platform_arch.upcase!
      search_labelfiles(prod_path).each do |label_file|
        filepath = label_file.split("/")
        IO.readlines(label_file).each do |line|
          fields = line.split(":")
          fields = line.split(" ") if filepath[-1] == "info.txt"
          log.info("is_instmaster,search_labelfiles,fields: #{fields} size #{fields.size}")
          next if fields.size == 0
          #Start checking the label
          if fields[1] =~  /^HANA/
            instmaster[0] = "HANA"
            instmaster[1] = File.dirname(label_file)
            instmaster[2] = fields[2]
            break
          end
          if fields[0] =~ /^B1/
            instmaster[0] = fields[0]
            instmaster[1] = File.dirname(label_file)
            instmaster[2] = fields[1]
            break
          end
          if fields[1] == "SLTOOLSET" && ( fields[5] == platform_arch || fields[5] == "*" )
            instmaster[0] = "SAPINST"
            instmaster[1] = File.dirname(label_file)
            cmd = instmaster[1] + "/sapinst --version 2> /dev/null | grep Version: | gawk '{ print \$2 }'"
            IO.popen(cmd) { |f| instmaster[2] = f.gets }
            instmaster[2].chomp!
            break
          end
          if fields[3] == "SAPINST" && ( fields[5] == platform_arch || fields[5] == "*" )
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
          # TODO: packed SWPM
        end
        break if instmaster.size > 0
      end
      return instmaster
    end

    def get_products_for_media(path)
      log.info("Start MediaCheck get_products_for_media #{path}")
      # First we read all LABEL.ASC files from the selected media
      labels = []
      IO.readlines(path + "/start_dir.cd").each do |medium|
        next if medium =~ /Instmaster/
        labels << IO.readlines(medium.chomp + "/LABEL.ASC")[0].chomp
      end
      packages = ""
      #Now we read the packages file from the intstallation master
      IO.popen(["find",path + "/Instmaster", "-name", "packages.xml"]) do |io|
        packages << io.read                
      end
      log.debug("packages #{packages.size} #{packages}")
      dbm    = ""
      trex   = false
      valid  = []
      log.info("@dbmap #{@dbmap}")
      packages.split("\n").each do |xml_file|
        xml   = IO.read(xml_file.chomp)
        doc   = Nokogiri::XML(xml)
        found = true
        labels.each do |label|
          found_label = false
          label_1     = label.sub(":749:",":74:")
          doc.xpath("/packages/package").each do |node|
            pattern = node.get_attribute("label")
            pattern.gsub!('/', '\/')
            pattern.gsub!('(', '\(')
            pattern.gsub!(')', '\)')
            pattern.gsub!('*', '.*')
            log.debug("pattern #{pattern}  #{label} #{label_1}")
            if label =~ /#{pattern}/ || label_1 =~ /#{pattern}/
              found_label = true
              break
            end
          end
          if !found_label
            found = false
            break
          end
          #check if it is a database media
          @databases.each do |db|
            if ! label.index(db).nil?
              log.debug("db #{db} ##  #{label} ##  #{@dbmap[db]}")
              dbm = @dbmap[db]
              break
            end
          end
        end
        if found
          tmp = xml_file.sub(/^.*Instmaster./,"")
          valid << tmp.sub("/packages.xml","")
        end
      end
      ret = {
        "product_dir" => valid,
        "db"          => dbm,
        "TREX"        => trex
      }
      return ret
    end

  private

    def search_labelfiles(prod_path)
      path   = prod_path.chomp
      labels = ""
      IO.popen(["find", "-L",path, "-name", "LABEL.ASC", "-o", "-name", "info.txt"]) {  |io| 
        labels << io.read
      }
      ret = []
      log.info("labels #{labels}")
      labels.split("\n").each do |label|
        ret << label.chomp    
      end
      log.info("ret #{ret}")
      return ret
    end
  end
end

