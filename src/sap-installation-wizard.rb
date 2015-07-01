# encoding: utf-8

# -*- Mode: YCP; tab-width: 4; indent-tabs-mode:nil -*-
# ex: set tabstop=4 expandtab:
# vim: set tabstop=4:expandtab
module Yast
  class SAPInstallationWizardClient < Client
    def main
      Yast.import "UI"
      Yast.import "Pkg"

      textdomain "sap-installation-wizard"
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("SAP auto started")

      Yast.import "SAPMedia"
      Yast.import "SAPInst"
      Yast.import "Wizard"
      Yast.import "Misc"
      Yast.import "Stage"
      Yast.import "URL"
      Yast.import "Popup"
      Yast.import "XML"
      Yast.import "Profile"
      Yast.import "AutoinstScripts"
      Yast.import "AutoInstall"
      Yast.import "Mode"
      Yast.import "AutoinstSoftware"
      Yast.import "AutoinstData"
      Yast.import "AutoinstConfig"
      Yast.import "Progress"
      Yast.import "FileUtils"
      Yast.import "LogView"
      Yast.import "Service"
      Yast.import "Storage"

      #//////////////////////////////////////////////////////////////////////////
      #/ MAIN
      #/

      # remove the old DTD file. It destorys <script> elements in combination
      # with the XML::LibXML.pm module we use in SAPMedia.pm
      SCR.Execute(
        path(".target.bash"),
        "mkdir -p /usr/share/autoinstall/dtd/; : > /usr/share/autoinstall/dtd/profile.dtd;"
      )
      SAPInst.Read

      @args = WFM.Args
      if Ops.get_string(@args, 0, "") == "hana_partitioning"
        @productPartitioningList = [Ops.get_string(@args, 0, "")]
        @ret = createPartitions
        @info = ""
        if @ret == nil
          @info = "SAP file system creation succesfully done:"
        elsif @ret == true
          @info = "SAP file systems already in place:"
        else
          @info = "SAP file system creation failed. Current partitions found:"
        end
        showPartitions(@info)
        return deep_copy(@ret)
      end

      @prodCount = 0
      @tmpTargetDir = @targetDir # backup for the targetDir without prodCount

      # Initialize Dialogs
      Wizard.CreateDialog
      @contents = nil
      @help_text = ""

      @out = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "date +%Y%m%d-%H%M")
      )
      @date = Builtins.filterchars(
        Ops.get_string(@out, "stdout", ""),
        "0123456789-."
      )
      begin
        # reset all "global" variables like STACK, etc. for every product
        @STACK = ""
        @INSTALL = ""
        @SEARCH = ""
        @TYPE = ""
        @DATABASE = ""
        @instMasterPath = ""
        @instMasterType = ""
        @instMasterVersion = ""
        @PRODUCT_ID = []
        # TODO IBM Java not needed anymore with SWPM
        # needJCECrypto = false;
        @needSAPCrypto = false
        @checkLocal = true
        @locationCache = ""
        @schemeCache = :local

        # in second stage we have to look for copied products from first stage.
        # that's why we can't simply remember the prodCount in a global variable
        # instead we are reading the existing directories
        while SCR.Read(
            path(".target.lstat"),
            Builtins.sformat("%1/%2/", @tmpTargetDir, @prodCount)
          ) != {}
          @targetDir = Builtins.sformat("%1/%2", @tmpTargetDir, @prodCount)

          # we can do this here because prodCount will be increased at the end, so
          # we'll never come back here, even if "install another product" is answered
          # with yes.
          # read settings from stage before
          @productData2 = Convert.convert(
            SCR.Read(path(".target.ycp"), Ops.add(@targetDir, "/product.data")),
            :from => "any",
            :to   => "map <string, any>"
          )
          # run scripts
          finish(@productData2)
          @prodCount = Ops.add(@prodCount, 1)
        end
        @targetDir = Builtins.sformat("%1/%2", @tmpTargetDir, @prodCount)
        Builtins.y2milestone("#### Target directory is: %1", @targetDir)

        while @run
          if @instMasterPath != nil &&
              Ops.greater_than(Builtins.size(@instMasterPath), 0) &&
              @instMasterType == "SAPINST"
            #///////////////////////////////////////////////////////////////////////////
            #
            # Wizard Page 2 - Product Selection List
            #
            #///////////////////////////////////////////////////////////////////////////

            # note: at this point we don't have a database and installtype, but we need
            #       it to do the search. Fortunatly all packages.xml files for a product
            #       have the same data, so it doesn't matter which we use so we go here
            #       with the global defaults are ADA and PD.

            # return array of products with shortname and description
            @products = SAPMedia.products_on_instmaster(
              @instMasterPath,
              @instMasterVersion
            )

            while @products == []
              Builtins.y2milestone(
                "ERROR: Empty productlist on the installationmaster"
              )
              if Popup.YesNo(
                  "No Products could be found on the Installationmaster. Try it again?"
                )
                @products = SAPMedia.products_on_instmaster(
                  @instMasterPath,
                  @instMasterVersion
                )
              else
                return :abort
              end
            end

            # build product list to show
            @productItemTable = []
            Builtins.foreach(@products) do |product|
              key = Ops.get_string(product, "id", "")
              val = Ops.get_string(product, "name", "")
              Ops.set(@productMap, key, {})
              Ops.set(@productMap, [key, "id"], key)
              Ops.set(@productMap, [key, "name"], val)
              Ops.set( @productMap, [key, "im"], Ops.get_string(product, "im", ""))
              Ops.set( @productMap, [key, "imv"], Ops.get_string(product, "imv", ""))
              Ops.set( @productMap, [key, "nw"], Ops.get_string(product, "nw", ""))
              @productItemTable = Builtins.add(
                @productItemTable,
                Item(Id(key), key, val)
              )
            end
            Builtins.y2milestone("productMap %1", @productMap)

            @help_text2 = _("<p>Please choose a product from the list.</p>")
            @content_products = VBox(
              MinSize(
                50,
                12,
                Table(
                  Id(:table),
                  Header("Product", "Description"),
                  @productItemTable
                )
              )
            )

            Wizard.SetContents(
              _("Products available for installation"),
              @content_products,
              @help_text2,
              true,
              true
            )

            @run = true
            while @run
              @button = UI.UserInput
              if @button == :next
                @choosenProduct = Convert.to_string(
                  UI.QueryWidget(Id(:table), :CurrentItem)
                )
                @instMasterPath = Ops.get_string(
                  @productMap,
                  [@choosenProduct, "im"],
                  ""
                )
                @instMasterVersion = Ops.get_string(
                  @productMap,
                  [@choosenProduct, "imv"],
                  ""
                )
                Builtins.y2milestone(
                  "choosenProduct=%1, instMasterPath=%2, instMasterVersion=%3",
                  @choosenProduct,
                  @instMasterPath,
                  @instMasterVersion
                )
                @run = false
              elsif @button == :back
                Wizard.SetContents(
                  _("SAP Installation Wizard - Step 1"),
                  @content_instMaster,
                  @help_text_instMaster,
                  false,
                  true
                )
                break
              elsif @button == :abort
                if Popup.ReallyAbort(false)
                  umountSources(true)
                  return :abort
                end
              end
            end
        end

        #/ now we start copy installation master - this must be done always (not local)
        @checkLocal = false
        copyFiles(@instMasterPath, @targetDir, @instMasterDir, @checkLocal)

        # TODO clean remove of SWPM_TMP directory needed...
        SCR.Execute(path(".target.bash"), "rm -rf /dev/shm/InstMaster_SWPM/")


        # Find the local inst master directories with same instmaster
        if Ops.greater_than(@prodCount, 0)
          @localIMPathList = SAPMedia.find_local_IM(
            @tmpTargetDir,
            @prodCount,
            @instMasterDir
          )
          Builtins.y2milestone(
            "### Found installed productes locally at %1",
            @localIMPathList
          )
        end

        #  after the copy we have the installmaster available on disk in our targetdir
        #  -> switch the variable INSTMASTER to our path on disk after the above copy
        @instMasterPath = Ops.add(Ops.add(@targetDir, "/"), @instMasterDir)

