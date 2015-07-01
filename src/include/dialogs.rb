# encoding: utf-8

# File: sap-installation-wizard/dialogs.rb
# Package:      Configuration of SAP products
# Summary:      Definition of dialogs
# Authors:      Peter Varkoly <varkoly@suse.de>
#

module Yast
  module SapInstallationWizardDialogsInclude
    def initialize_sap_installation_wizard_dialogs(include_target)
      textdomain "sap-installation-wizard"

      Yast.import "SAPInst"
      Yast.import "SAPMedia"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Popup"

     #*****************************************************
     #
     # Define some global variables relating the dialogs
     #
     #*****************************************************
     @scheme_list = [
          Item(Id("local"), "dir://", true),
          Item(Id("device"), "device://", false),
          Item(Id("usb"), "usb://", false),
          Item(Id("cdrom"), "cdrom://", false),
          Item(Id("nfs"), "nfs://", false),
          Item(Id("smb"), "smb://", false)
      ]

      #The selected schema.
      @schemeCache    = "local"

      #The entered location. TODO check if we need it
      @locationCache = ""

      #The selected product
      @choosenProduct = ""

      #The sources must be unmounted
      @umountSource = false

      #Local path to the sources
      @sourceDir    = ""

      #List of the searchded media
      @mediaList = []

      #Hash of available media labels for a product
      @labelHashRef = {}

      #Map of find media from available media
      @dbMap = {}

      #Need SAP lup
      @needSaplup = true

      #Stack may be JAVA or AS-ABAP
      @STACK      = ""

      #Hash for design the dialogs
