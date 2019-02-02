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
    # Read the installation parameter.
    # The product  ay_xml will executed to read the SAP installation parameter
    # The product.data file will be written
    #
    ############################################################
    def ReadParameter
      # Display the empty dialog before running external SAP installer program
      # First we execute the autoyast xml file of the product if this exeists
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
    end
    
    ############################################################
    #
    # read a value from the product list
    #
    ############################################################
    def GetProductParameter(productParameter)
    end
  end
  SAPProduct = SAPProductClass.new
  SAPProduct.main
end
