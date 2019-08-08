# encoding: utf-8
# Authors: Peter Varkoly <varkoly@suse.com>, Howard Guo <hguo@suse.com>

# ex: set tabstop=4 expandtab:
# vim: set tabstop=4:expandtab
require "yast"
require "fileutils"

module Yast
  class SAPPartitioningClass < Module
    def main
      Yast.import "UI"
      Yast.import "Misc"
      textdomain "sap-installation-wizard"
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("SAP Partitioning started")

      @partXMLPath = Misc.SysconfigRead(
        path(".sysconfig.sap-installation-wizard.PART_XML_PATH"),
        "/usr/share/YaST2/include/sap-installation-wizard"
      )
    end

    def CreatePartitions(productPartitioningList,productList)
      Builtins.y2milestone("********Starting partitioning")

      ret = nil
      hwinfo = get_hw_info
      manufacturer = Ops.get(hwinfo, 0, "") # "FUJITSU", "IBM", "HP", "Dell Inc."
      model = Ops.get(hwinfo, 1, "") # "PowerEdge R620", "PowerEdge R910"

      Builtins.foreach(productPartitioningList) do |productPartitioning|
        # This is a generic way for all SAP products and hardware
        # Now it is possible to create product manufactutrer and model based partitioning files.
        partXML = @partXMLPath + '/' + productPartitioning + "_" + manufacturer + "_" + model + ".xml"
        if ! File.exist?(partXML)
            partXML = @partXMLPath + '/' + productPartitioning + "_" + manufacturer + "_generic.xml"
           if ! File.exist?(partXML)
               partXML=@partXMLPath + '/' + productPartitioning + ".xml"
               if productList.include?('B1')
                  if ! Popup.YesNoHeadline(_("Your System is not certified for SAP Business One on HANA."),
                      _("It is not guaranteed that your system will work properly. Do you want to continue the installation?"))
                      return "abort"
                  end
               end
           end
        end
        ret = WFM.CallFunction( "sap_create_storage", [ partXML ])
        Builtins.y2milestone("sap_create_storage_ng returned: %1",ret)
	if( ret == "abort" )
	    return "abort"
	end
      end
      Builtins.y2milestone("MANUFACTURER: %1", manufacturer)
      Builtins.y2milestone("Modell: %1", model)
      deep_copy(ret)
    end

    def ShowPartitions(info)
      ret = nil
      partitionTable = Table()
      partitionTable = Builtins.add(
        partitionTable,
        Header("device", "mountpoint", "fs type", "size")
      )
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

    def CreateHANAPartitions(void)
        CreatePartitions(["hana_partitioning"],["HANA"])
        ShowPartitions("SAP file system creation successfully done:")
    end

    #Published functions
    publish :function => :CreatePartitions,    :type => "void()"
    publish :function => :ShowPartitions,      :type => "string()"
    publish :function => :CreateHANAPartitions,:type => "void()"

    # Published module variables
    publish :variable => :partXMLPath,       :type => "string"

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
  SAPPartitioning = SAPPartitioningClass.new
  SAPPartitioning.main

end

