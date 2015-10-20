# encoding: utf-8

# File: sap-installation-wizard/dialogs.rb
# Package:      Configuration of SAP products
# Summary:      Definition of dialogs
# Authors:      Peter Varkoly <varkoly@suse.com>, Howard Guo <hguo@suse.com>
#

module Yast
  module SapInstallationWizardDialogsInclude
    extend self
    def initialize
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
          Item(Id("nfs"), "nfs://", false),
          Item(Id("smb"), "smb://", false)
      ]

      #Detect how many cdrom we have:
      cdroms=`hwinfo --cdrom | grep 'Device File:' | sed 's/Device File://' | gawk '{ print $1 }' | sed 's#/dev/##'`.split
      if cdroms.count == 1
          @scheme_list << Item(Id("cdrom"), "cdrom://", false)
      elsif cdroms.count > 1
         i=1
         cdroms.each { |cdrom|
            @scheme_list << Item(Id("cdrom::" + cdrom  ), "cdrom" + i.to_s + "://", false)
            i = i.next
         }
      end

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
             "help"    => _("<p>Enter location of SAP installation master medium to prepare it for use.</p>") +
                          '<p><b>' + _("Prepare the SAP medium for installation by creating links to it") + '</p></b>' +
                          _("Prepare the installation master medium by creating necessary links, but do not make a copy of its content.") +
                          _("This option should only be used with SWPM based (NetWeaver) product medias.") +
                          '<p><b>' + _("List of SAP installation masters") + '</p></b>' +  
                          _("These SAP installation masters are ready to use."),
             "name"    => _("Prepare the SAP installation master medium")
             },
         "sapmedium" => {
             "help"    => _("<p>Enter the location of your SAP medium.</p>") +
			  '<p><b>' + _("Prepare the SAP medium for installation by creating links to it")  + '</p></b>' +
                          _("Select this option to not copy the installation data from medium to the local drive space.") +
			  '<p><b>' + _("This is the last SAP medium to be prepared for product installation")  + '</p></b>' +
                          _("The specified location contains the last SAP product medium to be prepared for installation."),
             "name"    => _("Location of the SAP product medium (e.g. SAP kernel, database, and database exports)")
             },
         "nwInstType" => {
             "help"    => _("<p>Choose SAP product installation and back-end database.</p>") +
                          '<p><b>' + _("Collect auto-installation profiles") + '</p></b>' +
			  _("<p>Enter installation parameters and generate auto-installation profiles for SAP products, without conducting product installation on this system.</p>") +
                          '<p><b>' + _("SAP Standard System") + '</p></b>' +
                          _("<p>Installation of a SAP NetWeaver system with all servers on the same host.</p>") +
                          '<p><b>' + _("SAP Standalone Engines") + '</p></b>' +
                          _("<p>Standalone engines are SAP Trex, SAP Gateway, and Web Dispatcher.</p>") +
                          '<p><b>' + _("Distributed System") + '</p></b>' +
                          _("Installation of SAP NetWeaver with the servers distributed on separate hosts.</p>") +
                          '<p><b>' + _("High-Availability System") + '</p></b>' +
                          _("Installation of SAP NetWeaver in a high-availability setup.</p>") +
                          '<p><b>' + _("System Rename") + '</p></b>' +
                          _("Change the SAP system ID, database ID, instance number, or host name of a SAP system.</p>") +
                          '<p><b>' + _("Select the database.") + '</p></b>' +
                          _("Select the database you have to install or will use.</p>") ,
             "name"    => _("What would you like to install?")
             },
         "nwSelectProduct" => {
             "help"    => _("<p>Please choose the SAP product you wish to install.</p>"),
             "name"    => _("Choose a Product")
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
        if ret == :abort || ret == :cancel
            if Yast::Popup.ReallyAbort(false)
                Yast::Wizard.CloseDialog
                return :abort
            end
        end
    
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
           Popup.Error(_("The location does not point to an SAP installation master.\nPlease check your input."))
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
      if SAPInst.instMasterType == 'HANA'
        # HANA instmaster must reside in "Instmaster" directory, instead of "Instmaster-HANA" directory.
        SAPInst.CopyFiles(SAPInst.instMasterPath, SAPInst.mediaDir, "Instmaster", false)
        SAPInst.instMasterPath = SAPInst.mediaDir + "/Instmaster"
      else
        SAPInst.CopyFiles(SAPInst.instMasterPath, SAPInst.mediaDir, "Instmaster-" + SAPInst.instMasterType, false)
        SAPInst.instMasterPath = SAPInst.mediaDir + "/Instmaster-" + SAPInst.instMasterType
      end
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
          
          HVSquash(Frame("",
          
          VBox(
            HBox(
                VBox(
                    Label(_("The SAP product is ..")),
                    RadioButtonGroup( Id(:type),
                    VBox(
                        RadioButton( Id("STANDARD"),    Opt(:notify, :hstretch), _("SAP Standard System"), false),
                        RadioButton( Id("STANDALONE"),  Opt(:notify, :hstretch), _("SAP Standalone Engines"), false),
                        RadioButton( Id("DISTRIBUTED"), Opt(:notify, :hstretch), _("Distributed System"), false),
                        #RadioButton( Id("SUSE-HA-ST"),  Opt(:notify, :hstretch), _("SUSE HA for SAP Simple Stack"), false),
                        RadioButton( Id("HA"),          Opt(:notify, :hstretch), _("SAP High-Availability System"), false),
                        RadioButton( Id("SBC"),         Opt(:notify, :hstretch), _("System Rename"), false),
                    )),
                ),
                HSpacing(4.0),
                VBox(
                    Label(_("The back-end database system is ..")),
                    RadioButtonGroup( Id(:db),
                    VBox(
                        RadioButton( Id("ADA"),    Opt(:notify, :hstretch), _("SAP MaxDB"), false),
                        RadioButton( Id("HDB"),    Opt(:notify, :hstretch), _("SAP HANA"), false),
                        RadioButton( Id("SYB"),    Opt(:notify, :hstretch), _("SAP ASE"), false),
                        RadioButton( Id("DB6"),    Opt(:notify, :hstretch), _("IBM DB2"), false),
                        RadioButton( Id("ORA"),    Opt(:notify, :hstretch), _("Oracle"), false)
                    ))
                )
            ),
            VSpacing(4.0),
            Frame(_("Advanced Options"),
                Left(CheckBox( Id(:auto), _("Collect auto-installation profiles, without installing the product."), false))),
          )
        ))),
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
              Popup.Message(_("Please choose an SAP installation type."))
              next
            end
            if SAPInst.instType !~ /STANDALONE|SBC/ and SAPInst.DB == ""
              run = true
              Popup.Message(_("Please choose a back-end database."))
              next
            end
          when :back
            return :back
          when :abort, :cancel
            if Yast::Popup.ReallyAbort(false)
                Yast::Wizard.CloseDialog
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
         Popup.Error(_("The medium does not contain SAP installation data."))
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
            _("Your SAP installation master supports the following products.\n"+
              "Please choose the product you wish to install:"),
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
          when :abort, :cancel
            if Yast::Popup.ReallyAbort(false)
                Yast::Wizard.CloseDialog
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
    # Copy the SAP Media
    #
    ############################################################
    def CopyNWMedia
      Builtins.y2milestone("-- Start CopyNWMedia ---")
      run = true
      while run  
        case media_dialog("sapmedium")
           when :abort, :cancel
              if Yast::Popup.ReallyAbort(false)
                  Yast::Wizard.CloseDialog
                  return :abort
              end
           when :back
              return :back
           when :forw
              return :next
           else
              media=find_sap_media(@sourceDir)
              media.each { |path,label|
                SAPInst.CopyFiles(path, SAPInst.mediaDir, label, false)
              }
              run = Popup.YesNo(_("Are there more SAP product mediums to be prepared?"))
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
      run = Popup.YesNo(_("Do you use a Supplement/3rd-Party SAP software medium?"))
      while run  
        ret = media_dialog("supplement")
        if ret == :abort || ret == :cancel
            if Yast::Popup.ReallyAbort(false)
                Yast::Wizard.CloseDialog
                return :abort
            end
        end
        return :back  if ret == :back
        SAPInst.CopyFiles(@sourceDir, SAPInst.instDir, "Supplement", false)
        SAPInst.ParseXML(SAPInst.instDir + "/Supplement/" + SAPInst.productXML)
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
          SCR.Execute(path(".target.bash"), "xterm -e '" + cmd + "'")

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
          SCR.Execute(path(".target.bash"), "xterm -e '" + cmd + "'")
        when "HANA"
          if Popup.AnyQuestion(_("Only collect installation profile"),
	                       _("There is an advanced installation mode that will collect installation profile without doing installation.\n" +
                             "Answer Yes if you wish to only collect a HANA installation profile.\n" +
                             "Answer No if you wish to collect HANA installation profile and execute the installation on the system."),
			       _("Yes"), _("No"), :focus_no)
            SAPInst.instMode = "preauto"
          end
        when /^B1/
          if Popup.AnyQuestion(_("Only collect installation profile"),
                           _("There is an advanced installation mode that will collect installation profile without doing installation.\n" +
                             "Answer Yes if you wish to only collect a BusinessOne installation profile.\n" +
                             "Answer No if you wish to collect BusinessOne installation profile and execute the installation on the system."),
			       _("Yes"), _("No"), :focus_no)
            SAPInst.instMode = "preauto"
          end
      end
      if Popup.YesNo(_("Installation profile is ready.\n" +
                       "Are there more SAP products to install?"))
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
        if ret == :abort || ret == :cancel
            if Yast::Popup.ReallyAbort(false)
                Yast::Wizard.CloseDialog
                return :abort
            end
        end
        return :back  if ret == :back
        if @dbMap == {}
           Popup.Error(_("The SAP kernel installation medium does not contain installation data."))
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
        if ret == :abort || ret == :cancel
            if Yast::Popup.ReallyAbort(false)
                Yast::Wizard.CloseDialog
                return :abort
            end
        end
        return :back  if ret == :back
        if @dbMap == {}
           Popup.Error(_("The database medium does not contain installation data."))
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

      #If we have not found anything we have to copy the whole medium when there is a LABAL.ASC file
      if path_map.empty?
        lf=base+"/LABEL.ASC"
        if File.exist?(lf)
          label=IO.readlines(lf,":")
          path_map[base]=label[1].gsub(/\W/,"-") + label[2].gsub(/\W/,"-") + label[3].chop.gsub(/\W/,"-")
        else
          #This is not a real SAP medium.
          Popup.Error( _("The location does not contain SAP installation data."))
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
          HBox(Label(@dialogs[wizard]["name"])),
          Left(
            HBox(
            ComboBox(Id(:scheme), Opt(:notify), "", @scheme_list),
            InputField(Id(:location),Opt(:hstretch),
              "",
              @locationCache
            ),
            HSpacing(18)
          )),
          VBox(HSpacing(13)),
          Left(HBox(CheckBox(Id(:link),_("Prepare the SAP medium for installation by creating links to it, without copying its content."),true)))
        )
      )
      #By copying sapmedia we have to list the existing media
      if wizard == "sapmedium"
	 if SAPInst.importSAPCDs
            #When importing the SAP Media we can not copy anything
	    return :forw
	 end
         media = []
         if File.exist?(SAPInst.mediaDir)
            media = Dir.entries(SAPInst.mediaDir)
            media.delete('.')
            media.delete('..')
            media.delete_if { |name|  name =~ /Instmaster-/ }
         end
         if !media.empty?
            content = HBox(
              VBox(HSpacing(12)),
              VBox(
                Left(Frame(_("These SAP product mediums are ready for use:"), Label(Id(:mediums), Opt(:hstretch), media.join("\n")))),
                VBox(HSpacing(12)),
                Left(HBox(
                  ComboBox(Id(:scheme), Opt(:notify), " ", @scheme_list),
                  InputField(Id(:location),Opt(:hstretch),
                    @dialogs[wizard]["name"],
                    @locationCache
                  ),
                  HSpacing(12)
                )),
                VBox(HSpacing(12)),
                Left(HBox(CheckBox(Id(:link),_("Prepare the SAP medium for installation by creating links to it, without copying its content."),true))),
                Left(HBox(CheckBox(Id(:forw),_("This is the last SAP medium to be prepared for product installation."),false)))
              )
            )
         end
      end
      #List existing inst master
      if wizard == "inst_master"
         media = []
         if File.exist?(SAPInst.mediaDir)
            media = Dir.entries(SAPInst.mediaDir)
            media.delete('.')
            media.delete('..')
            media.delete_if { |name| !( name =~ /Instmaster-/ ) }
         end
	 if SAPInst.importSAPCDs
	    if media.empty?
	       Popup.Error("No SAP Installation Master found.")
	       return :abort
	    end
	    if 1 == media.count
               @sourceDir = SAPInst.mediaDir + "/" + media[0]
               return :next
	    end
            #When importing the SAP Media we can not copy anything
	    content = HBox(
              VBox(HSpacing(13)),
	      VBox(
	          Left(Frame(_("List of SAP Installation Masters."),
		     ComboBox(Id(:local_im), Opt(:notify), _("Select one installation master"), [ "---" ] + media)
		  ))
	      )
	    )
         elsif !media.empty?
            content = HBox(
              VBox(HSpacing(13)),
              VBox(
                Left(Frame(_("These SAP installation masters are ready for use:"), ComboBox(Id(:local_im), Opt(:notify),
		           "", [ "---" ] + media))),
                VBox(HSpacing(13)),
                Left(HBox(
                  ComboBox(Id(:scheme), Opt(:notify), " ", @scheme_list),
                  InputField(Id(:location),Opt(:hstretch),
                    @dialogs[wizard]["name"],
                    @locationCache
                  ),
                  HSpacing(18)
                )),
                VBox(HSpacing(13)),
                Left(HBox(CheckBox(Id(:link),_("Prepare the SAP installatioin master by creating links to it, without copying its content."),true))),
                Left(HBox(CheckBox(Id(:forw),_("This is the last SAP installation master medium."),false)))
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

        if button == :local_im
          im = Convert.to_string(UI.QueryWidget(Id(:local_im), :Value))
	  if im == "---"
	    next
	  end
	  UI.ChangeWidget(Id(:scheme), :Value, "dir")
          UI.ChangeWidget(Id(:forw), :Value, true)
          UI.ChangeWidget(Id(:link), :Value, false)
          UI.ChangeWidget(Id(:link), :Enabled, true)
          UI.ChangeWidget(
            :location,
            :Value,
            SAPInst.mediaDir + "/" + Convert.to_string(UI.QueryWidget(Id(:local_im), :Value))
          )
          next
        end
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
      
        if button == :abort || button == :cancel
            return :abort
        end

        if UI.WidgetExists(Id(:forw)) and Convert.to_boolean(UI.QueryWidget(Id(:forw), :Value))
           return :forw
        end
        urlPath = SAPInst.MountSource(scheme, @locationCache)
        if urlPath != "" 
          ltmp    = Builtins.regexptokenize(urlPath, "ERROR:(.*)")
          if Ops.get_string(@ltmp, 0, "") != ""
            Popup.Error( _("Failed to mount the location: ") + Ops.get_string(@ltmp, 0, ""))
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
        else
          #This is cdrom1 cdrom2 and so on
          UI.ChangeWidget(Id(:link), :Value, false)
          UI.ChangeWidget(Id(:link), :Enabled, false)
          UI.ChangeWidget(
            :location,
            :Value,
            @locationCache == "" ? "//" : @locationCache
          )
        end
    
        nil
    end
  end
end
