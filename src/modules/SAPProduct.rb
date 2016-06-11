# encoding: utf-8
# Authors: Peter Varkoly <varkoly@suse.com>

# ex: set tabstop=4 expandtab:
# vim: set tabstop=4: set expandtab
require "yast"
require "fileutils"

module Yast
  class SAPProductClass < Module
    def main
      Yast.import "URL"
      Yast.import "UI"
      Yast.import "XML"
      Yast.import "SAPXML"
      Yast.import "SAPMedia"

      textdomain "sap-media"
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("SAP Product Installer Started")

      #Some parameter of the actual selected product
      @instType      = ""
      @DB            = ""
      @sapInstEnv    = ""
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

      # @installedProducts contains a list of the products which already are installen on the system
      # The list consits of hashes of the parameter of the products:
      # instEnv      : path to the installation environment
      # instType     : The type of the installation: Standard, Distributed, HA, SUSE-HA, STANDALONE
      # PRODUCT_NAME : the name of the product.
      # PRODUCT_ID   : The product ID of the product.
      # SID          : the SID of the installed product.
      # STACK        : ABABP, JAVA, Double
      # DB           : The selected database
      @installedProducts = []
    end
  end

  #############################################################
  #
  # Read the installed products.
  #
  ############################################################
  def Read()
     prodCount = 0;
     while Dir.exists?(  Builtins.sformat("%1/%2/", SAPMedia.instDirBase, prodCount) )
       if File.exists?( Builtins.sformat("%1/%2/%3", SAPMedia.instDirBase, prodCount, "installationSuccesfullyFinished.dat") ) && File.exists?(@instDir + "/product.data")
         @installedProducts << Convert.convert(
            SCR.Read(path(".target.ycp"), @instDir + "/product.data"),
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
  def SelectNWInstallationMode(sapInstEnv)
    Builtins.y2milestone("-- Start SelectNWInstallationMode ---")
    run = true

    #Reset the the selected product specific parameter
    @productMAP = SAPXML.get_products_for_media(sapInstEnv)
    @instType      = ""
    @DB            = ""
    @PRODUCT_ID    = ""
    @PRODUCT_NAME  = ""
    @sapInstEnv    = sapInstEnv

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
                      #RadioButton( Id("SUSE-HA-ST"),  Opt(:notify, :hstretch), _("SUSE HA for SAP Simple Stack"), false),
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
    adaptDB(@productMAP.DB)
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
    Builtins.y2milestone("-- Start SelectNWProduct ---")
    run = true
  
    productItemTable = []
    if @instType == 'STANDALONE'
      @DB = 'IND'
    end
    @productList = SAPXML.get_nw_products(@sapInstEnv,@instType,@DB,@productMAP.productDir)
    if @productList == nil or @productList.empty?
       Popup.Error(_("The medium does not contain SAP installation data."))
       return :back
    end
    @productList.each { |map|
       name = map["name"]
       id   = map["id"]
       productItemTable << Item(Id(id),name,false)
    }
    Builtins.y2milestone("@productList %1",@productList)
  
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
  # Partitioning xml will be executed
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
    script_name  = SAPMedia.ayXMLPath + '/' +  GetProductParameter("script_name")
    xml_path     = GetProductParameter("ay_xml") == ""       ? ""   : SAPMedia.ayXMLPath + '/' +  GetProductParameter("ay_xml")
    partitioning = GetProductParameter("partitioning") == "" ? "NO" : GetProductParameter("partitioning")
    if File.exist?( xml_path )
      SAPMedia.ParseXML(xml_path)
      SCR.Execute(path(".target.bash"), "mv /tmp/ay_* " + @sapInstEnv )
    end
 end

  publish :variable => :installedProducts,     :type => "map"

  private
  ############################################################
  #
  # Private functions
  #
  ############################################################
  def adaptDB(dataBase)
    if dataBase == ""
       UI.ChangeWidget(Id("STANDARD"), :Enabled, false)
    else
       UI.ChangeWidget(Id("ORA"), :Enabled, false)
       case dataBase
       when "ADA"
         UI.ChangeWidget(Id("ADA"), :Value, true)
         UI.ChangeWidget(Id("HDB"), :Enabled, false)
         UI.ChangeWidget(Id("SYB"), :Enabled, false)
         UI.ChangeWidget(Id("DB6"), :Enabled, false)
         UI.ChangeWidget(Id("ORA"), :Enabled, false)
       when "HDB"
         UI.ChangeWidget(Id("HDB"), :Value, true)
         UI.ChangeWidget(Id("ADA"), :Enabled, false)
         UI.ChangeWidget(Id("SYB"), :Enabled, false)
         UI.ChangeWidget(Id("DB6"), :Enabled, false)
         UI.ChangeWidget(Id("ORA"), :Enabled, false)
       when "SYB"
         UI.ChangeWidget(Id("SYB"), :Value, true)
         UI.ChangeWidget(Id("ADA"), :Enabled, false)
         UI.ChangeWidget(Id("HDB"), :Enabled, false)
         UI.ChangeWidget(Id("DB6"), :Enabled, false)
         UI.ChangeWidget(Id("ORA"), :Enabled, false)
       when "DB6"
         UI.ChangeWidget(Id("DB6"), :Value, true)
         UI.ChangeWidget(Id("ADA"), :Enabled, false)
         UI.ChangeWidget(Id("HDB"), :Enabled, false)
         UI.ChangeWidget(Id("SYB"), :Enabled, false)
         UI.ChangeWidget(Id("ORA"), :Enabled, false)
       when "ORA"
         #FATE
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
    @productList.each { |p|
        if p["id"] == @PRODUCT_ID
           return p.has_key?(productParameter) ? p[productParameter] : ""
        end
    }
    return ""
  end

  SAPProduct = SAPProductClass.new
  SAPProduct.main
end
   
