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

      textdomain "sap-installation-wizard"

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
      if @profile == nil
        Builtins.y2error("Partitioning file does not contain valid XML data.")
        return :abort
      end

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
      Builtins.y2milestone("Available memory %1", @memory)

      #Read the mtab
      @mounts = Convert.convert(
        SCR.Read(path(".etc.mtab")),
        :from => "any",
        :to   => "list <map>"
      )

      i = -1 #Counter for the partition

      #Read the partitiong section from the xml
      Builtins.foreach(Ops.get_list(@profile, "partitioning", [])) do |drive|
        Builtins.y2milestone("getDrive %1", drive)
        i = Ops.add(i, 1)
        if Ops.get_boolean(drive, "is_lvm_vg", false)
          device = Ops.get_string(drive, "device", "")
	  device = device.scan(/\/dev\/(.*)/)[0][0]

          #Evaluate the partitions
          j = -1
	  @created = false
          Builtins.foreach(Ops.get_list(drive, "partitions", [])) do |partition|
             j = Ops.add(j, 1)
             #Evaluate if some of the needed LVG was already created
             mountPoint = Ops.get_string( drive, ["partitions", j, "mount"], "")
             Builtins.foreach(@mounts) do |dev|
               @created = true if Ops.get_string(dev, "file", "") == mountPoint
             end
             #If the mount point already exists we do not need to do anything for this partition
             #
             break if @created

	     #Evaluate the min size of the partition
             size  = Ops.get_string(drive, ["partitions", j, "size_min"], "")
             @ltmp = Builtins.regexptokenize(size, "RAM.(.*)")
	     minSize = Ops.get_string(@ltmp, 0, "")
             if minSize != ""
               Builtins.y2milestone("Special size %1 on partition %2", minSize, partition )
	       minSize = minSize.to_f * @memory
               Ops.set( @profile, ["partitioning", i, "partitions", j, "size_min"], minSize)
	     else
	       minSize = 1000*1000*1000
	     end
             #Evaluate the max size of the partition
             maxSize = Ops.get_string(drive, ["partitions", j, "size_max"], "")
             size  = Ops.get_string(drive, ["partitions", j, "size"], "")
             sizeAux = getDimensionedValue(size)
       
             #if the size_max is not informed, we assume the bigger of min or size tag.
             # This is an workaround for the default value of 1 GB.
             # TODO: Refactor this logic.
             if maxSize == ""
                if ((sizeAux != nil) && (sizeAux > minSize))
                  maxSize = sizeAux.to_f
                else
                  maxSize = minSize.to_f
                end
             else
                maxSize = getDimensionedValue(maxSize)
             end
             Ops.set( @profile, ["partitioning", i, "partitions", j, "size_max"], maxSize)

             if size == ""
	        if minSize > maxSize
                   size = maxSize/1000/1000/1000
                   Ops.set( @profile, ["partitioning", i, "partitions", j, "size"], size.to_s + "G")
	        else
                   size = minSize/1000/1000/1000
                   Ops.set( @profile, ["partitioning", i, "partitions", j, "size"], size.to_s + "G" )
	        end
	     end
             size  = Ops.get_string(drive, ["partitions", j, "size_min"], "")
	     if size == ""
                size = Ops.get_string(drive, ["partitions", j, "size"], "")
                size = getDimensionedValue(size)
                Ops.set( @profile, ["partitioning", i, "partitions", j, "size_min"], size)
	     end
          end #END foreach partitions partition
          @neededLVG << device if !@created
          Ops.set(@LVGs, device, Ops.get(@profile, ["partitioning", i]))
        else
           @SWAP = Ops.get(@profile, ["partitioning", i])
        end
      end #END foreach @profile partitioning

      if @neededLVG == []
         if Popup.YesNo(_("The required partitions are already created. Do you want to continue?"))
            return "ok"
	 else
            return "abort"
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
      Builtins.foreach(@d) do |name, dev|
        free = 0
        type       = Ops.get_symbol(dev, "type")
        partitions = Ops.get_list(dev, "partitions")
	Builtins.y2milestone("TARGETMAP %1", dev)
	Builtins.y2milestone("DEVICE name %1 type %2 used_by", name, type,  Ops.get_list(dev, "used_by", []) )
        if type == :CT_DISK
          next if Ops.get_list(dev, "used_by", []) != []
        elsif type != :CT_DMMULTIPATH
          next
        end
	if partitions != []
           slots = []
           slots_ref = arg_ref(slots)
           Storage.GetUnusedPartitionSlots(name, slots_ref)
           slots = slots_ref.value
           Builtins.y2milestone("SLOTS %1",slots)
           Builtins.foreach(slots) do |slot|
	     cylinders = Ops.get_integer(slot, [:region, 1], 0)
             free = free + ( cylinders * Ops.get_integer(dev, "cyl_size", 0) )
             Builtins.y2milestone("Free device %1 cylinders %2 cyl_size %3 free %4",  name , cylinders, Ops.get_integer(dev, "cyl_size", 0), free )
           end
	else
	   free = Ops.get_integer(dev, "size_k", 0) * 1024
	end
        if free > 1073741824
          Ops.set(@cylSize, name, Ops.get_integer(dev, "cyl_size", 0))
          Ops.set(@freeDevices, name, free)
          @devices = @devices + 1
        end
      end
      Builtins.y2milestone("freeDevices %1", @freeDevices)
      if @devices == 0
	if Popup.YesNoHeadline(_("Do you want to continue the installation?"),
		               _("Your system does not meet the requirements. There is no guarantee that the system will work properly."))
	    return "ok"
        else
            return "abort"
        end
      elsif @devices == 1
        @dev = ""
        Builtins.foreach(@freeDevices) do |d, t|
          @dev = d
        end
        Builtins.y2milestone("Selecting the free device %1", @dev)
        Builtins.foreach(@neededLVG) do |_LVG|
	  Ops.set( @LVGsize, _LVG, Ops.get(@freeDevices, @dev, 0) )
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
                    "size"         => "max"
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
      Builtins.y2milestone("@LVGs %1", @LVGs)

      #Check if the minimal sizes was met
      back = true
      while back
        Builtins.foreach(@neededLVG) do |_LVG|
	  min = 0
          Builtins.foreach(Ops.get_list(@LVGs, [_LVG, "partitions"], [])) do |partition|
              Builtins.y2milestone("Partition %1", partition)
	      next if partition["size_min"] == nil
              min = min + partition["size_min"]
	  end
          Builtins.y2milestone("Checking _LVG %1 min: %2 size %3", _LVG, min, Ops.get(@LVGsize, _LVG, 0))
          if min > Ops.get(@LVGsize, _LVG, 0)
            min  = min/1000/1000/1000
            have = Ops.get(@LVGsize, _LVG, 0)/1000/1000/1000
            message = _("<size=30><b><color=red>Warning</color></b></size><br>")
	    message << _("Your system does not meet the requirements.")
            message << Builtins.sformat(_("There is less disk space than recommended for this LVG %1.<br>"), _LVG)
            message << Builtins.sformat(_("The recommended amount of %1 GB is not available.<br>"), min )
            message << Builtins.sformat(_("The total currently available amount %1 GB can not be used for the SAP installation.<br>"), have )
            message << _("There is no guarantee that the system will work properly if you continue the installation.")
	    if( @devices > 1 )
                message << Builtins.sformat(_("Otherwise you can abort the installation or go back to select different partitions for the LVG %1."), _LVG )
                Wizard.SetContentsFocus(_("Select the Partitions for the System"),RichText(message),"",true,true,false)
	    else
                Wizard.SetContentsFocus(_("Select the Partitions for the System"),RichText(message),"",false,true,false)
	    end
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
                Wizard.CloseDialog() if @closeMe
                return :ok
                break
              end
            end
          else
            back = false
          end
          break if back
        end
        if back
          @LVGsize = {}
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
        Builtins.y2milestone("Start creating _LVG %1", _LVG)
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
    # Function to calculate the kb values from GiB and Tb
    # **********************************************
    def getDimensionedValue(value)
             @ltmp     = Builtins.regexptokenize(value, "(.*)([G|T])")
	     size      = Ops.get_string(@ltmp, 0, "")
	     dimension = Ops.get_string(@ltmp, 1, "")
	     case dimension
	       when "G"
                  size = size.to_i*1024*1024*1024
	       when "T"
                  size = size.to_i*1024*1024*1024*1024
               else
                  size = 1024*1024*1024
	     end
	     return size
    end

    # **********************************************
    # Function to select the devices for the VLG-s
    # **********************************************
    def selectDevices
      items = VBox()

      Builtins.foreach(@neededLVG) do |_LVG|
        buttons = VBox()
        Builtins.foreach(@freeDevices) do |dev, tmp|
          tmp1 = "CHECK"+_LVG + "#" + dev
          tmp2 = Builtins.sformat("%1 %2GB",dev, Ops.get(@freeDevices, dev, 0) / 1000 / 1000 /1000 )
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
          tmp2 = Builtins.sformat("%1 %2GB",dev, Ops.get(@freeDevices, dev, 0) / 1000 / 1000 /1000 )
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
