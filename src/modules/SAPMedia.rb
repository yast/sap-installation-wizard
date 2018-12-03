# encoding: utf-8
# Authors: Peter Varkoly <varkoly@suse.com>

# ex: set tabstop=4 expandtab:
# vim: set tabstop=4: set expandtab
require "yast"
require "fileutils"

module Yast
  class SAPMediaClass < Module
    def main
      #Basic yast stuff
      Yast.import "URL"
      Yast.import "UI"
      Yast.import "XML"
      Yast.import "Misc"

      #Own stuff
      Yast.import "SAPXML"

      #Autoyast stuff
      Yast.import "AutoInstall"
      Yast.import "AutoinstConfig"
      Yast.import "AutoinstData"
      Yast.import "AutoinstScripts"
      Yast.import "AutoinstSoftware"
      Yast.import "Mode"
      Yast.import "Profile"


      textdomain "sap-installation-wizard"
      log.info("----------------------------------------")
      log.info("SAP Media Reader Started")


      #String to save the date. Will be set by set_date
      @date   = ""

      #Hash for design the dialogs
      #Help text for the fututre. This will be available only in SP1
      #                          '<p><b>' + _("SUSE HA for SAP Simple Stack") + '</p></b>' +
      #                          _("With this installation mode the <b>SUSE-HA for SAP Simple Stack</b> can be installed and configured.") +
      @dialogs = {
         "inst_master" => {
             "help"    => _("<p>Enter location of SAP installation master medium to prepare it for use.</p>") +
                          _("Valid SAP installation master media are: <b>SWPM, TREX, HANA and Business One media."),
             "name"    => _("Prepare the SAP installation master medium")
             },
         "sapmedium" => {
             "help"    => _("<p>Enter the location of your SAP medium.</p>"),
             "name"    => _("Location of the SAP product medium (e.g. SAP kernel, database, and database exports)")
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

      # ***********************************
      # Initialize global varaiables
      # ***********************************
      #*****************************************************
      #
      # Define some global variables relating the dialogs
      #
      #*****************************************************
      @scheme_list = [
          Item(Id("local"),  "dir://",    true),
          Item(Id("device"), "device://", false),
          Item(Id("usb"),    "usb://",    false),
          Item(Id("nfs"),    "nfs://",    false),
          Item(Id("smb"),    "smb://",    false)
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
      #Set system arch
      @ARCH = `arch`
      @ARCH = @ARCH.upcase
      @ARCH = @ARCH.chomp
      
      #The selected schema.
      @schemeCache    = "local"

      #The entered location.
      @locationCache = ""

      #The selected product
      @choosenProduct = ""

      #The sources must be unmounted
      @umountSource = false

      #Local path to the sources
      @sourceDir    = ""

      # The product counter
      @prodCount = 0

      #The installation will be prepared in this directory 
      #In case of HANA and B1 instDir and mediaDir is the same
      @instDir = ""

      #The type of the actual read installation master
      @instMasterType

      #The control hash for sap media
      @SAPMediaTODO = {}

      #The installations will be prepared in this directory
      #For all installation a separate directory will be created
      @instDirBase = ""

      #List of directories which contains a whole SAP installation
      #environment but no installation was executed
      @instEnvList = []

      #Hash for remember which media was selected.
      @selectedMedia = {}

      #Default file name for autoyast xml on third party media
      @productXML    = "product.xml";

      @sapCDsURL     = ""
      @mediaDir      = ""
      @mmount        = ""

      # read the global configuration
      parse_sysconfig

    end


    #***********************************
    # Reads the SAP installation configuration.
    # @return true or false
    def Read()
      # If there are installation profiles waiting to be installed, ask user what they want to do with them.
      while Dir.exists?(  Builtins.sformat("%1/%2/", @instDirBase, @prodCount) )
          case Popup.AnyQuestion3(_("Pending installation from previous wizard run"),
                                _("Installation profile was previously collected for the following product, however it has not been installed yet:\n\n") +
                               productData["PRODUCT_NAME"].to_s + "\n(" + productData["PRODUCT_ID"].to_s + ")\n\n" +
                               _("Would you like to delete it, install the product at the last wizard step, or ignore it?"),
                                _("Delete"), _("Install"), _("Ignore and do nothing"), :focus_retry) # Focus on ignore
          when :yes # Delete
              SCR.Execute(path(".target.bash"), "rm -rf --preserve-root " + @instDir)
          when :no # Install
              # It will be installed at the last wizard step (i.e. the installation step)
              @instEnvList << @instDir
          when :retry # Do nothing
              # Do nothing about it
          end
      end
    end

    #############################################################
    #
    # Writes the configuration environment of the installation
    # @return :next
    #
    #############################################################
    def Write()
      log.info("-- SAPMedia.Write Start ---")

      #When autoinstallation we have to copy the media
      if Mode.mode() == "autoinstallation"
        SCR.Execute(path(".target.bash"), "groupadd sapinst; usermod --groups sapinst root; ") 
        prodCount = -1
        @SAPMediaTODO["products"].each { |prod|
          mediaList = []
          script    = ""
          prodCount = prodCount.next
          sid       = ""
          @instDir = Builtins.sformat("%1/%2", @instDirBase, prodCount )
          if !prod.has_key?("media")
             Popup.Error("You have to define the location of the installation media in the autoyast xml.")
             next
          end
          #Start copying media
          prod["media"].each { |medium|
            url = medium["url"].split("://")
            urlPath = MountSource(url[0],url[1])
            if "ERROR:" == urlPath[0,6]
               log.info("Can not mount medium #{medium["url"]}. Reason #{urlPath}")
               return :next
            else
               case medium["type"].downcase
               when "supplement"
                 CopyFiles(@mountPoint, @instDir, "Supplement", false)
                 #TODO execute profile.xml on media
               when "sap"
                 instMasterList = SAPXML.is_instmaster(@mountPoint)
                 if instMasterList.empty?
                                 media=find_sap_media(@mountPoint)
                                 media.each { |path,label|
                                   CopyFiles(path, @mediaDir, label, false)
                                   mediaList << @mediaDir + "/" + label
                                 }
                 else
                     @instMasterType = instMasterList[0]
                     @instMasterPath = instMasterList[1]
                     CopyFiles(@instMasterPath, @instDir, "Instmaster", false)
                     mediaList << @instDir + "/" + "Instmaster"
                 end
               end
            end
            UmountSources(true)
          }
          if( @instMasterType == "SAPINST" )
             @DB           = prod.has_key?("DB")          ? prod["DB"]          : ""
             @PRODUCT_NAME = prod.has_key?("productName") ? prod["productName"] : ""
             @PRODUCT_ID   = prod.has_key?("productID")   ? prod["productID"]   : ""
             if prod.has_key?("iniFile")
                File.write(@instDir + "/inifile.params",  prod["iniFile"])
             end
             if @PRODUCT_ID == ""
                Popup.Error("The SAP PRODUCT_ID is not defined.")
                next
             end
             SCR.Execute(path(".target.bash"), "/usr/share/YaST2/include/sap-installation-wizard/doc.dtd " + @instDir) 
             SCR.Execute(path(".target.bash"), "/usr/share/YaST2/include/sap-installation-wizard/keydb.dtd " + @instDir) 
             File.write(@instDir + "/start_dir.cd" , mediaList.join("\n"))
          else
             @DB           = "HANA"
             @PRODUCT_NAME = @instMasterType
             @PRODUCT_ID   = @instMasterType
             if ! prod.has_key?("sapMasterPW") or ! prod.has_key?("sid") or ! prod.has_key?("sapInstNr")
                Popup.Error("Some of the required parameters are not defined.")
                next
             end
             if ! prod.has_key?("sapMDC")
                  prod["sapMDC"] = "no"
             end
             File.write(@instDir + "/ay_q_masterpass", prod["sapMasterPW"])
             File.write(@instDir + "/ay_q_sid",        prod["sid"])
             File.write(@instDir + "/ay_q_sapinstnr",  prod["sapInstNr"])
             File.write(@instDir + "/ay_q_sapmdc",     prod["sapMDC"])
             if prod.has_key?("sapVirtHostname")
                File.write(@instDir + "/ay_q_virt_hostname",     prod["sapVirtHostname"])
             end
             sid = prod["sid"]
          end
          SCR.Write( path(".target.ycp"), @instDir + "/product.data",  {
                 "instDir"        => @instDir,
                 "instMaster"     => @instDir + "/Instmaster",
                 "TYPE"           => @instMasterType,
                 "DB"             => @DB,
                 "PRODUCT_NAME"   => @PRODUCT_NAME,
                 "PRODUCT_ID"     => @PRODUCT_ID,
                 "PARTITIONING"   => "",
                 "SID"            => sid,
                 "SCRIPT_NAME"    => ""
              })
          #Now we start the product installation
          case @instMasterType
            when "SAPINST"
               SCR.Execute(path(".target.bash"), "chgrp sapinst " + @instDir + ";" + "chmod 770 " + @instDir)
               script = " /usr/share/YaST2/include/sap-installation-wizard/sap_inst_nodb.sh"
            when "HANA"
               SCR.Execute(path(".target.bash"), "chgrp sapinst " + @instDir + ";" + "chmod 775 " + @instDir)
               script = " /usr/share/YaST2/include/sap-installation-wizard/hana_inst.sh -g"
            when /^B1/
               SCR.Execute(path(".target.bash"), "chgrp sapinst " + @instDir + ";" + "chmod 775 " + @instDir)
               script = " /usr/share/YaST2/include/sap-installation-wizard/b1_inst.sh -g"
            when "TREX"
               SCR.Execute(path(".target.bash"), "chgrp sapinst " + @instDir + ";" + "chmod 775 " + @instDir)
               script = " /usr/share/YaST2/include/sap-installation-wizard/trex_inst.sh"
          end
          set_date()
          logfile = "/var/log/sap_inst." + @date + ".log"
          script << Builtins.sformat(
            " -m \"%1\" -i \"%2\" -t \"%3\" -y \"%4\" -d \"%5\"",
            @instDir + "/Instmaster",
            @PRODUCT_ID,
            @DB,
            @instMasterType,
            @instDir
            )
          log.info("Starting Installation : #{script}")
          Wizard.SetContents( _("SAP Product Installation"),
                                        LogView(Id("LOG"),"",30,400),
                                        "Help",
                                        true,
                                        true
                                        )
          require "open3"
          f = File.new(logfile,"w")
          exit_status = nil
          Open3.popen2e(script) {|i,o,t|
             i.close
             n=0
             text=""
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
             exit_status = t.value.exitstatus
          }
          f.close
          log.info("Exit code of script : #{exit_status}")
          if exit_status != 0
                Popup.Error("Installation failed. For details please check log files at /var/tmp and /var/adm/autoinstall/logs.")
          end
        }
      else
        if  @exportSAPCDs && @instMode != "auto" && !@importSAPCDs
            ExportSAPCDs()
        end
        @instEnvList << @instDir
        if Popup.YesNo(_("Do you want to install another product?"))
           @prodCount = @prodCount.next
           @instDir = Builtins.sformat("%1/%2", @instDirBase, @prodCount)
           SCR.Execute(path(".target.bash"), "mkdir -p " + @instDir )
           return ":readIM"
        end
      end
      :next
    end


    #############################################################
    #
    # Import the configuration of the auto installation
    # @return true
    #
    #############################################################
    def Import(settings)

      @SAPMediaTODO = settings
      log.info("-- SAPMedia.Import Start --- #{@SAPMediaTODO}")

      true
    end

    #############################################################
    #
    # Export the configuration of the auto installation
    # @return true
    #
    #############################################################
    def Export()
      log.info("-- SAPMedia.Export Start ---")
      #TODO

      {}
    end

    #############################################################
    #
    # Read and analize the installation master
    #
    ############################################################
    def ReadInstallationMaster
    end

    #############################################################
    #
    # Copy the SAP Media
    #
    ############################################################
    def CopyNWMedia
    end
    
    #############################################################
    #
    # Ask for 3rd-Party/ Supplement dialog (includes a product.xml)
    #
    ############################################################
    def ReadSupplementMedium
    end
    #***********************************
    # Umount sources.
    #  @param boolean doit
    def UmountSources(doit)
    end

    # ***********************************
    # Parse and merge our xml snipplets
    #
    def ParseXML(file)
      #Reimplemented
    end

    # ***********************************
    #  mounts a "scheme://host/path" to a mountPoint dir
    #  @param  scheme like "device", location like "/sda1"
    #  @return sting  Starting with ERROR: and containing the error message if ith happenend
    #                 Containing the mount point whre the source was mounted.
    #  The mountPoint was defined in /etc/sysconfig/sap-installation-wizard
    #
    def MountSource(scheme, location)
      #Reimplemented
    end

    # Make SURE to save firewall configuration and restart it.
    # Because firewall module has weird workaround that will prevent new configuration from being activated.
    def SaveAndRestartFirewallWorkaround()
       SuSEFirewall.WriteConfiguration
       if Service.Active("SuSEfirewall2")
           system("systemctl restart SuSEfirewall2")
           system("nohup sh -c 'sleep 60 && systemctl restart SuSEfirewall2' > /dev/null &")
       end
    end

    # Restart essential NFS services several times to get rid of "program not registered" error.
    def RestartNFSWorkaround()
       system("nohup sh -c 'sleep 16 && systemctl restart nfs-config' > /dev/null &")
       system("nohup sh -c 'sleep 18 && systemctl restart rpcbind' > /dev/null &")
       system("nohup sh -c 'sleep 20 && systemctl restart rpc.mountd' > /dev/null &")
       system("nohup sh -c 'sleep 22 && systemctl restart rpc.statd' > /dev/null &")
       system("nohup sh -c 'sleep 24 && systemctl restart nfs-idmapd' > /dev/null &")
       system("nohup sh -c 'sleep 26 && systemctl restart nfs-mountd' > /dev/null &")
       system("nohup sh -c 'sleep 28 && systemctl restart nfs-server' > /dev/null &")

       system("nohup sh -c 'sleep 30 && systemctl restart nfs-config' > /dev/null &")
       system("nohup sh -c 'sleep 32 && systemctl restart rpcbind' > /dev/null &")
       system("nohup sh -c 'sleep 34 && systemctl restart rpc.mountd' > /dev/null &")
       system("nohup sh -c 'sleep 36 && systemctl restart rpc.statd' > /dev/null &")
       system("nohup sh -c 'sleep 38 && systemctl restart nfs-idmapd' > /dev/null &")
       system("nohup sh -c 'sleep 40 && systemctl restart nfs-mountd' > /dev/null &")
       system("nohup sh -c 'sleep 42 && systemctl restart nfs-server' > /dev/null &")
    end

    def FindSAPCDServer()
        # Allow SLP to discover exported SAP mediums in the network
        SuSEFirewall.ReadCurrentConfiguration()
        ["INT", "EXT", "DMZ"].each { |zone|
            zone_custom_rules = SuSEFirewall.GetAcceptExpertRules(zone)
            if zone_custom_rules !~ /udp,0:65535,svrloc/
                SuSEFirewall.SetAcceptExpertRules(zone,"0/0,udp,0:65535,svrloc")
                SuSEFirewall.SetModified()
            end
        }
        SuSEFirewall.WriteConfiguration
        if Service.Active("SuSEfirewall2")
           system("systemctl restart SuSEfirewall2")
        end
        # Find NFS servres registered on SLP, filter out my own host name from the list.
        hostname_out = Convert.to_map( SCR.Execute(path(".target.bash_output"), "hostname -f"))
        my_hostname = Ops.get_string(hostname_out, "stdout", "")
        my_hostname.strip!
        slp_nfs_list = []
        slp_svcs = SLP.FindSrvs("service:sles4sapinst","")
        slp_svcs.each { |svc|
            host = svc["pcHost"]
            slp_attrs = SLP.GetUnicastAttrMap("service:sles4sapinst",svc["pcHost"])
            if host != my_hostname && slp_attrs.has_key?("provided-media")
                slp_nfs_list << [host, slp_attrs["provided-media"], svc["srvurl"]]
            end
        }
        # Dismiss if there is not any NFS server on SLP
        return if slp_nfs_list.empty?

        svc_table = Table(Id(:servers))
        svc_table << Header("Server","Provided Media")

        table_items = []
        table_items << Item(Id("local"),"(Local)","(do not use network installation server)")
        slp_nfs_list.each { |svc|
            table_items << Item(Id(svc[2]), svc[0], svc[1])
        }

        svc_table << table_items
        # Display a dialog to let user choose a server
        UI.OpenDialog(VBox(
            Heading(_("SLES4SAP installation servers are detected")),
            MinHeight(10, svc_table),
            PushButton("&OK")
        ))
        UI.UserInput
        ret = Convert.to_string(UI.QueryWidget(Id(:servers), :CurrentItem))
        if ret != "local"
            /service:sles4sapinst:(?<url>.*)/ =~ ret
            @sapCDsURL = url
            mount_sap_cds
        end
        UI.CloseDialog()
    end

    # Copy /etc/sysconfig/SuSEfirewall2 to /tmp/sapinst-SuSEfirewall2.
    def BackupSysconfigFirewall()
      ::FileUtils.remove_file('/tmp/sapinst-SuSEfirewall2', true)
      ::FileUtils.cp('/etc/sysconfig/SuSEfirewall2', '/tmp/sapinst-SuSEfirewall2')
    end

    # Copy /tmp/sapinst-SuSEfirewall2 to /etc/sysconfig/SuSEfirewall2 and remove the tmp file.
    def RestoreAndRemoveBackupSysconfigFirewall()
      ::FileUtils.cp('/tmp/sapinst-SuSEfirewall2', '/etc/sysconfig/SuSEfirewall2')
      ::FileUtils.remove_file('/tmp/sapinst-SuSEfirewall2', true)
    end

    # ***********************************
    # Function to export SAP installation media
    # and publish it via slp
    #
    def ExportSAPCDs()
       # Make sure the directory exists before using it
       ::FileUtils.mkdir_p @mediaDir
       # NFS module will throw away firewall configuration during installation, hence back it up now.
       BackupSysconfigFirewall()
       # Configure NFS service
       NfsServer.Read
       nfs_conf = NfsServer.Export
       if ! (nfs_conf["nfs_exports"].any? {|entry| entry["mountpoint"] == @mediaDir})
           nfs_conf["nfs_exports"] << { "allowed" => ["*(ro,no_root_squash,no_subtree_check)"], "mountpoint" => @mediaDir }
       end
       nfs_conf["start_nfsserver"] = true
       NfsServer.Set(nfs_conf)
       # Firewall configuration is wiped by calling the Write function
       NfsServer.Write
       # Expose NFS service via SLP
       # The SLP service description lists all medium names
       desc_list = []
       desc_list = Dir.entries(@mediaDir)
       desc_list.delete('.')
       desc_list.delete('..')
       desc_list.uniq!
       desc_list.sort!
       SLP.RegFile("service:sles4sapinst:nfs://$HOSTNAME/data/SAP_CDs,en,65535",{ "provided-media" => desc_list.join(",") },"sles4sapinst.reg")
       Service.Enable("slpd")
       if !(Service.Active("slpd") ? Service.Restart("slpd") : Service.Start("slpd"))
           Report.Error(_("Failed to start SLP server. SAP mediums will not be discovered by other computers."))
       end
       # Restore and configure firewall
       RestoreAndRemoveBackupSysconfigFirewall()
       SuSEFirewall.ReadCurrentConfiguration
       SuSEFirewall.SetServicesForZones(["service:openslp","service:nfs-kernel-server"], ["INT", "EXT", "DMZ"], true)
       SaveAndRestartFirewallWorkaround()
       # Restarting NFS before restarting firewall may not work
       Service.Enable("nfs-server")
       RestartNFSWorkaround()
    end

    #Published functions
    publish :function => :Read,                :type => "boolean ()"
    publish :function => :Write,               :type => "void ()"
    publish :function => :UmountSources,       :type => "void ()"
    publish :function => :ParseXML,            :type => "boolean ()"
    publish :function => :MountSource,         :type => "string ()"
    publish :function => :CopyFiles,           :type => "void ()"
    publish :function => :ShowPartitions,      :type => "string ()"
    publish :function => :WriteProductDatas,   :type => "void ()"
    publish :function => :ExportSAPCDs,        :type => "void ()"
    
    # Published module variables
    publish :variable => :createLinks,       :type => "boolean"
    publish :variable => :importSAPCDs,      :type => "boolean"
    publish :variable => :sapCDsURL,         :type => "string"
    publish :variable => :instEnvList,       :type => "list"
    publish :variable => :instDir,           :type => "string"
    publish :variable => :instDirBase,       :type => "string"
    publish :variable => :instMasterType,    :type => "string"
    publish :variable => :instMode,          :type => "string"
    publish :variable => :exportSAPCDs,      :type => "string"
    publish :variable => :mountPoint,        :type => "string"
    publish :variable => :mediaDir,          :type => "string"
    publish :variable => :mediaDirBase,      :type => "string"
    publish :variable => :productXML,        :type => "string"
    publish :variable => :partXMLPath,       :type => "string"
    publish :variable => :ayXMLPath,         :type => "string"
    publish :variable => :instDir,           :type => "string"
    publish :variable => :prodCount,         :type => "integer"


    private
    #############################################################
    #
    # Private function to find relevant directories on the media
    #
    ############################################################
    #***********************************
    # Read in our configuration file in /etc/sysconfig
    # set some defaults if its not there
    #
    def parse_sysconfig()
      @mountPoint = Misc.SysconfigRead(
        path(".sysconfig.sap-installation-wizard.SOURCEMOUNT"),
        "/mnt"
      )
      @mediaDir = Misc.SysconfigRead(
        path(".sysconfig.sap-installation-wizard.MEDIADIR"),
        "/data/SAP_CDs"
      )
      @instDirBase = Misc.SysconfigRead(
        path(".sysconfig.sap-installation-wizard.INSTDIR"),
        "/data/SAP_INST"
      )
      @xmlFilePath = Misc.SysconfigRead(
        path(".sysconfig.sap-installation-wizard.MEDIAS_XML"),
        "/etc/sap-installation-wizard.xml"
      )
      @multi_prods = Misc.SysconfigRead(
        path(".sysconfig.sap-installation-wizard.MULTIPLE_PRODUCTS"),
        "yes"
      ) == "yes" ? true : false
      @partXMLPath = Misc.SysconfigRead(
        path(".sysconfig.sap-installation-wizard.PART_XML_PATH"),
        "/usr/share/YaST2/include/sap-installation-wizard"
      )
      @ayXMLPath = Misc.SysconfigRead(
        path(".sysconfig.sap-installation-wizard.PRODUCT_XML_PATH"),
        "/usr/share/YaST2/include/sap-installation-wizard"
      )
      @installScript = Misc.SysconfigRead(
        path(".sysconfig.sap-installation-wizard.SAPINST_SCRIPT"),
        "/usr/share/YaST2/include/sap-installation-wizard/sap_inst.sh"
      )
      @instMode = Misc.SysconfigRead(
        path(".sysconfig.sap-installation-wizard.SAP_AUTO_INSTALL"),
        "no"
      ) == "yes" ? "auto" : "manual"

      @exportSAPCDs = Misc.SysconfigRead(
        path(".sysconfig.sap-installation-wizard.SAP_EXPORT_CDS"),
        "no"
      ) == "yes" ? true : false

      @sapCDsURL = Misc.SysconfigRead(
        path(".sysconfig.sap-installation-wizard.SAP_CDS_URL"),
        ""
      )

      nil
    end

    # ***********************************
    # select the usb media we want use
    #
    def usb_select
      usb_list = []
      probe = Convert.convert(
        SCR.Read(path(".probe.usb")),
        :from => "any",
        :to   => "list <map>"
      )
      Builtins.foreach(probe) do |d|
        if Ops.get_string(d, "bus", "USB") == "SCSI" &&
            Builtins.haskey(d, "dev_name")
          i = 1
          dev = Ops.get_string(d, "dev_name", "") + Builtins.sformat("%1", i)
          s = Ops.get_integer(d, ["resource", "size", 0, "x"], 0) * Ops.get_integer(d, ["resource", "size", 0, "y"], 0) / 1024 / 1024 / 1024
          while SCR.Read(path(".target.lstat"), dev) != {}
            model = Ops.get_string(d, "model", "")
            log.info( "#{dev} #{model} #{size}GB")
            ltmp = Builtins.regexptokenize(dev, "/dev/(.*)")
            usb_list = Builtins.add(
              usb_list,
              Item(
                Id(Ops.get_string(ltmp, 0, "")),
                Builtins.sformat(
                  "%1 %2GB Partition %3",
                  model,
                  s,
                  i
                ),
                false
              )
            )
            i = i+1
            dev = Ops.get_string(d, "dev_name", "") + Builtins.sformat("%1", i)
          end
        end
      end
      return "ERROR:No USB Device was found" if usb_list == []
      help_text_instMaster = _("<p>Please enter the right USB device.</p>")
      content_instMaster = HBox(
        VBox(HSpacing(13)),
        VBox(
          HBox(Label("Please select the right USB device.")),
          HBox(HSpacing(13), ComboBox(Id(:device), " ", usb_list), HSpacing(18))
        ),
        VBox(HSpacing(13))
      )
      Wizard.SetContents(
        _("SAP Installation Wizard - Step 1"),
        content_instMaster,
        help_text_instMaster,
        false,
        true
      )
      while true
        button = UI.UserInput
        device = Convert.to_string(UI.QueryWidget(Id(:device), :Value))
        return device
      end
    
      nil
    end
    
    def find_sap_media(base)
    end

    # Show the dialog where 
    def media_dialog(wizard)
      log.info("-- Start media_dialog ---")
      @dbMap = {}
      @sourceDir = ""
      @umountSource = false
      while true
        case UI.UserInput
        when :back
            return :back
        when :abort, :cancel
            return :abort
        when :skip_copy_medium
#          [:scheme, :location, :link].each { |widget|
#            UI.ChangeWidget(Id(widget), :Enabled, false)
#          }
          [:scheme, :location].each { |widget|
            UI.ChangeWidget(Id(widget), :Enabled, false)
          }
          UI.ChangeWidget(Id(:do_copy_medium), :Value, false)
        when :do_copy_medium
#         [:scheme, :location, :link].each { |widget|
#           UI.ChangeWidget(Id(widget), :Enabled, true)
#         }
          [:scheme, :location].each { |widget|
            UI.ChangeWidget(Id(widget), :Enabled, true)
          }
          UI.ChangeWidget(Id(:skip_copy_medium), :Value, false)
        when :local_im
            # Choosing an already prepared installation master
            im = UI.QueryWidget(Id(:local_im), :Value)
            if im == "---"
                # Re-enable media input
                UI.ChangeWidget(Id(:scheme), :Enabled, true)
#               UI.ChangeWidget(Id(:link), :Enabled, true)
                UI.ChangeWidget(Id(:location), :Enabled, true)
                next
            end
            # Write down media location and disable media input
            UI.ChangeWidget(Id(:scheme), :Value, "dir")
            UI.ChangeWidget(Id(:scheme), :Enabled, false)
#           UI.ChangeWidget(Id(:link), :Enabled, false)
            UI.ChangeWidget(Id(:location), :Value, @mediaDir + "/" + Convert.to_string(UI.QueryWidget(Id(:local_im), :Value)))
            UI.ChangeWidget(Id(:location), :Enabled, false)
        when :scheme
            # Basically re-render layout
            do_default_values(wizard)
        when "media"
          #We have modified the list of selected media
          UI.ChangeWidget(Id(:skip_copy_medium), :Value, true)
          UI.ChangeWidget(Id(:do_copy_medium), :Value, false)
          [:scheme, :location].each { |widget|
            UI.ChangeWidget(Id(widget), :Enabled, false)
          }
        when :next
            #Set the selected Items
            if UI.WidgetExists( Id("media") )
              @selectedMedia.each_key { |medium|
                 @selectedMedia[medium] = false
              }
              UI.QueryWidget(Id("media"),:SelectedItems).each {|medium|
                 @selectedMedia[medium] = true
              }
              log.info("selectedMedia #{@selectedMedia}")
            end

            # Export locally stored mediums over NFS
            @exportSAPCDs = true if !!UI.QueryWidget(Id(:export), :Value)
            # Set installation mode to preauto so that only installation profiles are collected
            @instMode = "preauto" if !!UI.QueryWidget(Id(:auto), :Value)

            scheme          = Convert.to_string(UI.QueryWidget(Id(:scheme), :Value))
            @locationCache  = Convert.to_string(UI.QueryWidget(Id(:location), :Value))
            if scheme == "local"
                #This value can be reset by MountSource if the target is iso file.
#               @createLinks = @importSAPCDs || !!UI.QueryWidget(Id(:link), :Value)
            end
            @sourceDir      = @locationCache

            if UI.QueryWidget(Id(:skip_copy_medium), :Value)
                return :forw
            end
            # Break the loop for a chosen installation master, without executing check_media
            if UI.WidgetExists(Id(:local_im)) && UI.QueryWidget(Id(:local_im), :Value).to_s != "---"
                return :forw
            end
            urlPath = MountSource(scheme, @locationCache)
            if urlPath != "" 
                ltmp    = Builtins.regexptokenize(urlPath, "ERROR:(.*)")
                if Ops.get_string(@ltmp, 0, "") != ""
                    Popup.Error( _("Failed to mount the location: ") + Ops.get_string(@ltmp, 0, ""))
                    next
                end
            end
            if scheme != "local"
                @sourceDir = @mountPoint +  "/" + urlPath
            elsif urlPath != ""
                @sourceDir = urlPath
            end
            @umountSource = true
            log.info("end urlPath #{urlPath}, @sourceDir #{@sourceDir}, scheme #{scheme}")
            break # No more input
        end # Case user input
      end # While true
      return :next
    end # Function media_dialog

    # ***********************************
    # show a default entry or the last entered path
    #
    def do_default_values(wizard)
    end

    def set_date
      @out = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "date +%Y%m%d-%H%M")
      )
      @date = Builtins.filterchars(
        Ops.get_string(@out, "stdout", ""),
        "0123456789-."
      )
    end
  end   

  SAPMedia = SAPMediaClass.new
  SAPMedia.main

end