#######
# Evaulating the selected product. 
######
        # only for BOBJ Media workflow
        if @instMasterType == "BOBJ"
          parseXML(Ops.add(Ops.add(@instMasterPath, "/"), @productXML))

          # get the right script from our mediachanger.xml file
          @INSTALL = "BOBJ"

          # Now we can unmount our instmaster  (bobj case)
          umountSources(@umountSource) 

          # HANA workflow
        elsif @instMasterType == "HANA"
          parseXML(Ops.add(Ops.add(@instMasterPath, "/"), @productXML))

          # get the right script from our mediachanger.xml file
          @DATABASE = "HDB"
          @INSTALL = "HANA"
          @TYPE = "HANA"
          Ops.set(@PRODUCT_ID, 0, "HANA")

          # add our ASK Dialogs depending on the choosen Product and installtype
          @filename = Convert.to_string(SAPInst.ConfigValue(@INSTALL, "ay_xml"))
          parseXML(Ops.add(Ops.add(@productXMLPath, "/"), @filename))

          # Now we can unmount our instmaster (hana case)
          umountSources(@umountSource) 

          # Workflow for B1. There are actually two B1 products:
          # B1AH: SAP Business One, version for SAP HANA (HANA-only, Linux-only)
          # B1A:  SAP Business One Analytics, powered by SAP HANA (side-car with MS SQL)
        elsif Builtins.contains(["B1AH", "B1A", "B1H"], @instMasterType)
          @INSTALL = "B1"
          @DATABASE = ""
          @TYPE = "B1"
          Ops.set(@PRODUCT_ID, 0, @instMasterType)

          # add our ASK Dialogs depending on the choosen Product and installtype
          @filename = Convert.to_string(SAPInst.ConfigValue(@INSTALL, "ay_xml"))
          parseXML(Ops.add(Ops.add(@productXMLPath, "/"), @filename))

          # Now we can unmount our instmaster (b1ah case)
          WFM.Execute(path(".local.umount"), @mountpoint) if @umountSource 

          # dummy workflow for StorageBasedCopy (SBC)
        elsif @choosenProduct == "SBC"
          @INSTALL = "SBC"
          @STACK = ""
          @DATABASE = ""
          @TYPE = ""

          # Now we can unmount our instmaster (SBC case)
          umountSources(@umountSource)

          # we need the search criteria depending on our previous findings
          @SEARCH = Convert.to_string(SAPInst.ConfigValue(@INSTALL, "search"))

          # In SBC SEARCH defines the PRODUCT_ID directly
          Ops.set(@PRODUCT_ID, 0, @SEARCH)

          # add our ASK Dialogs depending on the choosen Product and installtype
          @filename = Convert.to_string(SAPInst.ConfigValue(@INSTALL, "ay_xml"))
          parseXML(Ops.add(Ops.add(@productXMLPath, "/"), @filename)) 

        else
# Start sapinst workflow
# sapinst workflow
          # Now we can do product dependent things
          @productType = SAPMedia.type_of_product(@choosenProduct)

