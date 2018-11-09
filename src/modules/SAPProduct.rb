# encoding: utf-8
# Authors: Peter Varkoly <varkoly@suse.com>

# ex: set tabstop=4 expandtab:
# vim: set tabstop=4: set expandtab
require "yast"
require "fileutils"

module Yast
  # Handling of products on the sap media
  class SAPProductClass < Module
    attr_reader :installed_products
    def main
      Yast.import "URL"
      Yast.import "UI"
      Yast.import "XML"
      Yast.import "SAPXML"
      Yast.import "SAPMedia"
      Yast.import "SAPPartitioning"

      textdomain "sap-installation-wizard"
      log.info("----------------------------------------")
      log.info("SAP Product Installer Started")

      # Some parameter of the actual selected product
      @instType      = ""
      @DB            = ""
      @PRODUCT_ID    = ""
      @PRODUCT_NAME  = ""
      @productMAP    = {}

      @dialogs = {
         "nwInstType" => {
             "help"    => _("<p>Choose SAP product installation and back-end database.</p>") +
                          '<p><b>' + _("SAP Standard System") + '</p></b>' +
                          _("<p>Installation of a SAP NetWeaver system with all servers on the same host.</p>") +
                          '<p><b>' + _("SAP Standalone Engines") + '</p></b>' +
                          _("<p>Standalone engines are SAP Trex, SAP Gateway, and Web Dispatcher.</p>") +
                          '<p><b>' + _("Distributed System") + '</p></b>' +
                          _("Installation of SAP NetWeaver with the servers distributed on separate hosts.</p>") +
                          '<p><b>' + _("High-Availability System") + '</p></b>' +
                          _("Installation of SAP NetWeaver in a high-availability setup.</p>") +
                          '<p><b>' + _("System Rename") + '</p></b>' +
                          _("Change the SAP system ID, database ID, instance number, or host name of a SAP system.</p>"),
             "name"    => _("Choose the Installation Type!")
             },
         "nwSelectProduct" => {
             "help"    => _("<p>Please choose the SAP product you wish to install.</p>"),
             "name"    => _("Choose a Product")
             }
      }

      # @productList contains a list of hashes of the parameter of the products which can be installed
      # withe the selected installation medium. The parameter of HANA and B1 are constant
      # and can not be extracted from the datas on the IM of these products.

      @productList = []
      @productList << {
                       "name"         => "HANA",
                       "id"           => "HANA",
                       "ay_xml"       => SAPXML.ConfigValue("HANA","ay_xml"),
                       "partitioning" => SAPXML.ConfigValue("HANA","partitioning"),
                       "script_name"  => SAPXML.ConfigValue("HANA","script_name")
      }
      @productList << {
                       "name"         => "B1",
                       "id"           => "B1",
                       "ay_xml"       => SAPXML.ConfigValue("B1","ay_xml"),
                       "partitioning" => SAPXML.ConfigValue("B1","partitioning"),
                       "script_name"  => SAPXML.ConfigValue("B1","script_name")
      }
      @productList << {
                       "name"         => "TREX",
                       "id"           => "TREX",
                       "ay_xml"       => SAPXML.ConfigValue("TREX","ay_xml"),
                       "partitioning" => SAPXML.ConfigValue("TREX","partitioning"),
                       "script_name"  => SAPXML.ConfigValue("TREX","script_name")
      }

      # @installed_products contains a list of the products which already are installen on the system
      # The list consits of hashes of the parameter of the products:
      # instEnv      : path to the installation environment
      # instType     : The type of the installation: Standard, Distributed, HA, SUSE-HA, STANDALONE
      # PRODUCT_NAME : the name of the product.
      # PRODUCT_ID   : The product ID of the product.
      # SID          : the SID of the installed product.
      # STACK        : ABABP, JAVA, Double
      # DB           : The selected database
      @installed_products = []

      #List of product directories which must be installed
      @products_to_install = []

    end

    #############################################################
    #
    # Read the installed products.
    #
    ############################################################
    def Read()
      log.info("-- Start SAPProduct Read --")
       prodCount = 0;
       while Dir.exists?(  Builtins.sformat("%1/%2/", SAPMedia.instDirBase, prodCount) )
         instDir = Builtins.sformat("%1/%2/", SAPMedia.instDirBase, prodCount)
         if File.exists?( instDir + "/installationSuccesfullyFinished.dat" ) && File.exists?( instDir + "/product.data")
           @installed_products << Convert.convert(
              SCR.Read(path(".target.ycp"), instDir + "/product.data"),
              :from => "any",
              :to   => "map <string, any>"
            )
         end
         prodCount = prodCount.next
       end
    end
    
    #############################################################
    #
    # Select the NW installation mode.
    #
    ############################################################
    def SelectNWInstallationMode()
      log.info("-- Start SelectNWInstallationMode --- for instDir #{SAPMedia.instDir}")
      run = true
    
      # Reset the the selected product specific parameter
      @productMAP    = SAPXML.get_products_for_media(SAPMedia.instDir)
      log.info("@productMAP #{@productMAP}")
      @instType      = ""
      @DB            = ""
      @PRODUCT_ID    = ""
      @PRODUCT_NAME  = ""
    
      Wizard.SetContents(
        @dialogs["nwInstType"]["name"],
        VBox(
          HVSquash(Frame("",
          VBox(
            HBox(
                VBox(
                    Left(Label(_("Installation Type"))),
                    RadioButtonGroup( Id(:type),
                    VBox(
                        RadioButton( Id("STANDARD"),    Opt(:notify, :hstretch), _("SAP Standard System"), false),
                        RadioButton( Id("DISTRIBUTED"), Opt(:notify, :hstretch), _("Distributed System"), false),
                        # RadioButton( Id("SUSE-HA-ST"),  Opt(:notify, :hstretch), _("SUSE HA for SAP Simple Stack"), false),
                        RadioButton( Id("HA"),          Opt(:notify, :hstretch), _("SAP High-Availability System"), false),
                        RadioButton( Id("STANDALONE"),  Opt(:notify, :hstretch), _("SAP Standalone Engines"), false),
                        RadioButton( Id("SBC"),         Opt(:notify, :hstretch), _("System Rename"), false),
                    )),
                ),
                HSpacing(3),
                VBox(
                    Left(Label(_("Back-end Databases"))),
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
          )
        ))),
        @dialogs["nwInstType"]["help"],
        true,
        true
      )
      if SAPMedia.importSAPCDs
         UI.ChangeWidget(Id("STANDARD"),   :Enabled, false)
         UI.ChangeWidget(Id("STANDALONE"), :Enabled, false)
         UI.ChangeWidget(Id("SBC"),        :Enabled, false)
      end
      adaptDB(@productMAP["DB"])
      media = File.read(SAPMedia.instDir + "/start_dir.cd")
      if ! media.include?("KERNEL")
         UI.ChangeWidget(Id("STANDARD"),    :Enabled, false)
         UI.ChangeWidget(Id("DISTRIBUTED"), :Enabled, false)
         UI.ChangeWidget(Id("HA"),          :Enabled, false)
         # Does not exists at the time
         # UI.ChangeWidget(Id("SUSE-HA-ST"),  :Enabled, false)
         UI.ChangeWidget(Id("ADA"), :Enabled, false)
         UI.ChangeWidget(Id("HDB"), :Enabled, false)
         UI.ChangeWidget(Id("SYB"), :Enabled, false)
         UI.ChangeWidget(Id("DB6"), :Enabled, false)
         UI.ChangeWidget(Id("ORA"), :Enabled, false)
      end
      while run
        case UI.UserInput
          when /STANDARD|DISTRIBUTED|SUSE-HA-ST|HA/
            UI.ChangeWidget(Id(:db), :Enabled, true)
            @instType = Convert.to_string(UI.QueryWidget(Id(:type), :CurrentButton))
          when /STANDALONE|SBC/
            UI.ChangeWidget(Id(:db), :Enabled, false)
            @instType = Convert.to_string(UI.QueryWidget(Id(:type), :CurrentButton))
          when /DB6|ADA|ORA|HDB|SYB/
            @DB = Convert.to_string(UI.QueryWidget(Id(:db), :CurrentButton))
          when :next
            run = false
            if @instType == ""
              run = true
              Popup.Message(_("Please choose an SAP installation type."))
              next
            end
            if @instType !~ /STANDALONE|SBC/ and @DB == ""
              run = true
              Popup.Message(_("Please choose a back-end database."))
              next
            end
          when :back
            return :back
          when :abort, :cancel
            if Yast::Popup.ReallyAbort(false)
                Yast::Wizard.CloseDialog
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
      log.info("-- Start SelectNWProduct ---")
      run = true
    
      productItemTable = []
      if @instType == 'STANDALONE'
        @DB = 'IND'
      end
      @productList = SAPXML.get_nw_products(SAPMedia.instDir,@instType,@DB,@productMAP["productDir"])
      if @productList == nil or @productList.empty?
         Popup.Error(_("The medium does not contain SAP installation data."))
         return :back
      end
      @productList.each { |map|
         name = map["name"]
         id   = map["id"]
         productItemTable << Item(Id(id),name,false)
      }
      log.info("@productList #{@productList}")
    
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
            @PRODUCT_ID = Convert.to_string(UI.QueryWidget(Id(:products), :CurrentItem))
            if @PRODUCT_ID == nil
              run = true
              Popup.Message(_("Select a product!"))
            else
              run = false
              @productList.each { |map|
                 @PRODUCT_NAME = map["name"] if @PRODUCT_ID == map["id"]
              }
            end
          when :back
            return :back
          when :abort, :cancel
            if Yast::Popup.ReallyAbort(false)
                Yast::Wizard.CloseDialog
                run = false
                return :abort
            end
        end
      end
      return :next
    end
    
    #############################################################
    #
    # Read the installation parameter.
    # The product  ay_xml will executed to read the SAP installation parameter
    # The product.data file will be written
    #
    ############################################################
    def ReadParameter
      log.info("-- Start SAPProduct ReadParameter --")
      ret = :next
      sid        =""
      instNumber =""
      hostname_out = Convert.to_map( SCR.Execute(path(".target.bash_output"), "hostname"))
      my_hostname = Ops.get_string(hostname_out, "stdout", "")
      my_hostname.strip!
      log.info("-- Start ReadParameter ---")

      # For HANA B1 and  TREX there is no @DB @PRODUCT_NAME and @PRODUCT_ID set at this time
      case SAPMedia.instMasterType
        when "HANA"
           @DB           = "HDB"
           @PRODUCT_NAME = "HANA"
           @PRODUCT_ID   = "HANA"
        when /^B1/
           @DB           = ""
           @PRODUCT_NAME = "B1"
           @PRODUCT_ID   = "B1"
        when "TREX"
           @DB           = ""
           @PRODUCT_NAME = "TREX"
           @PRODUCT_ID   = "TREX"
      end
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
      # First we execute the autoyast xml file of the product if this exeists
      script_name    = SAPMedia.ayXMLPath + '/' +  GetProductParameter("script_name")
      inifile_params = GetProductParameter("inifile_params") == "" ? ""   : SAPMedia.ayXMLPath + '/' +  GetProductParameter("inifile_params")
      xml_path       = GetProductParameter("ay_xml")         == "" ? ""   : SAPMedia.ayXMLPath + '/' +  GetProductParameter("ay_xml")
      partitioning   = GetProductParameter("partitioning")   == "" ? "NO" : GetProductParameter("partitioning")

      if File.exist?( xml_path )
        SCR.Execute(path(".target.bash"), "sed -i s/##VirtualHostname##/" + my_hostname + "/g " + xml_path )
        SAPMedia.ParseXML(xml_path)
        if File.exist?("/tmp/ay_q_sid")
           sid = IO.read("/tmp/ay_q_sid").chomp    
        end
        if File.exist?("/tmp/ay_q_sapinstnr")
           instNumber = IO.read("/tmp/ay_q_sapinstnr").chomp
        end
        SCR.Execute(path(".target.bash"), "mv /tmp/ay_* " + SAPMedia.instDir )
      end

      # inifile_params can be contains DB-name
      inifile_params = inifile_params.gsub("##DB##",@DB)

      # Create the parameter.ini file
      if File.exists?(inifile_params)
        inifile = File.read(inifile_params)
        Dir.glob(SAPMedia.instDir + "/ay_q_*").each { |param|
           par = param.gsub(/^.*\/ay_q_/,"")
           val = IO.read(param).chomp
           pattern = "##" + par + "##"
           a = inifile.gsub!(/#{pattern}/,val) 
        }
        # Replace ##VirtualHostname## by the real hostname.
        inifile.gsub!(/##VirtualHostname##/,my_hostname)
        # Replace kernel base
        File.readlines(SAPMedia.instDir + "/start_dir.cd").each { |path|
          if path.include?("KERNEL")
            inifile.gsub!(/##kernel##/,path.chomp)
            break
          end
        }
        File.write(SAPMedia.instDir + "/inifile.params",inifile)
      end
      if SAPMedia.instMasterType == "SAPINST" 
         SCR.Execute(path(".target.bash"), "/usr/share/YaST2/include/sap-installation-wizard/doc.dtd "   + SAPMedia.instDir) 
         SCR.Execute(path(".target.bash"), "/usr/share/YaST2/include/sap-installation-wizard/keydb.dtd " + SAPMedia.instDir) 
      end

      SCR.Write( path(".target.ycp"), SAPMedia.instDir + "/product.data",  {
             "instDir"        => SAPMedia.instDir,
             "instMaster"     => SAPMedia.instDir + "/Instmaster",
             "TYPE"           => SAPMedia.instMasterType,
             "DB"             => @DB,
             "PRODUCT_NAME"   => @PRODUCT_NAME,
             "PRODUCT_ID"     => @PRODUCT_ID,
             "PARTITIONING"   => partitioning,
             "SID"            => sid,
             "INSTNUMBER"     => instNumber,
             "SCRIPT_NAME"    => script_name
          })

      @products_to_install << SAPMedia.instDir

      instDirMode = SAPMedia.instMasterType == "SAPINST" ? "770" : "775" 

      cmd = "groupadd sapinst; " +
            "usermod --groups sapinst root; " +
            "chgrp sapinst " + SAPMedia.instDir + ";" +
            "chmod " + instDirMode + " " + SAPMedia.instDir + ";"
      log.info("-- Prepare sapinst #{cmd}" )
      SCR.Execute(path(".target.bash"), cmd)

      if Popup.YesNo(_("Installation profile is ready.\n" +
                       "Are there more SAP products to be prepared for installation?"))
         ret = :readIM
         SAPMedia.prodCount = SAPMedia.prodCount.next
         SAPMedia.instDir = Builtins.sformat("%1/%2", SAPMedia.instDirBase, SAPMedia.prodCount)
         SCR.Execute(path(".target.bash"), "mkdir -p " + SAPMedia.instDir )
      end
      return ret
    end

    #############################################################
    #
    # Start the installation of the collected SAP products.
    #
    ############################################################
    def Write
      log.info("-- Start SAPProduct Write --")
      productScriptsList      = []
      productPartitioningList = []
      productList             = []
      @products_to_install.each { |instDir|
        productData = Convert.convert(
          SCR.Read(path(".target.ycp"), instDir + "/product.data"),
          :from => "any",
          :to   => "map <string, any>"
        )
        params = Builtins.sformat(
          " -m \"%1\" -i \"%2\" -t \"%3\" -y \"%4\" -d \"%5\"",
          Ops.get_string(productData, "instMaster", ""),
          Ops.get_string(productData, "PRODUCT_ID", ""),
          Ops.get_string(productData, "DB", ""),
          Ops.get_string(productData, "TYPE", ""),
          Ops.get_string(productData, "instDir", ""),
        )
        # Add script
        productScriptsList << "/bin/sh -x " + Ops.get_string(productData, "SCRIPT_NAME", "") + params

        # Add product to install
        productList << Ops.get_string(productData, "PRODUCT_ID", "")
        
        # Add product partitioning
        ret = Ops.get_string(productData, "PARTITIONING", "")
        if ret == nil
          # Default is base_partitioning
          ret = "base_partitioning"
        end
        productPartitioningList << ret if ret != "NO"
      }
      # Start create the partitions
      ret = SAPPartitioning.CreatePartitions(productPartitioningList,productList)
      log.info("SAPPartitioning.CreatePartitions returned: #{ret}")
      if( ret == "abort" )
        return :abort
      end
      

      # Start execute the install scripts
      require "open3"
      productScriptsList.each { |installScript|
          out = Convert.to_map( SCR.Execute(path(".target.bash_output"), "date +%Y%m%d-%H%M"))
          date = Builtins.filterchars( Ops.get_string(out, "stdout", ""), "0123456789-.")
          logfile = "/var/adm/autoinstall/logs/sap_inst." + date + ".log"
          f = File.new( logfile, "w")
          # pid = 0
          Wizard.SetContents( _("SAP Product Installation"),
                                        LogView(Id("LOG"),"",30,400),
                                        "Help",
                                        true,
                                        true
                                        )
          Open3.popen2e(installScript) {|i,o,t|
             i.close
             n = 0
             text = ""
             o.each_line {|line|
                f << line
                text << line
                if n > 30
                    UI::ChangeWidget(Id("LOG"), :LastLine, text );
                    n    = 0
                    text = ""
                else
                    n = n.next
                end
             }
          }
          f.close
          sleep 5
          # Process.kill("TERM", pid)
      }
      return :next
    end

    private
    ############################################################
    #
    # Private functions
    #
    ############################################################
    def adaptDB(data_base)
      log.info("-- Start SAPProduct adaptDB --")
      if data_base == ""
         UI.ChangeWidget(Id("STANDARD"), :Enabled, false)
      else
         UI.ChangeWidget(Id("ORA"), :Enabled, false)
         case data_base
         when "ADA"
           UI.ChangeWidget(Id("ADA"), :Value, true)
           UI.ChangeWidget(Id("HDB"), :Enabled, false)
           UI.ChangeWidget(Id("SYB"), :Enabled, false)
           UI.ChangeWidget(Id("DB6"), :Enabled, false)
           UI.ChangeWidget(Id("ORA"), :Enabled, false)
           @DB = data_base
         when "HDB"
           UI.ChangeWidget(Id("HDB"), :Value, true)
           UI.ChangeWidget(Id("ADA"), :Enabled, false)
           UI.ChangeWidget(Id("SYB"), :Enabled, false)
           UI.ChangeWidget(Id("DB6"), :Enabled, false)
           UI.ChangeWidget(Id("ORA"), :Enabled, false)
           @DB = data_base
         when "SYB"
           UI.ChangeWidget(Id("SYB"), :Value, true)
           UI.ChangeWidget(Id("ADA"), :Enabled, false)
           UI.ChangeWidget(Id("HDB"), :Enabled, false)
           UI.ChangeWidget(Id("DB6"), :Enabled, false)
           UI.ChangeWidget(Id("ORA"), :Enabled, false)
           @DB = data_base
         when "DB6"
           UI.ChangeWidget(Id("DB6"), :Value, true)
           UI.ChangeWidget(Id("ADA"), :Enabled, false)
           UI.ChangeWidget(Id("HDB"), :Enabled, false)
           UI.ChangeWidget(Id("SYB"), :Enabled, false)
           UI.ChangeWidget(Id("ORA"), :Enabled, false)
           @DB = data_base
         when "ORA"
           # FATE
           Popup.Error( _("The Installation of Oracle Databas with SAP Installation Wizard is not supported."))
           return :abort
         end
      end
    end
    
    ############################################################
    #
    # read a value from the product list
    #
    ############################################################
    def GetProductParameter(productParameter)
      log.info("-- Start SAPProduct GetProductParameter --")
      @productList.each { |p|
          if p["id"] == @PRODUCT_ID
             return p.has_key?(productParameter) ? p[productParameter] : ""
          end
      }
      return ""
    end
  end
  SAPProduct = SAPProductClass.new
  SAPProduct.main
end
