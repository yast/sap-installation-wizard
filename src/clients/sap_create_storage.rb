# encoding: utf-8

module Yast
  class SapCreateStorageClient < Client
    def main
      Yast.import "UI"
      Yast.import "AutoinstStorage"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Stage"
      Yast.import "Storage"
      Yast.import "Wizard"
      Yast.import "XML"
      Yast.import "AutoinstLVM"
      Yast.import "AutoinstRAID"

      textdomain "installation"

      @i = 0 #temp counter
      @devices = 0 #number of found free devices
      @neededLVG = [] #The list of the LVG have to be created
      @ltmp = [] #temp list
      @freeDevices = {} #Device name of physikal drives with free spaces
      @cylSize = {} #Device cylinder size
      @profile = {}
      @LVGs = {}
      @profiles = {}
      @LVGsize = {}
      @SWAP = {}
      @closeMe = false

      @needSWAP = true
      if `cat /proc/swaps | wc -l`.to_i > 1
         @needSWAP = false
      end

      # **********************************************
      # Start the program.
      # **********************************************
      @args = WFM.Args
      if Builtins.size(@args) == 0
        Builtins.y2error("No argument for the partitioning")
        return :abort
      end

      xmlFile = Ops.get_string(@args, 0, "")
      if !File.exists?(xmlFile)
        Builtins.y2error("Partitioning file does not exists.")
        return :abort
      end

      if !Wizard.IsWizardDialog
         Wizard.CreateDialog
         @closeMe = true
      end
      #Read the proposed XML
      @profile = XML.XMLToYCPFile(xmlFile)
      Builtins.y2milestone("Read Partitioning profile %1", @profile)

      #If the partitioning is predefined do it and go ahaed
      if Ops.get_boolean(@profile, "partitioning_defined", false)
        Wizard.SetContents(_("Processing Partitioning"),RichText(("Processing Storage Partitioning. Depending on your system this may take some time.")),"",false,false)
        Storage.GetTargetMap
        Stage.Set("initial")
        Mode.SetMode("autoinstallation")
        AutoinstStorage.Import(Ops.get_list(@profile, "partitioning", []))
        AutoinstStorage.Write
        AutoinstLVM.Write if AutoinstLVM.Init
        AutoinstRAID.Write if AutoinstRAID.Init
        Storage.CommitChanges
        return :next
      end
      #Get Memory Size in bytes
      @memories = Convert.to_list(SCR.Read(path(".probe.memory")))
      @memory = Ops.get_integer(
        @memories,
        [0, "resource", "phys_mem", 0, "range"],
        0
      )
      #reed the mtab
      @mounts = Convert.convert(
        SCR.Read(path(".etc.mtab")),
        :from => "any",
        :to   => "list <map>"
      )
      @i = -1
      Builtins.foreach(Ops.get_list(@profile, "partitioning", [])) do |drive|
        Builtins.y2milestone("getDrive %1", drive)
        @i = Ops.add(@i, 1)
        if Ops.get_boolean(drive, "is_lvm_vg", false)
          @ltmp = Builtins.regexptokenize(
            Ops.get_string(drive, "device", ""),
            "/dev/(.*)"
          )
          n = Ops.get_string(@ltmp, 0, "")
          #Evaluate if some of the needed LVG was already created
          mountPoint = Ops.get_string(
            drive,
            ["partitions", 0, "mount"],
            ""
          )
          created = false
          Builtins.foreach(@mounts) do |dev|
            created = true if Ops.get_string(dev, "file", "") == mountPoint
          end
          next if created

          @neededLVG = Builtins.add(@neededLVG, n)
          s = Ops.get_string(drive, ["partitions", 0, "size_min"], "max")
          @ltmp = Builtins.regexptokenize(s, "RAM.(.*)")
          if Ops.get_string(@ltmp, 0, "") != ""
            s = Builtins.tostring(
              Ops.multiply(
                Builtins.tointeger(Ops.get_string(@ltmp, 0, "")),
                @memory
              )
            )
            Ops.set(
              @profile,
              ["partitioning", @i, "partitions", 0, "size_min"],
              s
            )
          end
          Ops.set(@LVGs, n, Ops.get(@profile, ["partitioning", @i]))
        else
           @SWAP = Ops.get(@profile, ["partitioning", @i])
        end
      end
      Builtins.y2milestone(
        "Partitioning profile after parsing partition sizes %1",
        @profile
      )
      Builtins.y2milestone("LVGs after parsing partition sizes %1", @LVGs)
      Builtins.y2milestone("SWAPS after parsing partition sizes %1", @SWAP)

      #Read the device list
      @d = Storage.GetTargetMap
      Builtins.y2milestone("target map %1", @d)
      @d.each { |dev| 
         Builtins.y2milestone("TARGETMAP %1", dev)
      }
      Builtins.foreach(@d) do |name, dev|
        type = Ops.get_symbol(dev, "type")
        Builtins.y2milestone("DEVICE name %1 type %2 used_by", name, type,  Ops.get_map(dev, "used_by", {}) )
        if type == :CT_DISK
          next if Ops.get_map(dev, "used_by", {}) != {}
        elsif type != :CT_DMMULTIPATH
          next
        end
        Builtins.y2milestone("disk %1", name)
        slots = []
        slots_ref = arg_ref(slots)
        Storage.GetUnusedPartitionSlots(name, slots_ref)
        slots = slots_ref.value
        free = 0
        Builtins.y2milestone("SLOTS %1",slots)
        Builtins.foreach(slots) do |slot|
          free = free + Ops.get_integer(slot, [:region, 1], 0) * Ops.get_integer(dev, "cyl_size", 0)
          Builtins.y2milestone("Free device %1 region %2 cyl_size %3 free %4",  name , Ops.get_integer(slot, ["region", 1], 0), Ops.get_integer(dev, "cyl_size", 0), free )
        end
        if Ops.greater_than(free, 1073741824)
          Ops.set(@cylSize, name, Ops.get_integer(dev, "cyl_size", 0))
          Ops.set(@freeDevices, name, free)
          @devices = Ops.add(@devices, 1)
        end
      end
      Builtins.y2milestone("freeDevices %1", @freeDevices)
      if @devices == 0
        Popup.Error("There is no available disk space left.")
        return false
      elsif @devices == 1
        @dev = ""
        @sdev = 0
        @slvg = "max"
        Builtins.foreach(@freeDevices) do |d, t|
          @dev = d
          @sdev = Ops.get(@freeDevices, d, 0)
        end
        Builtins.y2milestone("Selecting the free device %1", @dev)
        Builtins.foreach(@neededLVG) do |_LVG|
          rat = Ops.get_integer(@LVGs, [_LVG, "partitions", 0, "size_ratio"])
          if rat != nil
            @slvg = Builtins.tostring(
              Ops.multiply(
                Ops.divide(
                  Ops.subtract(
                    Ops.divide(
                      Ops.multiply(
                        Ops.multiply(
                          Ops.divide(Ops.get(@freeDevices, @dev, 0), 4096),
                          4096
                        ),
                        rat
                      ),
                      100
                    ),
                    Ops.get(@cylSize, @dev, 1048576)
                  ),
                  Ops.get(@cylSize, @dev, 1048576)
                ),
                Ops.get(@cylSize, @dev, 1048576)
              )
            )
            Ops.set(@LVGsize, _LVG, Builtins.tointeger(@slvg))
          else
            Ops.set(@LVGsize, _LVG, @sdev)
          end
          Ops.set(@LVGs, [_LVG, "partitions", 0, "size"], @slvg)
          Ops.set(
            @profiles,
            _LVG,
            Builtins.add(
              [Ops.get_map(@LVGs, _LVG, {})],
              {
                "device"     => @dev,
                "use"        => "free",
                "type"       => :CT_DISK,
                "partitions" => [
                  {
                    "create"       => true,
                    "lvm_group"    => _LVG,
                    "partition_id" => 142,
                    "size"         => @slvg
                  }
                ]
              }
            )
          )
        end
      else
         ret = selectDevices()
         if ret == :abort or ret == :back  
           Wizard.CloseDialog() if @closeMe
           return ret
         end
      end

      Builtins.y2milestone("Notre profiles %1", @profiles)

      #Check if the minimal sizes was met
      back = true
      while back
        Builtins.foreach(@neededLVG) do |_LVG|
          min = Builtins.tointeger(
            Ops.get_string(@LVGs, [_LVG, "partitions", 0, "size_min"], "0")
          )
          if Ops.greater_than(min, Ops.get(@LVGsize, _LVG, 0))
            min = Ops.divide(Ops.divide(Ops.divide(min, 1024), 1024), 1024)
            have = Ops.divide(
              Ops.divide(Ops.divide(Ops.get(@LVGsize, _LVG, 0), 1024), 1024),
              1024
            )
            message = _("<size=30><b><color=red>Warning</color></b></size><br>")
            message << Builtins.sformat(_("There is less disk space than recommended for this LVG %1.<br>"), _LVG)
            message << Builtins.sformat(_("The recommended amount of %1 GB is not available.<br>"), min )
            message << Builtins.sformat(_("The total currently available amount of %1 GB will be used instead if you push <b>Next</b>.<br>"), have )
            message << Builtins.sformat(_("Otherwise you can abort the installation or go back to select different partitions for the LVG %1."), _LVG )
            Wizard.SetContents(_("Select the Partitions for the System"),RichText(message),"",true,true)
            while true
              event = UI.WaitForEvent
              ret = Ops.get(event, "ID")
              Builtins.y2milestone("Got event %1", ret)
              case ret
              when :abort
                Wizard.CloseDialog() if @closeMe
                return :abort
              when :back
		back = true
                break
              when :next
                back = false
                break
              end
            end
          else
            back = false
          end
          break if back
        end
        if back
          ret = selectDevices()
          if ret == :abort or ret == :back  
             Wizard.CloseDialog() if @closeMe
             return ret
          end
        end
      end

      #First we are creating the swap if necessary or resizing it
      if @needSWAP
        Wizard.SetContents(_("Processing Partitioning"),RichText(_("The SWAP partiton will be created. Depending on your system this may take some time.")),"",false,false)
        Stage.Set("initial")
        Mode.SetMode("autoinstallation")
        AutoinstStorage.Import(Ops.get_list(@profiles, "SWAP", []))
        AutoinstStorage.Write
        AutoinstLVM.Write if AutoinstLVM.Init
        AutoinstRAID.Write if AutoinstRAID.Init
        Storage.CommitChanges
      else
	if File.exists?( "/dev/mapper/system-swap" )
           swapSIZE = Ops.get_string(@SWAP, ["partitions", 0, "size"], "2G")
           command  = "swapoff /dev/mapper/system-swap; "
	   command << "lvresize  -L " << swapSIZE << "/dev/mapper/system-swap; "
	   command << "mkswap /dev/mapper/system-swap; "
           command  = "swapon /dev/mapper/system-swap; "
           SCR.Execute(path(".target.bash"), command )
	end
      end

      #Now we are creating the needed LVMs
      Builtins.foreach(@neededLVG) do |_LVG|
        Wizard.SetContents(_("Processing Partitioning"), RichText(Builtins.sformat(_("The LVM %1 will be created. Depending on your system this may take some time."),_LVG)),"",false,false)
        Stage.Set("initial")
        Mode.SetMode("autoinstallation")
        AutoinstStorage.Import(Ops.get_list(@profiles, _LVG, []))
        AutoinstStorage.Write
        AutoinstLVM.Write if AutoinstLVM.Init
        AutoinstRAID.Write if AutoinstRAID.Init
        Storage.CommitChanges
      end

      Wizard.CloseDialog() if @closeMe
      :next
    end

    # **********************************************
    # Function to select the devices for the VLG-s
    # **********************************************
    def selectDevices
      items = VBox()

      Builtins.foreach(@neededLVG) do |_LVG|
        buttons = VBox()
        Builtins.foreach(@freeDevices) do |dev, tmp|
          tmp1 = Ops.add(Ops.add(Ops.add("CHECK", _LVG), "#"), dev)
          tmp2 = Builtins.sformat("%1 %2GB",dev, Ops.get(@freeDevices, dev, 0) / 1024 / 1024 /1024 )
          buttons = Builtins.add(
            buttons,
            Left(CheckBox(Id(tmp1), Opt(:notify), tmp2, false))
          )
        end
        item = Frame(
          Ops.add(
            Ops.add("Select the Devices for '", _LVG),
            "' Logical Volume Group"
          ),
          HBox(buttons)
        )
        items = Builtins.add(items, item)
      end
      if @needSWAP
        buttons = VBox()
        Builtins.foreach(@freeDevices) do |dev, tmp|
          tmp1 = Ops.add("SWAP#", dev)
          tmp2 = Builtins.sformat("%1 %2GB",dev, Ops.get(@freeDevices, dev, 0) / 1024 / 1024 /1024 )
          buttons = Builtins.add(
            buttons,
            Left(CheckBox(Id(tmp1), Opt(:notify), tmp2, false))
          )
        end
        item = Left(Frame("Select one Device for SWAP", HBox(buttons)))
        items = Builtins.add(items, item)
      end

      Wizard.SetContents(_("Select the Partitions for the System"),items,"",true,true)

      while true
        event = UI.WaitForEvent
        ret = Ops.get(event, "ID")
        sret = Ops.get_string(event, "ID") if Ops.is_string?(ret)
        Builtins.y2milestone("Got event %1", ret)
        case ret
	when :abort
          Wizard.CloseDialog() if @closeMe
          return :abort
	when :back
          Wizard.CloseDialog() if @closeMe
          return :back
        when :next
          selectedLVDDev  = 0
          selectedSWAPDev = 0
          Builtins.foreach(@neededLVG) do |_LVG|
            Ops.set(@profiles, _LVG, [Ops.get_map(@LVGs, _LVG, {})])
            Builtins.foreach(@freeDevices) do |dev, tmp|
              wid = Ops.add(Ops.add(Ops.add("CHECK", _LVG), "#"), dev)
              if Convert.to_boolean(UI.QueryWidget(Id(wid), :Value))
		selectedLVDDev += 1
                Ops.set(
                  @LVGsize,
                  _LVG,
                  Ops.add(
                    Ops.get(@LVGsize, _LVG, 0),
                    Ops.get(@freeDevices, dev, 0)
                  )
                )
                Ops.set(
                  @profiles,
                  _LVG,
                  Builtins.add(
                    Ops.get_list(@profiles, _LVG, []),
                    {
                      "device"     => dev,
                      "use"        => "free",
                      "type"       => :CT_DISK,
                      "partitions" => [
                        {
                          "create"       => true,
                          "lvm_group"    => _LVG,
                          "partition_id" => 142,
                          "size"         => "max"
                        }
                      ]
                    }
                  )
                )
              end
            end
          end
          if @needSWAP
            Builtins.foreach(@freeDevices) do |dev, tmp|
              wid = Ops.add("SWAP#", dev)
	      if Convert.to_boolean(UI.QueryWidget(Id(wid), :Value))
                 selectedSWAPDev += 1
                 @SWAP["device"] = dev
		 Ops.set(@profiles,"SWAP",Builtins.add([],@SWAP))
                 break     
	      end
            end
          end
          if @needSWAP and selectedSWAPDev == 0
		Popup.Warning(_("You have to select at last one device for SWAP"))
	  elsif @neededLVG.count > 0 and selectedLVDDev == 0
		Popup.Warning(_("You have to select at last one device for LVG"))
	  else
              return true
	  end
	when /SWAP#/
          @ltmp = Builtins.regexptokenize(sret, "SWAP#(.*)")
          Builtins.foreach(@neededLVG) do |_LVG|
            if Convert.to_boolean(UI.QueryWidget(Id(ret), :Value))
              UI.ChangeWidget( Id( Ops.add( Ops.add(Ops.add("CHECK", _LVG), "#"), Ops.get_string(@ltmp, 0, ""))), :Enabled, false)
            else
              UI.ChangeWidget( Id( Ops.add( Ops.add(Ops.add("CHECK", _LVG), "#"), Ops.get_string(@ltmp, 0, ""))), :Enabled, true)
            end
          end
        when /CHECK/
          @ltmp = Builtins.regexptokenize(sret, "CHECK(.*)#(.*)")
          if @needSWAP
              if Convert.to_boolean(UI.QueryWidget(Id(ret), :Value))
                 UI.ChangeWidget(Id(Ops.add("SWAP#", Ops.get_string(@ltmp, 1, ""))),:Enabled,false)
              else
                 UI.ChangeWidget(Id(Ops.add("SWAP#", Ops.get_string(@ltmp, 1, ""))),:Enabled,true)
              end
	  end
          Builtins.foreach(@neededLVG) do |_LVG|
            if Ops.get_string(@ltmp, 0, "") != _LVG
              if Convert.to_boolean(UI.QueryWidget(Id(ret), :Value))
                UI.ChangeWidget( Id( Ops.add( Ops.add(Ops.add("CHECK", _LVG), "#"), Ops.get_string(@ltmp, 1, ""))), :Enabled, false)
              else
                UI.ChangeWidget( Id( Ops.add( Ops.add(Ops.add("CHECK", _LVG), "#"), Ops.get_string(@ltmp, 1, ""))), :Enabled, true)
              end
            end
          end
        else
           Builtins.y2milestone("Unknown re %1", ret)
        end
      end
      nil
    end
  end
end

Yast::SapCreateStorageClient.new.main