#SART TREX GATEWY WEBDISPATCHER
          # ES has the same workflow as Standalone Products
          if @productType == "STANDALONE" || @choosenProduct == "ES72"
            if @choosenProduct == "ES72"
              @INSTALL = "ES"
              @STACK = ""
              @TYPE = ""
            else
              @TYPE = @productType

              # All standalones are subproducts under netweaver
              @subProduct = @choosenProduct

              # set choosenProduct to "netweaver"
              @choosenProduct = Ops.get_string(
                @productMap,
                [@subProduct, "nw"],
                ""
              )
              @ltmp = Builtins.regexptokenize(
                @subProduct,
                Ops.add(@choosenProduct, "-(.*)")
              )
              @subProduct = Ops.get_string(@ltmp, 0, "")
              Builtins.y2milestone(
                "MainProduct:%1 SubProduct=%2",
                @choosenProduct,
                @subProduct
              )

              if @subProduct == "TREX"
                @INSTALL = @subProduct
                @STACK = @subProduct
              elsif @subProduct == "GATEWAY"
                @INSTALL = "GW"
                @STACK = ""
              elsif @subProduct == "WEBDISPATCHER"
                @INSTALL = "WD"
                @STACK = ""
              end
            end

            # read needed media from ini file
            @mediaList = Convert.convert(
              SAPInst.ConfigValue(@INSTALL, "media"),
              :from => "any",
              :to   => "list <string>"
            )

            # read in all labels for that medialist
            # It does not matter which, because for one product they are identical
            # so we go with the defaults ADA,PD here
            @LABEL_HASH_ref = SAPMedia.collect_labels_for_product(
              @choosenProduct,
              @instMasterPath,
              Ops.add(@choosenProduct, "/ADA/PD"),
              @mediaList
            )

            # first try to copy all from the instmaster media (thats the medium which is still inserted )
            @mediaMap = SAPMedia.check_media(
              @sourceDir,
              @mediaList,
              @LABEL_HASH_ref
            )

            Builtins.foreach(@mediaMap) do |key, val|
              @run = false
              Builtins.y2milestone("FIRST TRY==> key=%1 val=%2", key, val)
              Builtins.y2milestone("Copy Media from VAL:%1", val)
              @checkLocal = true
              copyFiles(val, @targetDir, key, @checkLocal)
              @LABEL_HASH_ref = Builtins.remove(@LABEL_HASH_ref, key)
            end

            #SEARCH = (string)SAPInst.ConfigValue( INSTALL, "search" );
            #PRODUCT_ID = SAPMedia::search_sapinst_id(instMasterPath,instMasterVersion,choosenProduct,STACK,DATABASE,TYPE,SEARCH,INSTALL);
            #y2milestone("Prognosis: search_sapinst_id: %1 %2",SEARCH,PRODUCT_ID);

            # Now we can unmount our instmaster (standalone case)
            umountSources(@umountSource)

            #///////////////////////////////////////////////////////////////////////////
            #
            # Wizard Page - additionally ask for the STANDALONE Media
            #
            #///////////////////////////////////////////////////////////////////////////
            @help_text = _(
              "<p>Please enter the location of the requested medium.</p>"
            )
            @contents = VBox(
              HBox(
                ComboBox(Id(:scheme), Opt(:notify), " ", @scheme_list),
                TextEntry(
                  Id(:location),
                  "Location of the medium",
                  @locationString
                )
              )
            )
            Wizard.SetContents(
              _("SAP Installation Wizard - Standalone Products"),
              @contents,
              @help_text,
              false,
              true
            )
            UI.ChangeWidget(:scheme, :Value, @schemeCache)
            doDefaultValue
            while Ops.greater_than(Builtins.size(@LABEL_HASH_ref), 0)
              Builtins.foreach(@LABEL_HASH_ref) do |key, v|
                UI.ChangeWidget(
                  Id(:location),
                  :Label,
                  Builtins.sformat(
                    "Please provide the location of the medium with the label: %1",
                    Ops.get(@LABEL_HASH_ref, [key, "mediaName"], "")
                  )
                )
                raise Break
              end
              @button = UI.UserInput
              @scheme = Convert.to_symbol(UI.QueryWidget(Id(:scheme), :Value))
              @location = Convert.to_string(
                UI.QueryWidget(Id(:location), :Value)
              )
              @sourceDir2 = @location
              @umountSource2 = false

              if @button == :scheme
                doDefaultValue
                next
              end

              if @button == :abort
                if Popup.ReallyAbort(false)
                  umountSources(true)
                  return :abort
                end
                next
              end
              @urlPath = mountSource(@scheme, @location, @mountpoint)
              @ltmp = Builtins.regexptokenize(@urlPath, "ERROR:(.*)")
              if Ops.get_string(@ltmp, 0, "") != ""
                Popup.Error(
                  Ops.add(_("Mounting failed: "), Ops.get_string(@ltmp, 0, ""))
                )
                next
              end
              if @scheme != :local
                @sourceDir2 = Ops.add(Ops.add(@mountpoint, "/"), @urlPath)
              elsif @urlPath != ""
                @sourceDir2 = @urlPath
              end

              @umountSource2 = true

              @mediaMap2 = {}

              @mediaMap2 = SAPMedia.check_media(
                @sourceDir2,
                @mediaList,
                @LABEL_HASH_ref
              )

              if @mediaMap2 == {}
                Popup.Error(
                  _(
                    "This is not the right medium - please choose a usable medium"
                  )
                )
                umountSources(@umountSource2)
                next
              end

              Builtins.foreach(@mediaMap2) do |key, val|
                Builtins.y2milestone("NOW COPY: key=%1 val=%2", key, val)
                @checkLocal = true
                copyFiles(val, @targetDir, key, @checkLocal)
                @LABEL_HASH_ref = Builtins.remove(@LABEL_HASH_ref, key)
              end
              umountSources(@umountSource2)
            end
            # we need the search criteria depending on our privious findings
            @SEARCH = Convert.to_string(SAPInst.ConfigValue(@INSTALL, "search"))

            # add our ASK Dialogs depending on the choosen Product and installtype
            @filename = Convert.to_string(SAPInst.ConfigValue(@INSTALL, "ay_xml"))
            parseXML(Ops.add(Ops.add(@productXMLPath, "/"), @filename))
          else
#END TREX GATEWY WEBDISPATCHER

            #///////////////////////////////////////////////////////////////////////////
            #
            # Wizard Page 3 (optional - for non-STANDALONE)
            #
            #///////////////////////////////////////////////////////////////////////////
            #SEARCH = (string)SAPInst.ConfigValue( INSTALL, "search" );
            #PRODUCT_ID = SAPMedia::search_sapinst_id(instMasterPath,instMasterVersion,choosenProduct,STACK,DATABASE,TYPE,SEARCH,INSTALL);
            #y2milestone("Prognosis 2: search_sapinst_id: %1 %2",SEARCH,PRODUCT_ID);
#START NEED SAP LOOP
            # Check if we need to install the additional feature SAPLUP (Diagnostic Agent)
            @needSaplup = SAPMedia.needSaplup(@instMasterPath)
            Builtins.y2milestone("Need SAPLUP %1", @needSaplup)
            if @needSaplup
              @ownSaplupMedia = false 
              # TODO IBM Java not needed anymore with SWPM
              # needJCECrypto = true;
            end

            # Now we can unmount our instmaster (normal case)
            umountSources(@umountSource)

#END NEED SAP LOOP


#START DB
#END DB

#START KERNEL
#END KERNEL

#START DI/CI
            #///////////////////////////////////////////////////////////////////////////
            #
            # Wizard Page 5 - Ask for DI or CI
            #
            #///////////////////////////////////////////////////////////////////////////
            @help_text = _(
              "<p>Please select if you want to perform a central system installation (default) or if you want to install a dialog instance.</p>"
            )
            @contents = VBox(
              HBox(
                RadioButtonGroup(
                  Id(:rbg_type),
                  VBox(
                    Left(RadioButton(Id(:di), _("&Dialog [DI]"), false)),
                    Left(
                      RadioButton(
                        Id(:ci),
                        _("&Central Installation [CI]"),
                        true
                      )
                    )
                  )
                )
              )
            )
            Wizard.SetContents(
              _("SAP Installation Wizard - Step 4: Type of Installation"),
              @contents,
              @help_text,
              false,
              true
            )
            @type = nil
            @run = true
            while @run
              @button = UI.UserInput
              @type = Convert.to_symbol(
                UI.QueryWidget(Id(:rbg_type), :CurrentButton)
              )
              Builtins.y2milestone("BUTTON = %1", @type)
              @run = false
              if @button == :abort
                if Popup.ReallyAbort(false)
                  umountSources(true)
                  return :abort
                end
                @run = true
              end
            end
#END DI/CI

