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
  module ProductPartitioning
    include Yast
    def create_partitions(product_partitioning_list, product_list)
      log.info("********Starting partitioning with #{product_partitioning_list} #{product_list}")

      ret = nil
      hwinfo = get_hw_info
      manufacturer = Ops.get(hwinfo, 0, "") # "FUJITSU", "IBM", "HP", "Dell Inc."
      model = Ops.get(hwinfo, 1, "") # "PowerEdge R620", "PowerEdge R910"

      product_partitioning_list.each do |product_partitioning|
        # This is a generic way for all SAP products and hardware
        # Now it is possible to create product manufactutrer and model based partitioning files.
        part_xml = @media.partitioning_dir_base + '/' + product_partitioning + "_" + manufacturer + "_" + model + ".xml"
        if ! File.exist?(part_xml)
          part_xml = @media.partitioning_dir_base + '/' + product_partitioning + "_" + manufacturer + "_generic.xml"
          if ! File.exist?(part_xml)
            part_xml=@media.partitioning_dir_base + '/' + product_partitioning + ".xml"
          end
        end
        ret = WFM.CallFunction( "sap_create_storage_ng", [ part_xml ])
        log.info("sap_create_storage_ng returned: #{ret}")
        if( ret == "abort" )
          return "abort"
        end
      end
      log.info("MANUFACTURER: #{manufacturer} Modell: #{model}")
      deep_copy(ret)
    end

    def hana_partitioning
      create_partitions(["hana_partitioning"],["HANA"])
      show_partitions("SAP file system creation successfully done:")
    end

    def show_partitions(info)
      ret = nil
      partitionTable = Table()
      partitionTable << Header("device", "mountpoint", "fs type", "size")
      items = []
      i = 0
      devmap = Storage.GetTargetMap
      Builtins.foreach(devmap) do |devkey, devvalue|
        if Ops.get_string(devvalue, "name", "") != "tmpfs" &&
            Ops.get_string(devvalue, "device", "") != "tmpfs"
          i = Ops.add(i, 1)
          items = Builtins.add(
            items,
            Item(
              Id(i),
              Ops.get_string(devvalue, "device", ""),
              "",
              "",
              Ops.add(
                Builtins.tostring(
                  Ops.divide(
                    Ops.divide(
                      Builtins.tofloat(Ops.get_integer(devvalue, "size_k", 0)),
                      Convert.convert(1024, :from => "integer", :to => "float")
                    ),
                    Convert.convert(1024, :from => "integer", :to => "float")
                  ),
                  0
                ),
                " G"
              )
            )
          )
        end
        partitions = Ops.get_list(devmap, [devkey, "partitions"], [])
        Builtins.maplist(partitions) do |partition|
          if Ops.get_string(partition, "name", "") != "tmpfs" &&
              Ops.get_string(partition, "device", "") != "tmpfs"
            i = i+1
            items = Builtins.add(
              items,
              Item(
                Id(i),
                Ops.get_string(partition, "device", ""),
                Ops.get_string(partition, "mount", ""),
                Builtins.substring( Builtins.tostring(Ops.get(partition, "detected_fs")), 1),
                Ops.add(
                  Builtins.tostring(
                    Ops.divide(
                      Ops.divide(
                        Builtins.tofloat(
                          Ops.get_integer(partition, "size_k", 0)
                        ),
                        Convert.convert(
                          1024,
                          :from => "integer",
                          :to   => "float"
                        )
                      ),
                      Convert.convert(1024, :from => "integer", :to => "float")
                    ),
                    0
                  ),
                  " G"
                )
              )
            )
          end
        end
      end
      partitionTable = Builtins.add(partitionTable, items)
      UI.OpenDialog(
        VBox(
          Heading(info),
          MinSize(60, Ops.add(i, 2), partitionTable),
          PushButton("&OK")
        )
      )
      ret = UI.UserInput
      UI.CloseDialog
      deep_copy(ret)
    end
   private

    def get_hw_info
      hwinfo = []
      product = ""
      product_vendor = ""
      bios = Convert.to_list(SCR.Read(path(".probe.bios")))

      if Builtins.size(bios) != 1
        Builtins.y2warning("Warning: BIOS list size is %1", Builtins.size(bios))
      end

      biosinfo = Ops.get_map(bios, 0, {})
      smbios = Ops.get_list(biosinfo, "smbios", [])

      sysinfo = {}

      Builtins.foreach(smbios) do |inf|
        sysinfo = deep_copy(inf) if Ops.get_string(inf, "type", "") == "sysinfo"
      end

      if Ops.greater_than(Builtins.size(sysinfo), 0)
        Ops.set(hwinfo, 0, Ops.get_string(sysinfo, "manufacturer", "default"))
        Ops.set(hwinfo, 1, Ops.get_string(sysinfo, "product", "default"))
      end

      deep_copy(hwinfo)
    end
  end
end

