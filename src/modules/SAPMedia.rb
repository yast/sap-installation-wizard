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
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("SAP Media Reader Started")


      #String to save the date. Will be set by set_date
      @date   = ""

      #Hash for design the dialogs
      #Help text for the fututre. This will be available only in SP1
      #                          '<p><b>' + _("SUSE HA for SAP Simple Stack") + '</p></b>' +
      #                          _("With this installation mode the <b>SUSE-HA for SAP Simple Stack</b> can be installed and configured.") +
      @dialogs = {
         "inst_master" => {
             "help"    => _("<p>Enter location of SAP installation master medium to prepare it for use.</p>"),
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
      ret=:next
      Builtins.y2milestone("-- SAPMedia.Read Start ---")
      if @sapCDsURL != ""
         mount_sap_cds()
      end

      # If there are installation profiles waiting to be installed, ask user what they want to do with them.
      while Dir.exists?(  Builtins.sformat("%1/%2/", @instDirBase, @prodCount) )
        @instDir = Builtins.sformat("%1/%2", @instDirBase, @prodCount)
        @prodCount = @prodCount.next
        if !File.exists?(@instDir + "/installationSuccesfullyFinished.dat") && File.exists?(@instDir + "/product.data")
          # Do not care about existing installations if we make autoinstallation
          next if Mode.mode() == "autoinstallation"

          productData = Convert.convert(
              SCR.Read(path(".target.ycp"), @instDir + "/product.data"),
              :from => "any",
              :to   => "map <string, any>"
            )

          # User has three choices: do nothing, ignore, or run it at end of the wizard workflow
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
      @instDir = Builtins.sformat("%1/%2", @instDirBase, @prodCount)
      return ret
    end

    #############################################################
    #
    # Writes the configuration environment of the installation
    # @return :next
    #
    #############################################################
    def Write()
      Builtins.y2milestone("-- SAPMedia.Write Start ---")

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
               Builtins.y2milestone("Can not mount medium %1. Reason %2",medium["url"],urlPath)
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
	     File.write(@instDir + "/ay_q_masterpass", prod["sapMasterPW"])
	     File.write(@instDir + "/ay_q_sid",        prod["sid"])
	     File.write(@instDir + "/ay_q_sapinstnr",  prod["sapInstNr"])
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
	  end
	  set_date()
          logfile = "/var/adm/autoinstall/logs/sap_inst." + @date + ".log"
	  script << Builtins.sformat(
            " -m \"%1\" -i \"%2\" -t \"%3\" -y \"%4\" -d \"%5\"",
	    @instDir + "/Instmaster",
	    @PRODUCT_ID,
	    @DB,
	    @instMasterType,
	    @instDir
	    )
	  Builtins.y2milestone("Starting Installation : %1 ",script)
          require "open3"
	  f = File.new(logfile,"w")
          Open3.popen2e(script) {|i,o,t|
             i.close
             o.each_line {|line|
		f << line
             }
          }
	  f.close
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
      Builtins.y2milestone("-- SAPMedia.Import Start ---%1",@SAPMediaTODO)

      true
    end

    #############################################################
    #
    # Export the configuration of the auto installation
    # @return true
    #
    #############################################################
    def Export()
      Builtins.y2milestone("-- SAPMedia.Export Start ---")
      #TODO

      {}
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
        instMasterList     = SAPXML.is_instmaster(@sourceDir)
        @instMasterType    = Ops.get(instMasterList, 0, "")
        @instMasterPath    = Ops.get(instMasterList, 1, "")
        @instMasterVersion = Ops.get(instMasterList, 2, "")

        Builtins.y2milestone(
          "found SAP instmaster at %1 type %2 version %3",
          @instMasterPath,
          @instMasterType,
          @instMasterVersion
        )
        if @instMasterPath == nil || @instMasterPath.size == 0
           Popup.Error(_("The location has expired or does not point to an SAP installation master.\nPlease check your input."))
        else
           #We have found the installation master
           run = false
        end
      end
      case @instMasterType
        when "SAPINST"
          ret = :SAPINST
        when "HANA"
          @instMasterType = "HANA"
          @mediaDir = @instDir
          ret = :HANA
        when /^B1/
          @mediaDir = @instDir
          ret = :B1
      end
      if @instMasterType == 'HANA'
        # HANA instmaster must reside in "Instmaster" directory, instead of "Instmaster-HANA" directory.
        CopyFiles(@instMasterPath, @mediaDir, "Instmaster", false)
        @instMasterPath = @mediaDir + "/Instmaster"
      else
        if ! File.exist?(@mediaDir + "/Instmaster-" + @instMasterType + '-' + @instMasterVersion  )
	   #Make a local copy of the installation master
           CopyFiles(@instMasterPath, @mediaDir, "Instmaster-" + @instMasterType + "-" + @instMasterVersion, false)
        end
        CopyFiles(@instMasterPath, @instDir, "Instmaster", false)
        @instMasterPath = @instDir + "/Instmaster"
      end
      UmountSources(@umountSource)
      return ret
    end

    #############################################################
    #
    # Copy the SAP Media
    #
    ############################################################
    def CopyNWMedia
      Builtins.y2milestone("-- Start CopyNWMedia ---")
      if @importSAPCDs
          # Skip the dialog all together if SAP_CD is already mounted from network location
          # There is no chance for user to copy new mediums to the location
          return :next
      end
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
              run = Popup.YesNo(_("Are there more SAP product mediums to be prepared?"))
           when :next 
              media=find_sap_media(@sourceDir)
              media.each { |path,label|
		if File.exist?(@mediaDir + "/" + label)
		   Popup.Warning(Builtins.sformat(_("The selected medium '%1' was already copied."),label))
		   next
                end	
                CopyFiles(path, @mediaDir, label, false)
                @selectedMedia[label] = true;
              }
              run = Popup.YesNo(_("Are there more SAP product mediums to be prepared?"))
        end
      end
      mediaList = []
      @selectedMedia.each_key { |medium|
        if @selectedMedia[medium]
          mediaList << @mediaDir + "/" + medium
	end
      }
      mediaList << @instDir + "/" + "Instmaster"
      IO.write(@instDir + "/start_dir.cd" , mediaList.join("\n"))
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
        CopyFiles(@sourceDir, @instDir, "Supplement", false)
        ParseXML(@instDir + "/Supplement/" + @productXML)
        run = Popup.YesNo(_("Are there more supplementary mediums to be prepared?"))
      end
      return :next
    end
    #***********************************
    # Umount sources.
    #  @param boolean doit
    def UmountSources(doit)
      Builtins.y2milestone("-- SAPMedia.UmountSources Start ---")
      return if !doit
      WFM.Execute(path(".local.umount"), @mountPoint)
      if @mountPoint != @mmount
        WFM.Execute(path(".local.umount"), @mmount)
        SCR.Execute(path(".target.bash"), "/bin/rmdir " + @mmount)
      end

      nil
    end

    #***********************************
    # Create a temporary directory.
    #  @param  string temp
    #  @return string the path to the created directory
    def MakeTemp(temp)
      Builtins.y2milestone("-- SAPMedia.MakeTemp Start ---")
      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          "/bin/mktemp -d " + temp
        )
      )
      tmp = Builtins.substring(
        Ops.get_string(out, "stdout", ""),
        0,
        Ops.subtract(Builtins.size(Ops.get_string(out, "stdout", "")), 1)
      )
      tmp
    end

    # ***********************************
    # Parse and merge our xml snipplets
    #
    def ParseXML(file)
      ret = false
      if file != ""
        SCR.Write(
          path(".target.string"),
          "/tmp/current_media_path",
          File.dirname(file)
        )
        profile = XML.XMLToYCPFile(file)
        if profile != {} && Builtins.size(profile) == 0
          # autoyast has read the autoyast configuration file but something went wrong
          message = _(
            "The XML parser reported an error while parsing the autoyast profile. The error message is:\n"
          )
          message = Ops.add(message, XML.XMLError)
          Popup.Error(message)
        end
        AutoinstData.post_packages = []
        Profile.current = { "general" => { "mode" => { "final_restart_services" => false , "activate_systemd_default_target" => false } }, "software" => {}, "scripts" => {} }
        if Builtins.haskey(Ops.get_map(profile, "general", {}), "ask-list")
          Ops.set(
            Profile.current,
            ["general", "ask-list"],
            Builtins.merge(
              Ops.get_list(Profile.current, ["general", "ask-list"], []),
              Ops.get_list(profile, ["general", "ask-list"], [])
            )
          )
          profile = Builtins.remove(profile, "general")
        end
        if Builtins.haskey(
            Ops.get_map(profile, "software", {}),
            "post-packages"
          )
          Ops.set(
            Profile.current,
            ["software", "post-packages"],
            Builtins.merge(
              Ops.get_list(Profile.current, ["software", "post-packages"], []),
              Ops.get_list(profile, ["software", "post-packages"], [])
            )
          )
          profile = Builtins.remove(profile, "software")
        end
        if Builtins.haskey(profile, "scripts")
          Builtins.foreach(["init-scripts", "chroot-scripts", "post-scripts"]) do |key|
            Ops.set(
              Profile.current,
              ["scripts", key],
              Builtins.merge(
                Ops.get_list(Profile.current, ["scripts", key], []),
                Ops.get_list(profile, ["scripts", key], [])
              )
            )
          end
          AutoinstScripts.Import(Ops.get_map(Profile.current, "scripts", {})) # required for the chroot scripts wich are needed in stage1 already
          profile = Builtins.remove(profile, "scripts")
        end
        Profile.Import(
          Convert.convert(
            Builtins.union(Profile.current, profile),
            :from => "map",
            :to   => "map <string, any>"
          )
        )
        AutoInstall.Save
        Wizard.CreateDialog

        # SUSE firewall behaves differently in auto installation mode.
        # Because SUSE firewall is configured (later) by this module, hence the current YaST mode must be preserved.
        original_mode = Mode.mode()
        Mode.SetMode("autoinstallation")

        Stage.Set("continue")
        WFM.CallFunction("inst_autopost", [])
        AutoinstSoftware.addPostPackages(
          Ops.get_list(Profile.current, ["software", "post-packages"], [])
        )
        if !Builtins.haskey(Profile.current, "networking")
          Profile.current = Builtins.add(
            Profile.current,
            "networking",
            { "keep_install_network" => true }
          )
        end
        Pkg.TargetInit("/", false)
        WFM.CallFunction("inst_rpmcopy", [])
        WFM.CallFunction("inst_autoconfigure", [])

        Mode.SetMode(original_mode)

        Wizard.CloseDialog
        SCR.Execute(path(".target.remove"), "/tmp/current_media_path")
        ret = true
      end
      ret
    end

    # ***********************************
    #  mounts a "scheme://host/path" to a mountPoint dir
    #  @param  scheme like "device", location like "/sda1"
    #  @return sting  Starting with ERROR: and containing the error message if ith happenend
    #                 Containing the mount point whre the source was mounted.
    #  The mountPoint was defined in /etc/sysconfig/sap-installation-wizard
    #
    def MountSource(scheme, location)
      ret     = nil
      i       = true
      isopath = []
      @mmount = @mountPoint
      Builtins.y2milestone(
        "MountSource called %1 %2 %3",
        scheme,
        location,
        @mountPoint
      )

      # In case of usb device we have to select the right usb device
      if scheme == "usb"
        scheme = "device"
        tmp = usb_select
        ltmp = Builtins.regexptokenize(tmp, "ERROR:(.*)")
        return tmp if Ops.get_string(ltmp, 0, "") != ""
        location = Ops.add(Ops.add(tmp, "/"), location)
      end

      #create the needed directories
      cmd = Builtins.sformat("mkdir -p '%1'", @mountPoint)
      Builtins.y2milestone("mkdir: %1", cmd)
      SCR.Execute(path(".target.bash"), cmd)
      #TODO Clean up spaces at the end.
      while i
        if Builtins.lsubstring( location, Builtins.size(location) - 1, 1) == " "
          location = Builtins.lsubstring( location, 0, Builtins.size(location) - 1)
        else
          i = false
        end
      end
      @locationCache = location

      if scheme == "cdrom"
        cdromDevice = "cdrom"
        location = Ops.add(Ops.add(cdromDevice, "/"), location)
        scheme = "device"
      end

      if /^cdrom::(?<dev>.*)/ =~ scheme
        cdromDevice = dev
        location = Ops.add(Ops.add(cdromDevice, "/"), location)
        scheme = "device"
      end

      if scheme == "device"
        parsedURL = URL.Parse(Ops.add("device://", location))
        Builtins.y2milestone("parsed URL: %1", parsedURL)

        Ops.set(
          parsedURL,
          "host",
          "/dev/" + Ops.get_string(parsedURL, "host", "/cdrom")
        )

        WFM.Execute(
          path(".local.umount"),
          Ops.get_string(parsedURL, "host", "/dev/cdrom")
        ) # old (dead) mounts
        if !Convert.to_boolean(
            SCR.Execute(
              path(".target.mount"),
              [Ops.get_string(parsedURL, "host", "/dev/cdrom"), @mountPoint],
              "-o shortname=mixed"
            )
          ) &&
            !Convert.to_boolean(
              WFM.Execute(
                path(".local.mount"),
                [Ops.get_string(parsedURL, "host", "/dev/cdrom"), @mountPoint]
              )
            )
          ret = "ERROR:Can not mount required device."
        else
          ret = "/" + Ops.get_string(parsedURL, "path", "")
        end

        Builtins.y2milestone("MountSource parsedURL=%1", parsedURL)
      elsif scheme == "nfs"
        parsedURL = URL.Parse(Ops.add("nfs://", location))
        mpath     = Ops.get_string(parsedURL, "path", "")
        isopath   = Builtins.regexptokenize(
          Ops.get_string(parsedURL, "path", ""),
          "(.*)/(.*.iso)"
        )

        Builtins.y2milestone("MountSource nfs isopath %1", isopath)

        if isopath != []
          mpath = Ops.get_string(isopath, 0, "")
          @mmount = MakeTemp("/tmp/sapiwMountSourceXXXXX")
        end
        WFM.Execute(path(".local.umount"), @mountPoint) # old (dead) mounts
        out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            "mount -o nolock " + Ops.get_string(parsedURL, "host", "") + ":" + mpath + " " + @mmount
          )
        )
        if Ops.get_string(out, "stderr", "") != ""
          ret = Ops.add("ERROR:", Ops.get_string(out, "stderr", ""))
        else
          ret = ""
        end
        Builtins.y2milestone("MountSource parsedURL=%1", parsedURL)
      elsif scheme == "smb"
        parsedURL = URL.Parse(Ops.add("smb://", location))
        mpath = Ops.get_string(parsedURL, "path", "")
        isopath = Builtins.regexptokenize(
          Ops.get_string(parsedURL, "path", ""),
          "(.*)/(.*.iso)"
        )

        Builtins.y2milestone("MountSource smb isopath %1", isopath)

        if isopath != []
          mpath = Ops.get_string(isopath, 0, "")
          @mmount = MakeTemp("/tmp/sapiwMountSourceXXXXX")
        end
        mopts = "-o ro"
        if Builtins.haskey(parsedURL, "workgroup") &&
            Ops.get_string(parsedURL, "workgroup", "") != ""
          mopts = mopts + ",user=" + Ops.get_string(parsedURL, "workgroup", "") + "/" + Ops.get_string(parsedURL, "user", "") + "%" + Ops.get_string(parsedURL, "password", "")
        elsif Builtins.haskey(parsedURL, "user") &&
            Ops.get_string(parsedURL, "user", "") != ""
          mopts = mopts + ",user=" + Ops.get_string(parsedURL, "user", "") + "%" + Ops.get_string(parsedURL, "password", "")
        else
          mopts = Ops.add(mopts, ",guest")
        end

        SCR.Execute(path(".target.bash"), Ops.add("/bin/umount ", @mountPoint)) # old (dead) mounts
        Builtins.y2milestone(
          "smbMount: %1",
          "/sbin/mount.cifs //" + Ops.get_string(parsedURL, "host", "") + mpath + " " + @mmount + " " + mopts
        )
        out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            "/sbin/mount.cifs //" + Ops.get_string(parsedURL, "host", "") + mpath + " " + @mmount + " " + mopts
          )
        )
        if Ops.get_string(out, "stderr", "") != ""
          ret = "ERROR:" + Ops.get_string(out, "stderr", "")
        else
          ret = ""
        end
        Builtins.y2milestone("MountSource parsedURL=%1", parsedURL)
      elsif scheme == "local"
        isopath = Builtins.regexptokenize(location, "(.*)/(.*.iso)")
        if isopath != []
          Builtins.y2milestone(
            "MountSource %1 %2 %3",
            Ops.get_string(isopath, 0, ""),
            Ops.get_string(isopath, 1, ""),
            @mountPoint
          )
          @mmount = Ops.get_string(isopath, 0, "")
          ret = ""
        else
          if SCR.Read(path(".target.lstat"), location) != {}
            ret = ""
          else
            ret = "ERROR: Can not find local path:" + location
          end
        end
      end
      if isopath != [] && ret == ""
        #The content of iso images must be copied.
        @createLinks = false
        Builtins.y2milestone(
          "Mount iso 'mount -o loop " + @mmount + "/" + Ops.get_string(isopath, 1, "") + " " + @mountPoint + "'"
        )
        out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            "mount -o loop " + @mmount + "/" + Ops.get_string(isopath, 1, "") + " " + @mountPoint
          )
        )
        ret = @mountPoint if scheme == "local"
        if Ops.get_string(out, "stderr", "") != ""
          ret = Ops.add(
            "ERROR:Can not mount required iso image.",
            Ops.get_string(out, "stderr", "")
          )
        end
      end

      Builtins.y2milestone("MountSource ret=%1", ret)
      ret
    end

    # ***********************************
    # Copies a complete directory-tree to a subdirectory of a targetdirectory
    # the targetdir must not exist, it is created
    #   Example: sourceDir = /home
    #            targetDir = /tmp
    #            subDir    = Documents
    #
    #   will end in: cp -a /home/* /tmp/Documents
    #
    def CopyFiles(sourceDir, targetDir, subDir, localCheck)
      # Check if we have it local
      Builtins.y2milestone("CopyFiles called:%1,%2,%3,%4", sourceDir, targetDir, subDir, localCheck)

      if localCheck
        localPath = check_local_path(subDir, sourceDir)
        if localPath != ""
          # We have something to use
          sourceDir = localPath
        end
      end

      # do not copy creat only a link
      #if @createLinks
      #   cmd = Builtins.sformat(
      #     "ln -s '%1' '%2'", sourceDir, targetDir + "/" + subDir
      #  )
      #  SCR.Execute(path(".target.bash"), cmd)
      #  return nil
      #end

      # create target dir
      cmd = Builtins.sformat(
        "mkdir -p '%1'", targetDir + "/" + subDir
      )
      SCR.Execute(path(".target.bash"), cmd)

      # our copy command
      cmd = Builtins.sformat(
        "find '%1/'* -maxdepth 0 -exec cp -a '{}' '%2/' \\;",
        sourceDir,
        targetDir + "/" + subDir
      )

      # get the size of our source
      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat(" du -s0 '%1' | awk '{printf $1}'", sourceDir)
        )
      )
      Builtins.y2milestone("Source Tech-Size progress %1", out)
      techsize = Builtins.tointeger(Ops.get_string(out, "stdout", "0"))

      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat("du -sh0 '%1' |awk '{printf $1}'", sourceDir)
        )
      )
      Builtins.y2milestone("Source Human-Size progress %1", out)
      humansize = Ops.get_string(out, "stdout", "")

      # show a progress bar during copy
      progress = 0
      Progress.Simple(
        "Copying Media",
        "Copying SAP " + subDir + " ( 0M of " + humansize + " )",
        techsize,
        ""
      )
      Progress.NextStep

      # normaly the cmd would block our screen, so we move it into the background

      # .process.start_shell is only for SLES11
      pid = Convert.to_integer(SCR.Execute(path(".process.start_shell"), cmd))
      if pid == nil || Ops.less_or_equal(pid, 0)
        if Popup.ErrorAnyQuestion(
            "Can not start copy",
            "Do you want to retry ?",
            "Retry",
            "Abort",
            :focus_yes
          )
          CopyFiles(sourceDir, targetDir, subDir, localCheck)
        else
          UI.CloseDialog
          return
        end
      end
      #Builtins.y2milestone("running %1 with pid %2", cmd, pid)


      while SCR.Read(path(".process.running"), pid) == true
        Builtins.sleep(1000) # ms
        # get the size of our target
        out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat(
              "du -s %1 | awk '{printf $1}'",
              targetDir + "/" + subDir
            )
          )
        )
        #Builtins.y2milestone("Target Tech-Size progress %1", out)

        Progress.Step(Builtins.tointeger(Ops.get_string(out, "stdout", "0")))

        out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat(
              "du -sh %1 | awk '{printf $1}'",
              targetDir + "/" + subDir
            )
          )
        )
        #Builtins.y2milestone("Target Human-Size progress %1", out)

        Progress.Title(
          "Copying Media " + subDir + " ( " + Ops.get_string(out, "stdout", "OM") + " of " + humansize + " )"
        )

        # Checking the exit code (0 = OK, nil = still running, 'else' = error)
        exitcode = Convert.to_integer(SCR.Read(path(".process.status"), pid))
        #Builtins.y2milestone("Exitcode: %1", exitcode)

        if exitcode != nil && exitcode != 0
          Builtins.y2milestone(
            "Copy has failed, exit code was: %1, stderr: %2",
            exitcode,
            SCR.Read(path(".process.read_stderr"), pid)
          )
          error = Builtins.sformat(
            "Copy has failed, exit code was: %1, stderr: %2",
            exitcode,
            SCR.Read(path(".process.read_stderr"), pid)
          )
          Popup.Error(error)
          if Popup.ErrorAnyQuestion(
              "Failed to copy files from medium",
              "Would you like to retry?",
              "Retry",
              "Abort",
              :focus_yes
            )
            CopyFiles(sourceDir, targetDir, subDir, localCheck)
          else
            UI.CloseDialog
            return :abort
          end
        end
      end
      # release the process from the agent
      SCR.Execute(path(".process.release"), pid)
      Progress.Finish

      nil
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
    publish :function => :MakeTemp,            :type => "string ()"
    publish :function => :ParseXML,            :type => "boolean ()"
    publish :function => :MountSource,         :type => "string ()"
    publish :function => :CopyFiles,           :type => "void ()"
    publish :function => :CreatePartitions,    :type => "void ()"
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
            Builtins.y2milestone(
              "%1,%2,%3GB",
              dev,
              Ops.get_string(d, "model", ""),
              s
            )
            ltmp = Builtins.regexptokenize(dev, "/dev/(.*)")
            usb_list = Builtins.add(
              usb_list,
              Item(
                Id(Ops.get_string(ltmp, 0, "")),
                Builtins.sformat(
                  "%1 %2GB Partition %3",
                  Ops.get_string(d, "model", ""),
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
      Builtins.y2milestone("-- Start find_sap_media --- %1",base)
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
	  if label.length > 2
            path_map[d]=label[1].gsub(/\W/,"-") + label[2].gsub(/\W/,"-")
	  end
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
	  if label.length > 3
            path_map[d]=label[4].chop.gsub(/\W/,"-")
	  end
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
	  if label.length > 3
            path_map[d]=label[2].gsub(/\W/,"-") + label[3].gsub(/\W/,"-") + label[4].chop.gsub(/\W/,"-")
	  end
        end
      }

      #If we have not found anything we have to copy the whole medium when there is a LABAL.ASC file
      if path_map.empty?
        lf=base+"/LABEL.ASC"
        if File.exist?(lf)
          label=IO.readlines(lf,":")
	  if label.length > 2
            path_map[base]=label[1].gsub(/\W/,"-") + label[2].gsub(/\W/,"-") + label[3].chop.gsub(/\W/,"-")
	  end
        else
          #This is not a real SAP medium.
          Popup.Error( _("The location does not contain SAP installation data."))
        end
      end
      Builtins.y2milestone("path_map %1",path_map)
      return path_map
    end

    # Show the dialog where 
    def media_dialog(wizard)
      Builtins.y2milestone("-- Start media_dialog ---")
      @dbMap = {}
      has_back = true

      # Find the already-prepared mediums
      media = []
      if File.exist?(@mediaDir)
          media = Dir.entries(@mediaDir)
          media.delete('.')
          media.delete('..')
      end

      # Displayed above the new-medium input
      content_before_input = Empty()
      # The new-medium input
      content_input = Empty()
      # Displayed below the new-medium input
      content_advanced_ops = Empty()

      # Make dialog content acording to wizard stage
      case wizard
      when "sapmedium"
          # List existing product installation mediums (excluding installation master)
          product_media = media.select {|name| !(name =~ /Instmaster-/)}
          if !product_media.empty?
	      mediaItems = []
              product_media.each {|medium|
		 mediaItems << Item(Id(medium),  medium,  @selectedMedia.has_key?(medium) ? @selectedMedia[medium] : true )
	      }
              content_before_input = VBox( MultiSelectionBox(Id("media"), Opt(:notify), _("Ready for use:"), mediaItems) )
          end
          content_input = VBox(
            Left(RadioButton(Id(:do_copy_medium), Opt(:notify), _("Copy a medium"), true)),
            Left(HBox(
                HSpacing(6.0),
                ComboBox(Id(:scheme), Opt(:notify), " ", @scheme_list),
                InputField(Id(:location),Opt(:hstretch),
                    _("Prepare SAP installation medium (such as SAP kernel, database and exports)"),
                    @locationCache),
                HSpacing(6.0))),
          )
#          content_advanced_ops = VBox(
#              Left(CheckBox(Id(:link),_("Link to the installation medium, without copying its content to local location."),false))
#          )
      when "inst_master"
          # List installation masters
          has_back = false
          instmaster_media = media.select {|name| name =~ /Instmaster-/}
          if !instmaster_media.empty?
              if @importSAPCDs
                  # If SAP_CD is mounted from network location, do not allow empty selection
                  content_before_input = VBox(
                      Frame(_("Ready for use from:  " + @sapCDsURL.to_s),
                            Label(Id(:mediums), Opt(:hstretch), media.join("\n"))),
                      Frame(_("Choose an installation master"),
                            Left(ComboBox(Id(:local_im), Opt(:notify),"", instmaster_media))),
                  )
              else
                  # Otherwise, allow user to enter new installation master
                  content_before_input = Frame(
                    _("Choose an installation master"),
                    ComboBox(Id(:local_im), Opt(:notify),"", ["---"] + instmaster_media)
                  )
              end
          end
          content_input = HBox(
              ComboBox(Id(:scheme), Opt(:notify), " ", @scheme_list),
              InputField(Id(:location),Opt(:hstretch),
              _("Prepare SAP installation master"),
              @locationCache)
          )
          advanced_ops = [Left(CheckBox(Id(:auto),_("Collect installation profiles for SAP products but do not execute installation."), false))]
          if !@importSAPCDs
              # link & export options are not applicable if SAP_CD is mounted from network location
              advanced_ops += [
                # Left(CheckBox(Id(:link),_("Link to the installation master, without copying its content to local location (SAP NetWeaver only)."), false)),
                Left(CheckBox(Id(:export),_("Serve all installation mediums (including master) to local network via NFS."), false))
              ]
          end
          content_advanced_ops = VBox(*advanced_ops)
      when "supplement"
          # Find the already-prepared mediums
          product_media = media.select {|name| !(name =~ /Instmaster-/)}
          if !product_media.empty?
              content_before_input = Frame(_("Ready for use:"), Label(Id(:mediums), Opt(:hstretch), product_media.join("\n")))
          end
          content_input = HBox(
              ComboBox(Id(:scheme), Opt(:notify), " ", @scheme_list),
              InputField(Id(:location),Opt(:hstretch),
              _("Prepare SAP supplementary medium"),
              @locationCache)
          )
#          content_advanced_ops = VBox(
#              Left(CheckBox(Id(:link),_("Link to the installation medium, without copying its content to local location."),false))
#          )
      end

      after_advanced_ops = Empty()
      advanced_ops_left  = Empty()

      if wizard == "sapmedium"
          after_advanced_ops = VBox(
            VSpacing(2.0),
            Left(RadioButton(Id(:skip_copy_medium), Opt(:notify), _("Skip copying of medium")))
          )
          advanced_ops_left = HSpacing(6.0)
      end
      

      # Render the wizard
      if( content_advanced_ops == Empty() )
        content = VBox(
            Left(content_before_input),
            VSpacing(2),
            Left(content_input),
            VSpacing(2),
            Left(after_advanced_ops)
        )
      else
        content = VBox(
            Left(content_before_input),
            VSpacing(2),
            Left(content_input),
            VSpacing(2),
            HBox(advanced_ops_left, Frame(_("Advanced Options"), Left(content_advanced_ops))),
            Left(after_advanced_ops)
        )
      end

      Wizard.SetContents(
        _("SAP Installation Wizard"),
        content,
        @dialogs[wizard]["help"],
        has_back,
        true
      )
      Wizard.RestoreAbortButton()
      UI.ChangeWidget(:scheme, :Value, @schemeCache)
      do_default_values(wizard)
      @sourceDir = ""
      @umountSource = false
      # Special case for SAP_CD being network location
      if @importSAPCDs && wizard == "inst_master"
          # Activate the first installation master option
          UI.ChangeWidget(Id(:scheme), :Value, "dir")
          UI.ChangeWidget(Id(:scheme), :Enabled, false)
#         UI.ChangeWidget(Id(:link), :Enabled, false)
          UI.ChangeWidget(Id(:location), :Value, @mediaDir + "/" + Convert.to_string(UI.QueryWidget(Id(:local_im), :Value)))
          UI.ChangeWidget(Id(:location), :Enabled, false)
      end
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
              Builtins.y2milestone("selectedMedia %1",@selectedMedia)
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
            Builtins.y2milestone("urlPath %1, @sourceDir %2, scheme %3",urlPath,@sourceDir,scheme)
            break # No more input
        end # Case user input
      end # While true
      return :next
    end # Function media_dialog

    # ***********************************
    # show a default entry or the last entered path
    #
    def do_default_values(wizard)
        val = Convert.to_string(UI.QueryWidget(Id(:scheme), :Value))
        @schemeCache = val
        if val == "device"
#         UI.ChangeWidget(Id(:link), :Value, false)
#         UI.ChangeWidget(Id(:link), :Enabled, false)
          UI.ChangeWidget(
            :location,
            :Value,
            @locationCache == "" ? "sda1/directory" : @locationCache
          )
        elsif val == "nfs"
#         UI.ChangeWidget(Id(:link), :Value, false)
#         UI.ChangeWidget(Id(:link), :Enabled, false)
          UI.ChangeWidget(
            :location,
            :Value,
            @locationCache == "" ? "nfs.server.com/directory/" : @locationCache
          )
        elsif val == "usb"
#         UI.ChangeWidget(Id(:link), :Value, false)
#         UI.ChangeWidget(Id(:link), :Enabled, false)
          UI.ChangeWidget(
            :location,
            :Value,
            @locationCache == "" ? "/directory/" : @locationCache
          )
        elsif val == "local"
#         UI.ChangeWidget(Id(:link), :Value, true)
#         UI.ChangeWidget(Id(:link), :Enabled, true)
          UI.ChangeWidget(
            :location,
            :Value,
            @locationCache == "" ? "/directory/" : @locationCache
          )
        elsif val == "smb"
#         UI.ChangeWidget(Id(:link), :Value, false)
#         UI.ChangeWidget(Id(:link), :Enabled, false)
          UI.ChangeWidget(
            :location,
            :Value,
            @locationCache == "" ?
              "[username:passwd@]server/path-on-server[?workgroup=my-workgroup]" :
              @locationCache
          )
        else
          #This is cdrom1 cdrom2 and so on
#         UI.ChangeWidget(Id(:link), :Value, false)
#         UI.ChangeWidget(Id(:link), :Enabled, false)
          UI.ChangeWidget(
            :location,
            :Value,
            @locationCache == "" ? "//" : @locationCache
          )
        end
        nil
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

    def mount_sap_cds
        # Un-mount it, in case if the location was previously mounted
        # Run twice to umount it forcibly and surely
        SCR.Execute(path(".target.bash_output"), "/usr/bin/umount -lfr " + @mediaDir)
        SCR.Execute(path(".target.bash_output"), "/usr/bin/umount -lfr " + @mediaDir)
        # Make sure the mount point exists
        SCR.Execute(path(".target.bash_output"), "/usr/bin/mkdir -p " + @mediaDir)
        # Mount new network location
        url     = URL.Parse(@sapCDsURL)
        command = ""
        case url["scheme"]
           when "nfs"
            command = "mount -o nolock " + url["host"] + ":" + url["path"] + " " + @mediaDir
           when "smb"
            mopts = "-o ro"
            if url["workgroup"] != ""
               mopts = mopts + ",user=" + url["workgroup"] + "/" + url["user"] + "%" + url["password"]
            elsif url["user"] != ""
               mopts = mopts + ",user=" + url["user"] + "%" + url["password"]
            else
               mopts = mopts + ",guest"
            end
            command = "/sbin/mount.cifs //" + url["host"] + url["path"] + " " + @mediaDir + " " + mopts 
        end
        out = Convert.to_map( SCR.Execute( path(".target.bash_output"), command ))
            if Ops.get_string(out, "stderr", "") != ""
               @importSAPCDs = false
               Popup.ErrorDetails("Failed to mount " + @sapCDsURL + "\n" +
                             "The wizard will move on without using network media server.",
                            Ops.get_string(out, "stderr", ""))
            else
               @importSAPCDs = true
            end
        return
    end

    
  end   

  SAPMedia = SAPMediaClass.new
  SAPMedia.main

end