#START READ SAPLUP
            #///////////////////////////////////////////////////////////////////////////
            #
            # Wizard Page 6 - Ask SAPLUP if needed
            #
            #///////////////////////////////////////////////////////////////////////////

            Builtins.y2milestone("needSaplup:%1", @needSaplup)

            if @needSaplup && (@STACK == "AS-JAVA" || @ownSaplupMedia)
              @MediaMap = { "SAPLUP" => "" }
              @RetMediaMap = {}

              @MediaList = Builtins.maplist(@MediaMap) { |k, v| k }

              Builtins.y2milestone("MediaList %1", @MediaList)
              Builtins.y2milestone("MediaMap %1", @MediaMap)
              Builtins.y2milestone("RetMediaMap %1", @RetMediaMap)

              # Try to look if we have it localy
              Builtins.foreach(@localIMPathList) do |s|
                @RetMediaMap = SAPMedia.check_media(
                  s,
                  @MediaList,
                  @LABEL_HASH_ref
                )
                if @RetMediaMap != {}
                  Builtins.y2milestone("Local directory found: %1", s)
                  raise Break
                end
              end

              if @RetMediaMap != {}
                Builtins.foreach(@RetMediaMap) do |key, val|
                  Builtins.y2milestone("A key=%1 val=%2", key, val)
                  Builtins.y2milestone("A MediaMap %1", @MediaMap)
                  @checkLocal = true
                  copyFiles(val, @targetDir, key, @checkLocal)
                  @LABEL_HASH_ref = Builtins.remove(@LABEL_HASH_ref, key)
                  @MediaMap = Builtins.remove(@MediaMap, key)
                  Builtins.y2milestone("B MediaMap %1", @MediaMap)
                end
              else
                @help_text = _(
                  "<p>The Diagnostic Agent needs additional media. Please enter the path to the required medium.</p>"
                )
                @contents = VBox(
                  HBox(
                    ComboBox(Id(:scheme), Opt(:notify), " ", @scheme_list),
                    TextEntry(
                      Id(:location),
                      "Location of the Media",
                      @locationString
                    )
                  )
                )
                Wizard.SetContents(
                  _(
                    "SAP Installation Wizard - additional Diagnostic Agent Media"
                  ),
                  @contents,
                  @help_text,
                  false,
                  true
                )
                UI.ChangeWidget(:scheme, :Value, @schemeCache)
                doDefaultValue

                while Ops.greater_than(Builtins.size(@MediaMap), 0)
                  Builtins.foreach(@MediaMap) do |key, v|
                    Wizard.SetContents(
                      _(
                        "SAP Installation Wizard - additional Diagnostic Agent Media"
                      ),
                      @contents,
                      @help_text,
                      false,
                      true
                    )
                    UI.ChangeWidget(:scheme, :Value, @schemeCache)
                    doDefaultValue
                    UI.ChangeWidget(
                      Id(:location),
                      :Label,
                      Builtins.sformat(
                        "Please provide the path to the medium with the label: %1 (SL Controller)",
                        Ops.get(@LABEL_HASH_ref, [key, "mediaName"], "")
                      )
                    )
                    Builtins.y2milestone(
                      "Ask for key=%1 val=%2 label=%3 (SL Controller)",
                      key,
                      v,
                      Ops.get(@LABEL_HASH_ref, [key, "mediaName"], "")
                    )
                    raise Break
                  end

                  @button = UI.UserInput
                  @scheme = Convert.to_symbol(
                    UI.QueryWidget(Id(:scheme), :Value)
                  )
                  @location = Convert.to_string(
                    UI.QueryWidget(Id(:location), :Value)
                  )
                  @sourceDir2 = @location
                  @umountSource2 = false

                  if @button == :scheme
                    doDefaultValue
                    next
                  end
                  if @button == :abort
                    if Popup.ReallyAbort(false)
                      umountSources(true)
                      return :abort
                    end
                    next
                  end
                  @urlPath = mountSource(@scheme, @location, @mountpoint)
                  @ltmp = Builtins.regexptokenize(@urlPath, "ERROR:(.*)")
                  if Ops.get_string(@ltmp, 0, "") != ""
                    Popup.Error(
                      Ops.add(
                        _("Mounting failed: "),
                        Ops.get_string(@ltmp, 0, "")
                      )
                    )
                    next
                  end
                  if @scheme != :local
                    @sourceDir2 = Ops.add(Ops.add(@mountpoint, "/"), @urlPath)
                  elsif @urlPath != ""
                    @sourceDir2 = @urlPath
                  end

                  @umountSource2 = true

                  @MediaList2 = Builtins.maplist(@MediaMap) { |k, v| k }

                  @RetMediaMap = SAPMedia.check_media(
                    @sourceDir2,
                    @MediaList2,
                    @LABEL_HASH_ref
                  )
                  Builtins.y2milestone("-MediaMap %1", @MediaMap)
                  Builtins.y2milestone("-RetMediaMap %1", @RetMediaMap)

                  if @RetMediaMap == {}
                    Popup.Error(
                      _(
                        "This is not the correct medium - please choose a usable medium with the mentioned label"
                      )
                    )
                    umountSources(@umountSource2)
                    next
                  end

                  Builtins.foreach(@RetMediaMap) do |key, val|
                    Builtins.y2milestone("C key=%1 val=%2", key, val)
                    Builtins.y2milestone("C MediaMap %1", @MediaMap)
                    @checkLocal = true
                    copyFiles(val, @targetDir, key, @checkLocal)
                    @LABEL_HASH_ref = Builtins.remove(@LABEL_HASH_ref, key)
                    @MediaMap = Builtins.remove(@MediaMap, key)
                    Builtins.y2milestone("D MediaMap %1", @MediaMap)
                  end
                  umountSources(@umountSource2)
                end
              end
            end

#END SAPLUP