#Help text for the fututre. This will be available only in SP1
#                          '<p><b>' + _("SUSE HA for SAP Simple Stack") + '</p></b>' +
#                          _("With this installation mode the <b>SUSE-HA for SAP Simple Stack</b> can be installed and configured.") +
      @dialogs = {
         "inst_master" => {
             "help"    => _("<p>Enter the location of your SAP Installation Master.</p>") +
                          '<p><b>' + _("Do not copy the sources. Create only links.") + '</p></b>' +
                          _("Select this option to not copy the installation data from media to the local drive space.") +
                          _("This option is only available for SWPM based (NetWeaver) application types.") +
                          '<p><b>' + _("List of present SAP Media.") + '</p></b>' +  
                          _("List of locally already available SAP media."),
             "name"    => _("SAP Installation Master")
             },
         "sapmedium" => {
             "help"    => _("<p>Enter the location of your SAP medium.</p>") +
			  '<p><b>' + _("Do not copy the sources. Create only links.")  + '</p></b>' +
                          _("Select this option to not copy the installation data from media to the local drive space.") +
			  '<p><b>' + _("All sources are present. Do not copy.")  + '</p></b>' +
                          _("Select this option to skip the copy process if all needed SAP media were already copied."),
             "name"    => _("Location of the SAP Medium")
             },
         "nwInstType" => {
             "help"    => _("<p>Choose an installation type from the list.</p>") +
                          '<p><b>' + _("Preparation for autoinstallation.") + '</p></b>' +
			  _("<p>Select this option to only enter installation parameter and to not start installation right after.</p>") +
                          '<p><b>' + _("SAP Standard System") + '</p></b>' +
                          _("<p>Installation of a SAP NetWeaver system with all instances on the same host.</p>") +
                          '<p><b>' + _("SAP Standalone Engines") + '</p></b>' +
                          _("<p>Standalone engines are not part of a specific SAP NetWeaver product instance.</p>") +
                          _("Standalone product types are: TREX, Gateway, Web Dispatcher.<p>") +
                          '<p><b>' + _("Distributed System") + '</p></b>' +
                          _("Installation of SAP NetWeaver with the instances distributed on separate hosts.</p>") +
                          '<p><b>' + _("High-Availability System") + '</p></b>' +
                          _("Installation of SAP NetWeaver for a high-availability scenario.</p>") +
                          '<p><b>' + _("System Rename") + '</p></b>' +
                          _("Changes the SAP system ID, database ID, instance number, or host name of a SAP system.</p>") +
                          '<p><b>' + _("Select the database.") + '</p></b>' +
                          _("Select the database you have to install or will use.</p>") ,
             "name"    => _("Select the Installation Parameter.")
             },
         "nwSelectProduct" => {
             "help"    => _("<p>Select a SAP product from the list.</p>"),
             "name"    => _("Select a SAP Product.")
             },
         "database" => {
             "help"    => _("<p>Enter the location of your database medium. The database type is determined automatically.</p>"),
             "name"    => _("Location of the Database Medium")
             },
         "kernel" => {
             "help"    => _("<p>Enter the path to a medium with a SAP Unicode Kernel if you want to perform an ABAP-based installation or to a SAP Java medium to perform a JAVA-based installation.</p>"),
             "name"    => _("Path to a Kernel or Java Medium")
             },
         "supplement" => {
            "help"    => _("<p>Enter the path to a 3rd party medium which you want to copy to the machine.</p>"),
            "name"    => _("3rd Party Medium")
         }
      }
    end

    #############################################################
    #
    # Reads the settins and previous installations
    #
    ############################################################
    def ReadDialog
      Builtins.y2milestone("--Start SAPInst ReadDialog ---")
      return SAPInst.Read
    end
    
    #############################################################
    #
    # Read and analize the installation master
    #
    ############################################################
    def ReadInstallationMaster
      Builtins.y2milestone("-- Start ReadInstallationMaster ---")
      ret = nil
      run = true
      while run  
        ret = media_dialog("inst_master")
        return :abort if ret == :abort
    
        # is_instmaster gives back a key-value pair to split for the BO workflow
        #         KEY: SAPINST, BOBJ, HANA, B1
        #       VALUE: complete path to the instmaster directory incl. sourceDir
        Builtins.y2milestone("looking for instmaster in %1", @sourceDir)
        instMasterList            = SAPMedia.is_instmaster(@sourceDir)
        SAPInst.instMasterType    = Ops.get(instMasterList, 0, "")
        SAPInst.instMasterPath    = Ops.get(instMasterList, 1, "")
        @instMasterVersion        = Ops.get(instMasterList, 2, "")
    
        Builtins.y2milestone(
          "found SAP instmaster at %1 type %2 version %3",
          SAPInst.instMasterPath,
          SAPInst.instMasterType,
          @instMasterVersion
        )
        if SAPInst.instMasterPath == nil || SAPInst.instMasterPath.size == 0
           Popup.Error(_("Cannot find Installation Master at given location"))
        else
           #We have found the installation master
           run = false
        end
      end
      case SAPInst.instMasterType
        when "SAPINST"
          ret = :SAPINST
        when "HANA"
          SAPInst.DB             = "HDB"
          SAPInst.instMasterType = "HANA"
          SAPInst.PRODUCT_ID     = "HANA"
          SAPInst.PRODUCT_NAME   = "HANA"
          SAPInst.productList << { "name" => "HANA", "id" => "HANA", "ay_xml" => SAPMedia.ConfigValue("HANA","ay_xml"), "partitioning" => SAPMedia.ConfigValue("HANA","partitioning"), "script_name" => SAPMedia.ConfigValue("HANA","script_name") }
          SAPInst.mediaDir = SAPInst.instDir
          ret = :HANA
        when /^B1/ 
          SAPInst.DB             = ""
          SAPInst.PRODUCT_ID     = SAPInst.instMasterType
          SAPInst.PRODUCT_NAME   = SAPInst.instMasterType
          SAPInst.productList << { "name" => SAPInst.instMasterType, "id" => SAPInst.instMasterType, "ay_xml" => SAPMedia.ConfigValue("B1","ay_xml"), "partitioning" => SAPMedia.ConfigValue("B1","partitioning"), "script_name" => SAPMedia.ConfigValue("B1","script_name") }
          SAPInst.mediaDir = SAPInst.instDir
          ret = :B1
      end
      if SAPInst.instMasterType != "SAPINST"
         #We can only link SAPINST MEDIA
         SAPInst.createLinks = false
      end
      Builtins.y2milestone("SAPInst.productList %1", SAPInst.productList)
      SAPInst.CopyFiles(SAPInst.instMasterPath, SAPInst.instDir, "Instmaster", false)
      SAPInst.instMasterPath = SAPInst.instDir + "/Instmaster"
      SAPInst.UmountSources(@umountSource)
      return ret
    end
    
    #############################################################
    #
    # Select the NW installation mode.
    #
    ############################################################
    def SelectNWInstallationMode
      Builtins.y2milestone("-- Start SelectNWInstallationMode ---")
      run = true
    
      #Reset the selected installation type and DB
      SAPInst.instType = ""
      SAPInst.DB = ""
    
      Wizard.SetContents(
        @dialogs["nwInstType"]["name"],
        VBox(
          Left( CheckBox( Id(:auto), _("Preparation for autoinstallation."), false )),
          HBox(
            Frame(_("Select the installation mode."),
            RadioButtonGroup( Id(:type),
              VBox(
                RadioButton( Id("STANDARD"),    Opt(:notify, :hstretch), _("SAP Standard System"), false),
                RadioButton( Id("STANDALONE"),  Opt(:notify, :hstretch), _("SAP Standalone Engines"), false),
                RadioButton( Id("DISTRIBUTED"), Opt(:notify, :hstretch), _("Distributed System"), false),
                #RadioButton( Id("SUSE-HA-ST"),  Opt(:notify, :hstretch), _("SUSE HA for SAP Simple Stack"), false),
                RadioButton( Id("HA"),          Opt(:notify, :hstretch), _("SAP High-Availability System"), false),
                RadioButton( Id("SBC"),         Opt(:notify, :hstretch), _("System Rename"), false),
              ),
            )),
            Frame(_("Select the database."),
            RadioButtonGroup( Id(:db),
              VBox(
                RadioButton( Id("DB6"),    Opt(:notify, :hstretch), _("IBM DB2"), false),
                RadioButton( Id("ADA"),    Opt(:notify, :hstretch), _("MaxDB"), false),
                RadioButton( Id("ORA"),    Opt(:notify, :hstretch), _("Oracle"), false),
                RadioButton( Id("HDB"),    Opt(:notify, :hstretch), _("SAP HANA"), false),
                RadioButton( Id("SYB"),    Opt(:notify, :hstretch), _("SAP ASE"), false)
              )
            ))
          )
        ),
        @dialogs["nwInstType"]["help"],
        true,
        true
      )
    
      while run
        case UI.UserInput
          when /STANDARD|DISTRIBUTED|SUSE-HA-ST|HA/
            UI.ChangeWidget(Id(:db), :Enabled, true)
            SAPInst.instType = Convert.to_string(UI.QueryWidget(Id(:type), :CurrentButton))
          when /STANDALONE|SBC/
            UI.ChangeWidget(Id(:db), :Enabled, false)
            SAPInst.instType = Convert.to_string(UI.QueryWidget(Id(:type), :CurrentButton))
          when /DB6|ADA|ORA|HDB|SYB/
            SAPInst.DB = Convert.to_string(UI.QueryWidget(Id(:db), :CurrentButton))
          when :next
            SAPInst.instMode = "preauto" if Convert.to_boolean(UI.QueryWidget(Id(:auto), :Value))
            run = false
            if SAPInst.instType == ""
              run = true
              Popup.Message(_("Select an installation type!"))
              next
            end
            if SAPInst.instType !~ /STANDALONE|SBC/ and SAPInst.DB == ""
              run = true
              Popup.Message(_("Select a database!"))
              next
            end
          when :back
            return :back
          when :abort
            if Popup.ReallyAbort(false)
              SAPInst.UmountSources(true)
              run = false
              return :abort
            end
        end
      end
      return :next
    end

    #############################################################
    #
    # SelectNWProduct
    #
    ############################################################
    def SelectNWProduct
      Builtins.y2milestone("-- Start SelectNWProduct ---")
      run = true
    
      productItemTable = []
      if SAPInst.instType == 'STANDALONE'
        SAPInst.DB = 'IND'
      end
      SAPInst.productList = SAPMedia.get_nw_products(SAPInst.instMasterPath,SAPInst.instType,SAPInst.DB)
      if SAPInst.productList == nil or SAPInst.productList.empty?
         Popup.Error(_("There are now products to find on this media."))
	 return :back
      end
      SAPInst.productList.each { |map|
         name = map["name"]
         id   = map["id"]
         productItemTable << Item(Id(id),name,false)
      }
      Builtins.y2milestone("productList %1",SAPInst.productList)

      Wizard.SetContents(
        @dialogs["nwSelectProduct"]["name"],
        VBox(
          SelectionBox(Id(:products),
            _("List of available products for the selected installation mode and database."),
            productItemTable
          )
        ),
        @dialogs["nwSelectProduct"]["help"],
        true,
        true
      )
      while run
        case UI.UserInput
          when :next
            SAPInst.PRODUCT_ID = Convert.to_string(UI.QueryWidget(Id(:products), :CurrentItem))
            if SAPInst.PRODUCT_ID == nil
              run = true
              Popup.Message(_("Select a product!"))
            else
              run = false
	      SAPInst.productList.each { |map|
	         SAPInst.PRODUCT_NAME = map["name"] if SAPInst.PRODUCT_ID == map["id"]
	      }
            end
          when :back
            return :back
          when :abort
            if Popup.ReallyAbort(false)
              SAPInst.UmountSources(true)
              return :abort
            end
        end
      end
      return :next
    end

    #############################################################
    #
    # Copy the SAP Media
    #
    ############################################################
    def CopyNWMedia
      Builtins.y2milestone("-- Start CopyNWMedia ---")
      run = true
      while run  
        case media_dialog("sapmedium")
           when :abort
              return :abort
           when :back
              return :back
           when :forw
              return :next
           else
              media=find_sap_media(@sourceDir)
              media.each { |path,label|
                SAPInst.CopyFiles(path, SAPInst.mediaDir, label, false)
              }
              run = Popup.YesNo(_("Do you have more SAP medium to copy?"))
        end
      end
      return :next
    end
    
    #############################################################
    #
    # Ask for 3rd-Party/ Supplement dialog (includes a product.xml)
    #
    ############################################################
    def ReadSupplementMedium
      Builtins.y2milestone("-- Start ReadSupplementMedium ---")
      run = Popup.YesNo(_("Do you have a Supplement/3rd-Party medium?"))
      while run  
        ret = media_dialog("supplement")
        return :abort if ret == :abort
        return :back  if ret == :back
        SAPInst.CopyFiles(@sourceDir, SAPInst.mediaDir, "Supplement", false)
        SAPInst.ParseXML(SAPInst.mediaDir + "/Supplement/" + SAPInst.productXML)
        run = false
      end
      return :next
    end
    
    #############################################################
    #
    # Read the installation parameter.
    # The product xml will executed
    # Partitioning xml will be executed
    # Sapinst will started to read the parameter.
    #
    ############################################################
    def ReadParameter
      Builtins.y2milestone("-- Start ReadParameter ---")
      ret=:next
      #First we execute the autoyast xml file of the product if this exeists
      script_name  = SAPInst.ayXMLPath + '/' +  SAPInst.GetProductParameter("script_name")
      xml_path     = SAPInst.GetProductParameter("ay_xml") == ""       ? ""   : SAPInst.ayXMLPath + '/' +  SAPInst.GetProductParameter("ay_xml")
      partitioning = SAPInst.GetProductParameter("partitioning") == "" ? "NO" : SAPInst.GetProductParameter("partitioning")
      if File.exist?( xml_path ) 
        SAPInst.ParseXML(xml_path)
        SCR.Execute(path(".target.bash"), "mv /tmp/ay_* " + SAPInst.instDir )
      end

      #Writing the installation datas into the product.data file
      SAPInst.WriteProductDatas( {
             "instDir"      => SAPInst.instDir,
             "instMaster"   => SAPInst.instMasterPath,
             "TYPE"         => SAPInst.instMasterType,
             "DB"           => SAPInst.DB,
             "PRODUCT_NAME" => SAPInst.PRODUCT_NAME,
             "PRODUCT_ID"   => SAPInst.PRODUCT_ID,
             "PARTITIONING" => partitioning,
             "SCRIPT_NAME"  => script_name
          })

      case SAPInst.instMasterType
        when "SAPINST"
          # If the product is sapinst we start sapinst to read the parameter
          #Write the media path file
          IO.write(SAPInst.instDir + "/start_dir.cd" , SAPInst.mediaList.join("\n"))
          #Create group sapinst
          #TODO may be we need to check if sapinst already exists
          cmd = "groupadd sapinst; " +
                "usermod --groups sapinst root; " +
                "chgrp sapinst " + SAPInst.instDir + ";" +
                "chmod 770 " + SAPInst.instDir + ";" 
          Builtins.y2milestone("-- Prepare sapinst %1", cmd )
          SCR.Execute(path(".target.bash"), cmd)

          #Some other staff
          if SAPInst.DB == "DB6"
            SCR.Execute(path(".target.bash"), "sed -i 's@.*5912/.*@# & # changing as needed for DB2 communication service@' /etc/services")
          end

          #Now we start the sapinst to read the parameter
          cmd = "cd " + SAPInst.instDir + ";" +
                " export PRC_DEACTIVATE_CHECKS=true;" +
                SAPInst.instMasterPath + "/sapinst SAPINST_EXECUTE_PRODUCT_ID=" + SAPInst.PRODUCT_ID + " SAPINST_STOP_AFTER_DIALOG_PHASE=true SAPINST_DETAIL_SUMMARY=false"
          #TODO VIRTHOST MUST BE CONFIGURED HERE NOT IN THE SCRIPT
          if File.exists?(SAPInst.instDir + "/ay_q_virt_hostname")
              hostname=IO.read(SAPInst.instDir + "/ay_q_virt_hostname")
              hostname = hostname.chomp
              cmd = cmd + " SAPINST_USE_HOSTNAME=" + hostname
          end

          Builtins.y2milestone("-- Start sapinst %1", cmd )
          SCR.Execute(path(".target.bash"), cmd)
        when "HANA"
          if Popup.AnyQuestion(_("Preparation for autoinstallation?"), _("Select this option to only enter installation parameter and to not start installation right after."), _("Yes"), _("No"), :focus_no)
            SAPInst.instMode = "preauto"
          end
        when /^B1/
          if Popup.AnyQuestion(_("Preparation for autoinstallation?"), _("Select this option to only enter installation parameter and to not start installation right after."), _("Yes"), _("No"), :focus_no)
            SAPInst.instMode = "preauto"
          end
      end
      if Popup.YesNo(_("Do you want to install another product?"))
         ret = SAPInst.instMasterType == "SAPINST" ?  :selectP : :readIM
         SAPInst.prodCount = SAPInst.prodCount.next
         SAPInst.instDir = Builtins.sformat("%1/%2", SAPInst.instDirBase, SAPInst.prodCount)
         SCR.Execute(path(".target.bash"), "mkdir -p " + SAPInst.instDir )
      end

      return ret 
    end

    #############################################################
    #
    # Read kernel media
    #
    ############################################################
    def ReadKernel
      run = true
      @mediaList = ["UKERNEL", "SCA"]
    
      while run  
        ret = media_dialog("kernel")
        return :abort if ret == :abort
        return :back  if ret == :back
        if @dbMap == {}
           Popup.Error(_("This is not an allowed Database medium - please choose a usable medium"))
        else
          run = false
          @dbMap.each do |key, val|
            SAPInst.CopyFiles(val, SAPInst.mediaDir, key, true)
            @labelHashRef = Builtins.remove(@labelHashRef, key)
            if key == "UKERNEL"
              @STACK = "AS-ABAP"
    
              # if we need the feature SAPLUP, try to copy it. It may be on the Kernel medium
              if @needSaplup
                @dbMediaList = ["SAPLUP"]
    
                # Try to find it on the media inserted
                myMap = SAPMedia.check_media(
                  @sourceDir,
                  @dbMediaList,
                  @labelHashRef 
                )
    
                if myMap == {}
                  # SAPLUP is on a different media - we are asking later
                  @ownSaplupMedia = true
                else
                  Builtins.foreach(myMap) do |key2, val2|
                    Builtins.y2milestone("key=%1 val=%2", key2, val2)
                    copyFiles(val2, SAPInst.mediaDir, key2, true)
                      @labelHashRef = Builtins.remove(@labelHashRef, key2)
                  end
                end
              end
            elsif key == "SCA"
              @STACK = "AS-JAVA"
            end
          end
        end
      end
    end
    
    #############################################################
    #
    # Read database media
    #
    ############################################################
    def ReadDataBase
      run = true
      @mediaList    = SAPInst.dbMediaList
      while run  
        ret = media_dialog("database")
        return :abort if ret == :abort
        return :back  if ret == :back
        if @dbMap == {}
           Popup.Error(_("This is not an allowed Database medium - please choose a usable medium"))
        else
           run = false
           @dbMap.each do |key, val|
             SAPInst.CopyFiles(val, SAPInst.mediaDir, key, false)
             @labelHashRef = Builtins.remove(@labelHashRef, key)
             # only if we do not have set a DB before
             if Builtins.size(SAPInst.DB) == 0
               SAPInst.DB = Builtins.substring(key, 6)
               Builtins.y2milestone("DB = %1", SAPInst.DB)
               key = ""
    
               if SAPInst.DB == "DB6"
                 key = "RDBMS-DB6-CLIENT"
               elsif SAPInst.DB == "ORA" || SAPInst.DB == "ORA2" ||
                     SAPInst.DB == "ORA112d" ||
                     SAPInst.DB == "ORA1122" ||
                     SAPInst.DB == "ORA112"
                 key = "ORACLI"
               end
               if key != ""
                 run = true
                 UI.ChangeWidget(
                   Id(:location),
                   :Label,
                   Builtins.sformat(
                     _("Provide the location of the medium with the label: %1"),
                     Ops.get(@labelHashRef, [key, "mediaName"], "")
                   )
                 )
                 @mediaList = [key]
               end
             end
           end
        end
      end
    end
    
    def WriteDialog
      Builtins.y2milestone("--Start SAPInst WriteDialog ---")
      return SAPInst.Write
    end
    
    private
    #############################################################
    #
    # Private function to find relevant directories on the media
    #
    ############################################################
    def find_sap_media(base)
      Builtins.y2milestone("-- Start find_sap_media ---")
      make_hash = proc do |hash,key|
         hash[key] = Hash.new(&make_hash)
      end
      path_map = Hash.new(&make_hash)

      #Searching the SAPLUP
      command = "find '" + base + "' -maxdepth 5 -type d -name 'SL_CONTROLLER_*'"
      out     = SCR.Execute(path(".target.bash_output"), command)
      stdout  = out["stdout"] || ""
      stdout.split("\n").each { |d|
        lf=d+"/LABEL.ASC"
        if File.exist?(lf)
          label=IO.readlines(lf,":")
          path_map[d]=label[1].gsub(/\W/,"-") + label[2].gsub(/\W/,"-")
        end
      }
      #Searching the EXPORTS
      command = "find '" + base + "' -maxdepth 5 -type d -name 'EXP?'"
      out     = SCR.Execute(path(".target.bash_output"), command)
      stdout  = out["stdout"] || ""
      stdout.split("\n").each { |d|
        lf=d+"/LABEL.ASC"
        if File.exist?(lf)
          label=IO.readlines(lf,":")
          path_map[d]=label[4].chop.gsub(/\W/,"-")
        end
      }

      #Searching the LINUX_X86_64 directories
      command = "find '" + base + "' -maxdepth 5 -type d -name '*LINUX_X86_64'"
      out     = SCR.Execute(path(".target.bash_output"), command)
      stdout  = out["stdout"] || ""
      stdout.split("\n").each { |d|
        lf=d+"/LABEL.ASC"
        if File.exist?(lf)
          label=IO.readlines(lf,":")
          path_map[d]=label[2].gsub(/\W/,"-") + label[3].gsub(/\W/,"-") + label[4].chop.gsub(/\W/,"-")
        end
      }

      #If we have not found anything we have to copy the whole medium
      if path_map.empty?
        lf=base+"/LABEL.ASC"
        if File.exist?(lf)
          label=IO.readlines(lf,":")
          path_map[base]=label[1].gsub(/\W/,"-") + label[2].gsub(/\W/,"-") + label[3].chop.gsub(/\W/,"-")
        else
          #This is not a real SAP medium.
          Popup.Error( _("This is not an official SAP medium."))
        end
      end
      Builtins.y2milestone("path_map %1",path_map)
      return path_map
    end

    #############################################################
    #
    # Private function to handle media
    #
    ############################################################
    def media_dialog(wizard)
      Builtins.y2milestone("-- Start media_dialog ---")
      @dbMap = {}
      content = HBox(
        VBox(HSpacing(13)),
        VBox(
          HBox(Label("Enter the path to the " +  @dialogs[wizard]["name"])),
          HBox(
            HSpacing(13),
            ComboBox(Id(:scheme), Opt(:notify), " ", @scheme_list),
            InputField(Id(:location),Opt(:hstretch),
              @dialogs[wizard]["name"],
              @locationCache
            ),
            HSpacing(18)
          ),
          VBox(HSpacing(13)),
          CheckBox(Id(:link),_("Do not copy the sources. Create only links."),true)
        )
      )
      #By copying sapmedia we have to list the existing media
      if wizard == "sapmedium"
         media = []
         if File.exist?(SAPInst.mediaDir)
            media = Dir.entries(SAPInst.mediaDir)
            media.delete('.')
            media.delete('..')
         end
         if !media.empty?
            content = HBox(
              VBox(HSpacing(13)),
              VBox(
                Left(Frame(_("List of SAP media already copied or linked."), Label( media.join("\n")))),
                VBox(HSpacing(13)),
                HBox(
                  HSpacing(13),
                  ComboBox(Id(:scheme), Opt(:notify), " ", @scheme_list),
                  InputField(Id(:location),Opt(:hstretch),
                    @dialogs[wizard]["name"],
                    @locationCache
                  ),
                  HSpacing(18)
                ),
                VBox(HSpacing(13)),
                CheckBox(Id(:link),_("Do not copy the sources. Create only links."),true),
                CheckBox(Id(:forw),_("All sources are present. Do not copy."),false)
              )
            )
         end
      end
      Wizard.SetContents(
        _("SAP Installation Wizard"),
        content,
        @dialogs[wizard]["help"],
        true,
        true
      )
      Wizard.RestoreAbortButton()
      UI.ChangeWidget(:scheme, :Value, @schemeCache)
      do_default_values(wizard)
      run = true
      @sourceDir = ""
      @umountSource = false
      while run
        button          = UI.UserInput

        if button == :scheme
          do_default_values(wizard)
          next
        end

        scheme          = Convert.to_string(UI.QueryWidget(Id(:scheme), :Value))
        @locationCache  = Convert.to_string(UI.QueryWidget(Id(:location), :Value))
        if scheme == "local"
          #This value can be reset by MountSource if the target is iso file.
          SAPInst.createLinks =Convert.to_boolean(UI.QueryWidget(Id(:link), :Value))
        end
        @sourceDir      = @locationCache
      
        if button == :back
           return :back
        end
      
        if button == :abort
          if Popup.ReallyAbort(false)
            SAPInst.UmountSources(true)
            run = false
            return :abort
          end
          next
        end

        if UI.WidgetExists(Id(:forw)) and Convert.to_boolean(UI.QueryWidget(Id(:forw), :Value))
           return :forw
        end
        urlPath = SAPInst.MountSource(scheme, @locationCache)
        if urlPath != "" 
          ltmp    = Builtins.regexptokenize(urlPath, "ERROR:(.*)")
          if Ops.get_string(@ltmp, 0, "") != ""
            Popup.Error( _("Mounting failed: ") + Ops.get_string(@ltmp, 0, ""))
            next
          end
        end
        run = false
        if scheme != "local"
          @sourceDir = SAPInst.mountPoint +  "/" + urlPath
        elsif urlPath != ""
          @sourceDir = urlPath
        end
        @umountSource = true
        Builtins.y2milestone("urlPath %1, @sourceDir %2, scheme %3",urlPath,@sourceDir,scheme)
      end
      if @mediaList != [] and @labelHashRef != {}
         @dbMap = SAPMedia.check_media(
           @sourceDir,
           @mediaList,
           @labelHashRef
         )
      end
      return :next
    end
    
    # ***********************************
    # show a default entry or the last entered path
    #
    def do_default_values(wizard)
        val = Convert.to_string(UI.QueryWidget(Id(:scheme), :Value))
        @schemeCache = val
        if val == "device"
          UI.ChangeWidget(Id(:link), :Value, false)
          UI.ChangeWidget(Id(:link), :Enabled, false)
          UI.ChangeWidget(
            :location,
            :Value,
            @locationCache == "" ? "sda1/directory" : @locationCache
          )
        elsif val == "nfs"
          UI.ChangeWidget(Id(:link), :Value, false)
          UI.ChangeWidget(Id(:link), :Enabled, false)
          UI.ChangeWidget(
            :location,
            :Value,
            @locationCache == "" ? "nfs.server.com/directory/" : @locationCache
          )
        elsif val == "usb"
          UI.ChangeWidget(Id(:link), :Value, false)
          UI.ChangeWidget(Id(:link), :Enabled, false)
          UI.ChangeWidget(
            :location,
            :Value,
            @locationCache == "" ? "/directory/" : @locationCache
          )
        elsif val == "local"
          UI.ChangeWidget(Id(:link), :Value, true)
          UI.ChangeWidget(Id(:link), :Enabled, true)
          UI.ChangeWidget(
            :location,
            :Value,
            @locationCache == "" ? "/directory/" : @locationCache
          )
        elsif val == "cdrom"
          UI.ChangeWidget(Id(:link), :Value, false)
          UI.ChangeWidget(Id(:link), :Enabled, false)
          UI.ChangeWidget(
            :location,
            :Value,
            @locationCache == "" ? "//" : @locationCache
          )
        elsif val == "smb"
          UI.ChangeWidget(Id(:link), :Value, false)
          UI.ChangeWidget(Id(:link), :Enabled, false)
          UI.ChangeWidget(
            :location,
            :Value,
            @locationCache == "" ?
              "[username:passwd@]server/path-on-server[?workgroup=my-workgroup]" :
              @locationCache
          )
        end
    
        nil
    end
  end
end
