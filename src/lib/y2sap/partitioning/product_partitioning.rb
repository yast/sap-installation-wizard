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
require "open3"
Yast.import "UI"

module Y2Sap
  # Creates a gui for selecting the SAP NetWeaver installation mode
  # Which products installation mode can be selected depends on the selected media
  module ProductPartitioning
    include Yast
    include Yast::UI
    include Yast::UIShortcuts
    def create_partitions(product_partitioning_list, product_list)
      log.info("********Starting partitioning with #{product_partitioning_list} #{product_list}")
      ret = ""

      hwinfo = hw_info
      manufacturer = Ops.get(hwinfo, 0, "") # "FUJITSU", "IBM", "HP", "Dell Inc."
      model = Ops.get(hwinfo, 1, "") # "PowerEdge R620", "PowerEdge R910"

      product_partitioning_list.each do |product_partitioning|
        part_base = @media.partitioning_dir_base + "/" + product_partitioning
        part_xml = part_base + "_" + manufacturer + "_" + model + ".xml"
        if !File.exist?(part_xml)
          part_xml = part_base + "_" + manufacturer + "_generic.xml"
          if !File.exist?(part_xml)
            part_xml = part_base + ".xml"
          end
        end
        # B1 need to be installed for certified hardware
        if part_xml == part_base + ".xml" && product_list.include?("B1")
          if !Popup.YesNoHeadline(
            _("Your System is not certified for SAP Business One on HANA."),
            _("It is not guaranteed that your system will work properly. \
               Do you want to continue the installation?")
          )
            return :abort
          end
        end
        ret = WFM.CallFunction("sap_create_storage_ng", [part_xml])
        log.info("sap_create_storage_ng returned: #{ret}")
        return :abort if ret == :abort
      end
      log.info("MANUFACTURER: #{manufacturer} Modell: #{model}")
      deep_copy(ret)
    end

    def hana_partitioning
      ret = create_partitions(["hana_partitioning"], ["HANA"])
      show_partitions(_("SAP file system creation successfully done:")) if ret != :abort
    end

    def show_partitions(info)
      partition_table = Table()
      partition_table << Header("device", "mountpoint", "size")
      items = []
      n = 0
      Open3.popen2e("df -h | grep vg_hana") do |i, o, _|
        i.close
        o.each_line do |line|
          fields = line.split
          items << Item(Id(n), fields[0], fields[5], fields[1])
          n = n.next
        end
      end
      n = n.next
      partition_table = Builtins.add(partition_table, items)
      UI.OpenDialog(
        VBox(
          Heading(info),
          MinSize(60, Ops.add(n, 2), partition_table),
          PushButton("&OK")
        )
      )
      ret = UI.UserInput
      UI.CloseDialog
      deep_copy(ret)
    end

  private

    def hw_info
      hwinfo = []
      bios = Convert.to_list(SCR.Read(path(".probe.bios")))
      log.warning("Warning: BIOS list size is %1", Builtins.size(bios)) if bios.size != 1
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