#START READ EXPORTS
            #///////////////////////////////////////////////////////////////////////////
            #
            # Wizard Page 6 - Ask EXPORTS if needed
            #
            #///////////////////////////////////////////////////////////////////////////
            if @type == :ci
              @TYPE = "CENTRAL"

              # FIXME
              # Try to check at this point - means before we do a heavy copy of the export media -
              # if we are able to find a SAP-Product-ID.
              # If not there may be something wrong - Tell the user that something is wrong here
              # and the "automatic" mode is disabled now, this means SAPINST will do all missing things

              @help_text = _(
                "<p>Please provide the media with the SAP system export you want to use for the installation.</p>"
              )
              @contents = VBox(
                HBox(
                  ComboBox(Id(:scheme), Opt(:notify), " ", @scheme_list),
                  TextEntry(
                    Id(:location),
                    "Location of the Export Media",
                    @locationString
                  )
                )
              )
              Wizard.SetContents(
                _("SAP Installation Wizard - Step 5: Export Media"),
                @contents,
                @help_text,
                false,
                true
              )
              UI.ChangeWidget(:scheme, :Value, @schemeCache)
              doDefaultValue

              @run = true
              @cdCounter = 0

              while @run
                @button = UI.UserInput
                @scheme = Convert.to_symbol(UI.QueryWidget(Id(:scheme), :Value))
                @location = Convert.to_string(
                  UI.QueryWidget(Id(:location), :Value)
                )
                @sourceDir2 = @location
                @umountSource2 = false

                if @button == :scheme
                  doDefaultValue
                  next
                end

                if @button == :abort
                  if Popup.ReallyAbort(false)
                    umountSources(true)
                    return :abort
                  end
                  next
                end
                @urlPath = mountSource(@scheme, @location, @mountpoint)
                @ltmp = Builtins.regexptokenize(@urlPath, "ERROR:(.*)")
                if Ops.get_string(@ltmp, 0, "") != ""
                  Popup.Error(
                    Ops.add(
                      _("Mounting failed: "),
                      Ops.get_string(@ltmp, 0, "")
                    )
                  )
                  next
                end
                if @scheme != :local
                  @sourceDir2 = Ops.add(Ops.add(@mountpoint, "/"), @urlPath)
                elsif @urlPath != ""
                  @sourceDir2 = @urlPath
                end

                @umountSource2 = true

                # Target Dir for export medias for systemcopy
                @ExpDir = ""

                if @cdCounter == 0
                  # reicht es hier "JMIG" (Java) einfach wie "MIGEXPORT1" (ABAP) zu behandeln?!
                  @dbMap = SAPMedia.check_media(
                    @sourceDir2,
                    ["^EXPORT", "MIGEXPORT1", "JAVA_EXPORT", "JMIG"],
                    @LABEL_HASH_ref
                  )

                  if @dbMap == {}
                    Popup.Error(
                      _(
                        "This is not an allowed Export Medium - please choose a usable medium"
                      )
                    )
                    umountSources(@umountSource2)
                    next
                  end
                  Builtins.foreach(@dbMap) do |key, val|
                    @run = false
                    Builtins.y2milestone("key=%1 val=%2", key, val)
                    @checkLocal = false
                    copyFiles(val, @targetDir, key, @checkLocal)
                    @LABEL_HASH_ref = Builtins.remove(@LABEL_HASH_ref, key)
                    if Builtins.substring(key, 0, 6) == "EXPORT" ||
                        key == "JAVA_EXPORT"
                      @INSTALL = "PD"
                    elsif key == "MIGEXPORT1" || key == "JMIG"
                      @INSTALL = "COPY"
                      # remember the key as target dir
                      @ExpDir = key
                    else
                      @INSTALL = ""
                    end
                  end
                  Wizard.SetContents(
                    _("SAP Installation Wizard - Step 5: Export Media"),
                    @contents,
                    @help_text,
                    false,
                    true
                  )
                  # then second media in the ABAP case  - is not be used in java case
                  Builtins.foreach(@LABEL_HASH_ref) do |key, v|
                    if Builtins.substring(key, 0, 6) == "EXPORT" &&
                        @INSTALL == "PD"
                      Builtins.y2milestone("key=%1 val=%2", key, v)
                      UI.ChangeWidget(:scheme, :Value, @schemeCache)
                      doDefaultValue
                      UI.ChangeWidget(
                        Id(:location),
                        :Label,
                        Builtins.sformat(
                          "Please provide the path to the medium with the label: %1",
                          Ops.get(@LABEL_HASH_ref, [key, "mediaName"], "")
                        )
                      )
                      @run = true
                      raise Break
                    end
                  end
                elsif Ops.greater_than(@cdCounter, 0) && @INSTALL == "COPY"
                  # copy the second media
                  # - we never have it local!
                  @checkLocal = false
                  copyFiles(@sourceDir2, @targetDir, @ExpDir, @checkLocal)
                  @run = true
                  Builtins.y2milestone("copy second export media")
                end
                # wenn MIG_EXPORT -> Frage ob noch ein weiteres Medium vorhanden.
                #    Ja, dann Medien (ohne LABEL!!) in "ExpDir" kopieren solange bis nein -> weiter
                if @INSTALL == "COPY"
                  if Popup.YesNo("Do you have an additional Export Media?")
                    Builtins.y2milestone("addidional MIG_EXPORT media")
                    Wizard.SetContents(
                      _("SAP Installation Wizard - Step 5: Export Media"),
                      @contents,
                      @help_text,
                      false,
                      true
                    )
                    UI.ChangeWidget(:scheme, :Value, @schemeCache)
                    doDefaultValue
                    UI.ChangeWidget(
                      Id(:location),
                      :Label,
                      Builtins.sformat(
                        "Please provide the location of the additional Export Media"
                      )
                    )
                    @run = true
                    @cdCounter = Ops.add(@cdCounter, 1)
                  else
                    Builtins.y2milestone("no further export media")
                    @run = false
                  end
                end
                umountSources(@umountSource2)
              end
              Builtins.y2milestone("INSTALL = %1", @INSTALL)
            else
              # Dialog instance installation
              @TYPE = "DIALOG" # must be DIALOG
              @INSTALL = "LM" # life under LiveCyle
            end

            if @STACK == "AS-JAVA"
              Builtins.y2milestone("JAVA Stack - additional media needed")

              # TODO IBM Java not needed anymore with SWPM
              # // If needIBMJava JCE Crypto is manadatory
              # needJCECrypto = needIBMJava;

              # if we have JAVA as Stack we need a few additional media - so here a new Wizard Page
              #///////////////////////////////////////////////////////////////////////////
              #
              # Wizard Page - ask for additional Java Media
              #
              #///////////////////////////////////////////////////////////////////////////

              @javaMediaMap = {
                "J2EE"      => "",
                "J2EE-INST" => "",
                "UKERNEL"   => ""
              }

              if @INSTALL == "PD"
                @javaMediaMap = {
                  "J2EE"      => "",
                  "J2EE-INST" => "",
                  "UKERNEL"   => "",
                  "SCA_2"     => ""
                }
              end

              @help_text = _(
                "<p>The JAVA Stack needs additional media. Please enter the path to the required medium.</p>"
              )
              @contents = VBox(
                HBox(
                  ComboBox(Id(:scheme), Opt(:notify), " ", @scheme_list),
                  TextEntry(
                    Id(:location),
                    "Location of the Media",
                    @locationString
                  )
                )
              )
              Wizard.SetContents(
                _("SAP Installation Wizard - additional Java Media"),
                @contents,
                @help_text,
                false,
                true
              )
              UI.ChangeWidget(:scheme, :Value, @schemeCache)
              doDefaultValue

              while Ops.greater_than(Builtins.size(@javaMediaMap), 0)
                Builtins.foreach(@javaMediaMap) do |key, v|
                  Wizard.SetContents(
                    _("SAP Installation Wizard - additional Java Media"),
                    @contents,
                    @help_text,
                    false,
                    true
                  )
                  UI.ChangeWidget(:scheme, :Value, @schemeCache)
                  doDefaultValue
                  UI.ChangeWidget(
                    Id(:location),
                    :Label,
                    Builtins.sformat(
                      "Please provide the path to the medium with the label: %1",
                      Ops.get(@LABEL_HASH_ref, [key, "mediaName"], "")
                    )
                  )
                  Builtins.y2milestone(
                    "Frage nach key=%1 val=%2 label=%3",
                    key,
                    v,
                    Ops.get(@LABEL_HASH_ref, [key, "mediaName"], "")
                  )
                  raise Break
                end
                @button = UI.UserInput
                @scheme = Convert.to_symbol(UI.QueryWidget(Id(:scheme), :Value))
                @location = Convert.to_string(
                  UI.QueryWidget(Id(:location), :Value)
                )
                @sourceDir2 = @location
                @umountSource2 = false

                if @button == :scheme
                  doDefaultValue
                  next
                end
                if @button == :abort
                  if Popup.ReallyAbort(false)
                    umountSources(true)
                    return :abort
                  end
                  next
                end
                @urlPath = mountSource(@scheme, @location, @mountpoint)
                @ltmp = Builtins.regexptokenize(@urlPath, "ERROR:(.*)")
                if Ops.get_string(@ltmp, 0, "") != ""
                  Popup.Error(
                    Ops.add(
                      _("Mounting failed: "),
                      Ops.get_string(@ltmp, 0, "")
                    )
                  )
                  next
                end
                if @scheme != :local
                  @sourceDir2 = Ops.add(Ops.add(@mountpoint, "/"), @urlPath)
                elsif @urlPath != ""
                  @sourceDir2 = @urlPath
                end

                @umountSource2 = true

                @javaMediaList = Builtins.maplist(@javaMediaMap) { |k, v| k }

                @jMediaMap = {}
                @jMediaMap = SAPMedia.check_media(
                  @sourceDir2,
                  @javaMediaList,
                  @LABEL_HASH_ref
                )

                Builtins.y2milestone("javaMediaMap %1", @javaMediaMap)
                Builtins.y2milestone("jMediaMap %1", @jMediaMap)

                if @jMediaMap == {}
                  Popup.Error(
                    _(
                      "This is not the correct medium - please choose a usable medium"
                    )
                  )
                  umountSources(@umountSource2)
                  next
                end

                Builtins.foreach(@jMediaMap) do |key, val|
                  Builtins.y2milestone("A key=%1 val=%2", key, val)
                  Builtins.y2milestone("A javaMediaMap %1", @javaMediaMap)
                  @checkLocal = true
                  copyFiles(val, @targetDir, key, @checkLocal)
                  @LABEL_HASH_ref = Builtins.remove(@LABEL_HASH_ref, key)
                  @javaMediaMap = Builtins.remove(@javaMediaMap, key)
                  Builtins.y2milestone("B javaMediaMap %1", @javaMediaMap)
                end
                umountSources(@umountSource2)
              end
            else
              @haveCrypto = Convert.to_integer(
                SCR.Execute(
                  path(".target.bash"),
                  Ops.add(
                    Ops.add("find '", @targetDir),
                    "' -type f -name SAPCRYPTO.SAR | grep -q SAPCRYPTO.SAR"
                  )
                )
              ) == 0
              if @needIBMJava && @needSaplup && @haveCrypto
                @haveCrypto = Convert.to_integer(
                  SCR.Execute(
                    path(".target.bash"),
                    Ops.add(
                      Ops.add("find '", @targetDir),
                      "' -type f -name 'jce_policy.*zip' | grep -q jce_policy."
                    )
                  )
                ) == 0
              end
              if !@haveCrypto
                if !@needSAPCrypto &&
                    Popup.YesNo(
                      "Do you want to copy a CryptoAddOn medium, to enable encryption?"
                    )
                  Builtins.y2milestone("manual added CryptoAddOn")
                  @needSAPCrypto = true
                end
              end
            end

            # we need the search criteria depending on our privious findings
            @SEARCH = Convert.to_string(
              SAPInst.ConfigValue(Ops.add(Ops.add(@STACK, "_"), @INSTALL), "search")
            )

            # add our ASK Dialogs depending on the choosen Product and installtype
            @filename = Convert.to_string(
              SAPInst.ConfigValue(Ops.add(Ops.add(@STACK, "_"), @INSTALL), "ay_xml")
            )
            parseXML(Ops.add(Ops.add(@productXMLPath, "/"), @filename)) 

            # end else db-based-product
          end

          # TODO IBM Java not needed anymore with SWPM
          # if( !haveCrypto && ( needSAPCrypto || needJCECrypto )){
          if !@haveCrypto && @needSAPCrypto
            #///////////////////////////////////////////////////////////////////////////
            #
            # Wizard Page - Ask for CryptoAddOn media
            #
            #///////////////////////////////////////////////////////////////////////////

            @targetLabel = "CryptoAddOn"
            @run = true

            @fileFound = true
            @jceFound = false
            @sapcFound = false
            Builtins.foreach(@localIMPathList) do |localIMPath|
              @fileFound = true
              fileList = Convert.convert(
                SCR.Read(
                  path(".target.dir"),
                  Ops.add(Ops.add(localIMPath, "/"), @targetLabel)
                ),
                :from => "any",
                :to   => "list <string>"
              )
              Builtins.foreach(fileList) do |file|
                if Builtins.regexpmatch(file, "jce_policy.*.zip")
                  @jceFound = true
                elsif file == "SAPCRYPTO.SAR"
                  @sapcFound = true
                end
                raise Break if @jceFound && @sapcFound
              end
              # TODO IBM Java not needed anymore with SWPM
              # if( needJCECrypto && !jceFound )
              #     fileFound = false;
              @fileFound = false if @needSAPCrypto && !@sapcFound
              if @fileFound
                Builtins.y2milestone("Found a local CryptoAddOn to use")
                @checkLocal = false # because we don't have a label file
                copyFiles(
                  Ops.add(Ops.add(localIMPath, "/"), @targetLabel),
                  @targetDir,
                  @targetLabel,
                  @checkLocal
                )
                # we are ready now, can break the loop and don't need the nxt screen
                @run = false
                raise Break
              end
            end
            # don't display it if we copied automtical before
            if @run
              @contents = VBox(
                HBox(
                  ComboBox(Id(:scheme), Opt(:notify), " ", @scheme_list),
                  TextEntry(
                    Id(:location),
                    "Location of the CryptoAddOn Medium",
                    @locationString
                  )
                )
              )
              # TODO IBM Java not needed anymore with SWPM
              # if( needJCECrypto && needSAPCrypto )
              #            help_text = _("Please enter the path to the medium with the required crypto files. Allowed names are SAPCRYPTO.SAR and jce_policy-<version>.zip.");
              # else if( needJCECrypto )
              #            help_text = _("Please enter the path to the medium with the required crypto file. Allowed names are jce_policy-<version>.zip.");
              # else if( needSAPCrypto )
              if @needSAPCrypto
                @help_text = _(
                  "Please enter the path to the medium with the required crypto file. Allowed name is SAPCRYPTO.SAR."
                )
              end

              Wizard.SetContents(
                _("SAP Installation Wizard - Step 6: CryptoAddOn Medium"),
                @contents,
                @help_text,
                false,
                true
              )
              UI.ChangeWidget(:scheme, :Value, @schemeCache)
              doDefaultValue
            end
            while @run
              @button = UI.UserInput
              @scheme = Convert.to_symbol(UI.QueryWidget(Id(:scheme), :Value))
              @location = Convert.to_string(
                UI.QueryWidget(Id(:location), :Value)
              )
              @sourceDir2 = @location
              @umountSource2 = false

              if @button == :scheme
                doDefaultValue
                next
              end
              if @button == :abort
                if Popup.ReallyAbort(false)
                  umountSources(true)
                  return :abort
                end
                next
              end
              @urlPath = mountSource(@scheme, @location, @mountpoint)
              @ltmp = Builtins.regexptokenize(@urlPath, "ERROR:(.*)")
              if Ops.get_string(@ltmp, 0, "") != ""
                Popup.Error(
                  Ops.add(_("Mounting failed: "), Ops.get_string(@ltmp, 0, ""))
                )
                next
              end
              if @scheme != :local
                @sourceDir2 = Ops.add(Ops.add(@mountpoint, "/"), @urlPath)
              elsif @urlPath != ""
                @sourceDir2 = @urlPath
              end

              @umountSource2 = true

              # check if it contains the right files
              # read in dir
              @fileFound = true
              @jceFound = false
              @sapcFound = false
              # check if it contains the right files
              # read in dir
              @fileList = Convert.convert(
                SCR.Read(path(".target.dir"), @sourceDir2),
                :from => "any",
                :to   => "list <string>"
              )
              Builtins.foreach(@fileList) do |file|
                if Builtins.regexpmatch(file, "jce_policy.*.zip")
                  @jceFound = true
                elsif file == "SAPCRYPTO.SAR"
                  @sapcFound = true
                end
                raise Break if @jceFound && @sapcFound
              end
              # TODO IBM Java not needed anymore with SWPM
              # if( needJCECrypto && !jceFound )
              #     fileFound = false;
              @fileFound = false if @needSAPCrypto && !@sapcFound
              if @fileFound
                @checkLocal = false # because we don't have a label file
                copyFiles(@sourceDir2, @targetDir, @targetLabel, @checkLocal)
                @run = false
              else
                # TODO IBM Java not needed anymore with SWPM
                # if( needJCECrypto && needSAPCrypto && !jceFound && !sapcFound )
                #             Popup::Error( _("The required CryptoAddOn files were not found. Please use another media!") );
                # else if( needJCECrypto && !jceFound )
                #             Popup::Error( _("The CryptoAddOn Medium did not contain a file with the name jce_policy-<version>.zip. Please use another media!") );
                # else if( needSAPCrypto && !sapcFound )
                if @needSAPCrypto && !@sapcFound
                  Popup.Error(
                    _(
                      "The CryptoAddOn Medium did not contain a file with the name SAPCRYPTO.SAR. Please use another media!"
                    )
                  )
                end
                @run = true
              end
              umountSources(@umountSource2)
            end
          end #end need crypto

          # Clear our screen
          Wizard.ClearContents

          # we need sapinst version 7.2 as minimum
          @sapVersion = SAPMedia.get_sapinst_version(@instMasterPath)
          if @sapVersion == -1
            #If we can not detect the SAP version, we can not go on. We abort the installation. This can happen after
            #copying the Kernel or JAVA and SAPLUP media. The reason can be bad access rights.
            Popup.Error(
              _(
                "The sapinst executable can not be found or it is not executable. This is a fatal error, because we need the SAP Installer"
              )
            )
            return :abort
          end
          Builtins.y2milestone("found instmaster version %1", @sapVersion)

          if Ops.less_than(@sapVersion, @sapMinVersion)
            #///////////////////////////////////////////////////////////////////////////
            #
            # Wizard Page XY - additional Instmaster tasks if we do not have the right
            #                  sapinst version

            @help_text = _(
              "<p>Your installation set uses a version of SAPINST with missing functionality. Please enter the path to an additional Installation Master containing a newer SAPINST.</p>"
            )
            @content_new_master = HBox(
              VBox(HSpacing(13)),
              VBox(
                HBox(
                  Label(
                    "A newer version of SAPINST is required in addition. Please provide the path to a newer Installation Master."
                  )
                ),
                HBox(
                  HSpacing(13),
                  ComboBox(Id(:scheme), Opt(:notify), " ", @scheme_list),
                  TextEntry(
                    Id(:location),
                    "Location of the Installation Master",
                    @locationString
                  ),
                  HSpacing(30)
                )
              ),
              VBox(HSpacing(13))
            )
            Wizard.SetContents(
              _("SAP Installation Wizard - Newer SAPINST"),
              @content_new_master,
              @help_text,
              false,
              true
            )
            UI.ChangeWidget(:scheme, :Value, @schemeCache)
            doDefaultValue

            Popup.Warning(
              Ops.add(
                Ops.add(
                  Ops.add(
                    Ops.add(
                      "The SAPINST executable version is not the right one (found ",
                      @sapVersion
                    ),
                    " need "
                  ),
                  @sapMinVersion
                ),
                "). Please use another Installation Master Medium."
              )
            )

            @run = true
            while @run
              @button = UI.UserInput
              @scheme = Convert.to_symbol(UI.QueryWidget(Id(:scheme), :Value))
              @location = Convert.to_string(
                UI.QueryWidget(Id(:location), :Value)
              )
              @sourceDir2 = @location
              @umountSource2 = false

              if @button == :scheme
                doDefaultValue
                next
              end

              if @button == :abort
                if Popup.ReallyAbort(false)
                  umountSources(true)
                  return :abort
                end
                next
              end
              @urlPath = mountSource(@scheme, @location, @mountpoint)
              @ltmp = Builtins.regexptokenize(@urlPath, "ERROR:(.*)")
              if Ops.get_string(@ltmp, 0, "") != ""
                Popup.Error(
                  Ops.add(_("Mounting failed: "), Ops.get_string(@ltmp, 0, ""))
                )
                next
              end
              if @scheme != :local
                @sourceDir2 = Ops.add(Ops.add(@mountpoint, "/"), @urlPath)
              elsif @urlPath != ""
                @sourceDir2 = @urlPath
              end

              @umountSource2 = true
              Popup.ShowFeedback("Search", "Searching ...")

              @instMasterList = SAPMedia.is_instmaster(@sourceDir2)
              @newinstMasterType = Ops.get(@instMasterList, 0, "")
              @newinstMasterPath = Ops.get(@instMasterList, 1, "")
              Builtins.y2milestone("New sapinst path: %1", @newinstMasterPath)

              if @newinstMasterPath != nil &&
                  Ops.greater_than(Builtins.size(@newinstMasterPath), 0)
                @sapVersion = SAPMedia.get_sapinst_version(@newinstMasterPath)
                if @sapVersion == -1
                  #If we can not detect the SAP version, we can not go on. We abort the installation. This can happen after
                  #copying the Kernel or JAVA and SAPLUP media. The reason can be bad access rights.
                  Popup.Error(
                    _(
                      "The sapinst executable can not be found or it is not executable. This is a fatal error, because we need the SAP Installer"
                    )
                  )
                  return :abort
                end
                Builtins.y2milestone("New sapinst version: %1", @sapVersion)

                if Ops.greater_or_equal(@sapVersion, @sapMinVersion)
                  @run = false

                  # we need the complete path to new sapinst executable and the control.dtd
                  @sourcefileHash = SAPMedia.get_sapinst_path(
                    @newinstMasterPath
                  )
                  # we need the complete path to the old sapinst executable and the control.dtd
                  @targetfileHash2 = SAPMedia.get_sapinst_path(@instMasterPath)

                  #copy it over the original ones
                  Builtins.foreach(@sourcefileHash) do |key, sourcefile|
                    Builtins.y2milestone(
                      "DEBUG SourceFile : %1 %2",
                      key,
                      Ops.get(@sourcefileHash, key, "")
                    )
                    Builtins.y2milestone(
                      "DEBUG TargetFile : %1 %2",
                      key,
                      Ops.get(@targetfileHash2, key, "")
                    )
                    cmd = Builtins.sformat(
                      "cp -f '%1' '%2'",
                      Ops.get(@sourcefileHash, key, ""),
                      Ops.get(@targetfileHash2, key, "")
                    )
                    Builtins.y2milestone("Copy files: %1", cmd)
                    # check if cp was successfull?
                    ok = Convert.to_integer(
                      SCR.Execute(path(".target.bash"), cmd)
                    ) == 0
                    if !ok
                      Builtins.y2milestone("CP failed cmd:%1 ret:%2", cmd, ok)
                      # FIXME - what else to do?
                      @run = true
                    end
                    if key == "control"
                      # Check and set the needed feature in control.dtd
                      ret = SAPMedia.set_sapinst_feature(
                        Ops.get(@targetfileHash2, key, "")
                      )
                      Builtins.y2milestone(
                        "Check and maybe set feature in control.dtd : %1 %2",
                        key,
                        Ops.get(@targetfileHash2, key, "")
                      )
                    end
                  end
                else
                  Popup.ClearFeedback
                  Popup.Error(
                    _(
                      "this is also not the right version of the sapinst executable"
                    )
                  )
                  @run = true
                end
              else
                Popup.ClearFeedback
                Popup.Error(
                  _("cannot find an installation master at the given location")
                )
                @run = true
              end
              Popup.ClearFeedback
              umountSources(@umountSource2)
            end
          end # end sapinst version
#############
# END SAPINST
#############
          # Alex - 26.5: Always check control.dtd and fix it if feature is not here
          @targetfileHash = SAPMedia.get_sapinst_path(@instMasterPath)
          @ret2 = SAPMedia.set_sapinst_feature(
            Ops.get(@targetfileHash, "control", "")
          )
          Builtins.y2milestone(
            "Always check and maybe set feature in control.dtd : %1",
            Ops.get(@targetfileHash, "control", "")
          )

          @tmp2 = Builtins.substring(@DATABASE, 0, 3)
          @DATABASE = "ORA" if @tmp2 == "ORA"
          # search within the products.catalog for the right sap_product_id
          # PRODUCT_ID should only be one record.
          @PRODUCT_ID = SAPMedia.search_sapinst_id(
            @instMasterPath,
            @instMasterVersion,
            @choosenProduct,
            @STACK,
            @DATABASE,
            @TYPE,
            @SEARCH,
            @INSTALL
          )
          #FIXME: PRODUCT_ID should not empty -> popup abort?
          Builtins.y2milestone(
            "SAPMedia::search_sapinst_id(instMaster=%1,choosenProduct=%2,STACK=%3,DATABASE=%4,TYPE=%5,SEARCH=%6,INSTALL=%7);",
            @instMasterPath,
            @choosenProduct,
            @STACK,
            @DATABASE,
            @TYPE,
            @SEARCH,
            @INSTALL
          )
        end # end sap product


        # <script_name> in the XML requires the complete path to the script, not just the name
        # if we don't have a special script we use the default from the sysconfig file
        @scriptName = Convert.to_string(
          SAPInst.ConfigValue(Ops.add(Ops.add(@STACK, "_"), @INSTALL), "script_name")
        )
        Builtins.y2milestone("A:ScriptName=%1", @scriptName)

        if @instMasterType != "BOBJ" && @scriptName == nil ||
            Builtins.size(@scriptName) == 0
          @scriptName = @installScript
        end
        if @instMasterType == "BOBJ"
          @scriptName = Ops.add(Ops.add(@instMasterPath, "/"), @scriptName)
        end

        Builtins.y2milestone("B:ScriptName=%1", @scriptName)

        # Take care of partitioning
        @ret = nil
        @ret = Convert.to_string(SAPInst.ConfigValue(@INSTALL, "partitioning"))

        if @ret == nil
          # Default is base_partitioning
          @ret = "base_partitioning"
        end
        # Path to template without .xml extention
        @productPartitioning2 = Ops.add(@partXMLPath, @ret)
        Builtins.y2milestone("partitioning now %1", @productPartitioning2)


        # Store our configuration values for this product
        @productData = {
          "instMaster"     => @instMasterPath,
          "choosenProduct" => @choosenProduct,
          "STACK"          => @STACK,
          "DATABASE"       => @DATABASE,
          "TYPE"           => @TYPE,
          "SEARCH"         => @SEARCH,
          "INSTALL"        => @INSTALL,
          "PRODUCT_ID"     => Ops.get_string(@PRODUCT_ID, 0, ""),
          "SCRIPT_NAME"    => @scriptName,
          "SAPLUP"         => @needSaplup,
          "PARTITIONING"   => @productPartitioning2
        }
        SCR.Write(
          path(".target.ycp"),
          Ops.add(@targetDir, "/product.data"),
          @productData
        )

        # save answers from our ask dialogs
        SCR.Execute(path(".target.bash"), Ops.add("mv /tmp/ay* ", @targetDir))

        # prepare all install scripts and partioning
        finish(@productData)

        @prodCount = Ops.add(@prodCount, 1) # useful for the next run

        # Clear our screen
        Wizard.ClearContents
      end while @multi_prods == true &&
        Popup.YesNo("Do you want to install another product?") # end if product loop - no indentation

  end
end

Yast::SapInstallationWizardClient.new.main
