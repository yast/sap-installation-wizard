# encoding: utf-8

# ex: set tabstop=4 expandtab:
# vim: set tabstop=4:expandtab
require "yast"

module Yast
  class SAPInstClass < Module
    def main
      Yast.import "UI"
      Yast.import "Pkg"

      textdomain "sap-installation-wizard"
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("SAP Instalation Wizard started")

      Yast.import "AutoInstall"
      Yast.import "AutoinstConfig"
      Yast.import "AutoinstData"
      Yast.import "AutoinstScripts"
      Yast.import "AutoinstSoftware"
      Yast.import "FileUtils"
      Yast.import "LogView"
      Yast.import "Misc"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Profile"
      Yast.import "Progress"
      Yast.import "SAPMedia"
      Yast.import "Service"
      Yast.import "Stage"
      Yast.import "Storage"
      Yast.import "Wizard"
      Yast.import "URL"
      Yast.import "XML"

      # ***********************************
      # Initialize global varaiables
      # ***********************************

      #Path to the installation master
      @instMasterPath =""

      #Type of the installation master
      @instMasterType = ""

      #Version of the installation master
      @instMasterVersion = ""

      #The installatin type: STANDARD, STANDALONE, DISTRIBUTED, SUSE-HA-ST, HA, SBC
      @instType = ""

      #The selected database
      @DB = ""

      #The mode of the installation:
      # manual:  all installation steps will be accomplished.
      # auto:    a prepared auto installation will be compleated.
      # preauto: an installation environment for autoinstallation will be prepared.
      @instMode = "manual"

      #The temporare mount point for SAP media.
      #The value can be set in /etc/sysconfig/sap-installation-wizard
      @mountPoint = ""

      #The media of the SAP installation will be saved in this directory
      #The value can be set in /etc/sysconfig/sap-installation-wizard
      @mediaDir = ""

      #The installation will be prepared in this directory 
      #In case of HANA and B1 instDir and mediaDir is the same
      @instDir = ""

      #The installations will be prepared in this directory
      #For all installation a separate directory will be created
      @instDirBase = ""

      #If this variable was set true the local paths will not be copyed
      #Only symlinks will be created.
      @createLinks = false

      #This variable contains the list of the media was copied
      @mediaList = []

      #The PRODUCT_ID of the selected porduct
      @PRODUCT_ID = ""

      #The name of the selected porduct
      @PRODUCT_NAME = ""

      #Name of the autoyast xml on supplementary media
      @productXML = "product.xml"

      #The list of the products which was selected in the
      #first step by SWPM
      @productList = []

      #Defaults for productList
      @productListDefaults = {
         "ay_xml"       => "",
         "partitioning" => "base_partitioning",
         "scrit_name"   => "sap_inst.sh"
      }

      #Path to the directory where the partitioning xml files can be found
      @partXMLPath = "/usr/share/YaST2/include/sap-installation-wizard/"

      #Path to the directory where the autoyast xml files can be found
      @ayXMLPath = "/usr/share/YaST2/include/sap-installation-wizard/"

      # The product counter
      @prodCount = 0

      # Array of the partiioning plans which will be executed in Write
      @productPartitioningList = []

      # Array of the scripts which will be executed in Write
      @productScriptsList = []

      @STACK = ""
      @SEARCH = ""
      @TYPE = ""
      @tmp = ""
      @date = ""

      @sapMinVersion = 720

      @multi_prods = true
      @needSaplup = false
      @ownSaplupMedia = false
      @needSAPCrypto = false
      @needIBMJava = false
      @haveCrypto = false
      @locationCache = ""
      @xmlFilePath = ""
      @productXMLPath = ""
      @installScript = ""
      @productPartitioning = ""
      @localIMPathList = []
      @schemeCache = "local"
      @mmount = ""

    end


    #***********************************
    # Reads the SAP installation configuration.
    # @return true or false
    def Read()
      ret=:next
      Builtins.y2milestone("-- Start Write ---")
      # read the global configuration
      parse_sysconfig

      #TODO Temporary dirty patch 
      SCR.Execute(path(".target.bash"), "cp /usr/share/YaST2/include/sap-installation-wizard/inst_autoconfigure.rb /usr/share/YaST2/clients/inst_autoconfigure.rb" )
     
      # Read the existing media
      if File.exist?(SAPInst.mediaDir)
         media = Dir.entries(@mediaDir)
         media.delete('.')
         media.delete('..')
         media.each { |m|
            n = @mediaDir + "/" + m
            if File.symlink?(n)
              n = File.readlink(n)
            end
            next if ! File.exists?(n)
            next if ! File.directory?(n)
            @mediaList << File.realpath(n)
         }
      end

      # New feature in SLE12 (pre installation)
      # If installing supliment products we have to increase @prodCount
      while Dir.exists?(  Builtins.sformat("%1/%2/", @instDirBase, @prodCount) )
        @instDir = Builtins.sformat("%1/%2", @instDirBase, @prodCount)

        # If the product was not installed only copied and the runSapInstall is true
        # we have to read the product.data becouse the sap installer will be started
        # after finishing the work.
        if !File.exists?(@instDir + "/installationSuccesfullyFinished.dat") && File.exists?(@instDir + "/product.data")
          productData2 = Convert.convert(
            SCR.Read(path(".target.ycp"), @instDir + "/product.data"),
            :from => "any",
            :to   => "map <string, any>"
          )
          if Popup.YesNo(_("A not completed installation was found:") + "\n" +
                         Ops.get_string(productData2,"PRODUCT_NAME","") + "\n" +
                         Ops.get_string(productData2,"PRODUCT_ID","")   + "\n" +
                         _("Do you want to start the installation again?"))
             WriteProductDatas(productData2)
          end
        end
        @prodCount = @prodCount.next
      end
      Builtins.y2milestone("@instMode %1 @productScriptsList %2",@instMode,@productScriptsList )
      if @instMode == "auto"
         Builtins.y2milestone("Read Returns :auto")
         ret=:auto
      else
        #if @prodCount > 0
        #   #TODO Warning 
        #   Popup.Warning( _("There are some not installed products."))
        #end
        @instDir = Builtins.sformat("%1/%2", @instDirBase, @prodCount)
        Builtins.y2milestone("#### Installation Directory is: %1", @instDir)
        
        #Create the base directories if the does not exists
        SCR.Execute(path(".target.bash"), "mkdir -p " + @instDir + " " + @mediaDir )
      end
      deep_copy(ret)
    end

    #***********************************
    # Starts the installation
    # @return nil
    def Write()
        Builtins.y2milestone("-- Start Write ---")
        Builtins.y2milestone("@instMode %1 @productScriptsList %2",@instMode,@productScriptsList )

      if @instMode != "preauto"
        # First we have to create the partitions, maybe HW-dependent
        CreatePartitions()

        @help_text = _(
          "<p>Now external programs like the SAP Software Delivery Tool or others are called to perform the SAP installation(s).</p>"
        )
        @contents2 = nil
        Builtins.y2milestone("********instMasterType: %1", @instMasterType)
        if Builtins.contains(["HANA", "B1AH", "B1A", "B1H"], @instMasterType)
          @contents2 = VBox(
            VBox(
              RichText( "<br><h2>SAP software installation now begins.</h2></br>"),
              LogView(Id(:log), "&Installation log", 20, 0)
            )
          )
        else
          @contents2 = VBox(
            HBox(
              RichText( "<br><h2>SAP software installation now begins.</h2></br>")
            )
          )
        end
        Wizard.SetContents(
          _("SAP Installation Wizard - Finish installation"),
          @contents2,
          @help_text,
          false,
          true
        )

        @productScriptsList.each { |installScript|
          if Builtins.contains(["HANA", "B1AH", "B1A", "B1H"], @instMasterType)
            set_date
            logfile = "/var/adm/autoinstall/logs/sap_inst." + @date + ".log"
            # read installation log file, remove rotating cursor and < > tags
            tailcmd = "tail -50 " + logfile + " | sed -e 's/[<>]//g' | sed -e 's/"
            grepcmd = "grep completed " + logfile + " | awk '{ print $3 }' | tail -1 | sed s/%//g"

            # with HANA unified installer, no sapinst GUI pops up, so we show the progress by displaying the install log
            pid = Convert.to_integer(
              SCR.Execute(path(".process.start_shell"), installScript)
            )
            if pid == nil || Ops.less_or_equal(pid, 0)
              Builtins.y2error("Cannot run '%1' -> %2", installScript, pid)
              next false
            end
            Builtins.y2milestone("running %1 with pid %2", installScript, pid)
            while SCR.Read(path(".process.running"), pid) == true
              out = Convert.to_map(
                SCR.Execute(path(".target.bash_output"), tailcmd)
              )
              UI.ChangeWidget(
                Id(:log),
                :LastLine,
                Ops.get_string(out, "stdout", "")
              )
              out = Convert.to_map(
                SCR.Execute(path(".target.bash_output"), grepcmd)
              )
              Builtins.sleep(1000) # ms
            end
            SCR.Execute(path(".process.release"), pid)
          else
            # sapinst, no HANA unified installer
            SCR.Execute(path(".target.bash"), installScript)
          end
        }
        # Remove all global ask files
        SCR.Execute(path(".target.bash"), "rm /tmp/may_*")

      end
      WFM.Execute(path(".local.umount"), @mountPoint) # old mounts

      :next
    end


    #***********************************
    # Umount sources.
    #  @param boolean doit
    def UmountSources(doit)
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
    # Get directory name
    #  @param string path
    #  @return  string dirname
    def DirName(filePath)
      pathComponents = Builtins.splitstring(filePath, "/")
      last = Ops.get_string(
        pathComponents,
        Ops.subtract(Builtins.size(pathComponents), 1),
        ""
      )
      ret = Builtins.substring(
        filePath,
        0,
        Ops.subtract(Builtins.size(filePath), Builtins.size(last))
      )
      ret
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
          DirName(file)
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
      Builtins.y2milestone("localCheck:%1", localCheck)

      if localCheck
        localPath = check_local_path(subDir, sourceDir)
        if localPath != ""
          # We have something to use
          sourceDir = localPath
        end
      end

      # do not copy creat only a link
      if @createLinks
        cmd = Builtins.sformat(
          "ln -s '%1' '%2'", sourceDir, targetDir + "/" + subDir
        )
        SCR.Execute(path(".target.bash"), cmd)
        @mediaList << sourceDir
        return nil
      end

      # Add the target to the mediaList
      @mediaList << targetDir + "/" + subDir

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
      Builtins.y2milestone("running %1 with pid %2", cmd, pid)


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
        Builtins.y2milestone("Target Tech-Size progress %1", out)

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
        Builtins.y2milestone("Target Human-Size progress %1", out)

        Progress.Title(
          "Copying Media " + subDir + " ( " + Ops.get_string(out, "stdout", "OM") + " of " + humansize + " )"
        )

        # Checking the exit code (0 = OK, nil = still running, 'else' = error)
        exitcode = Convert.to_integer(SCR.Read(path(".process.status"), pid))
        Builtins.y2milestone("Exitcode: %1", exitcode)

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
              "Copy has faild",
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
      end
      # release the process from the agent
      SCR.Execute(path(".process.release"), pid)
      Progress.Finish

      nil
    end

    # ***********************************
    # read a value from the product list
    #
    def GetProductParameter(productParameter)
      @productList.each { |p|
          if p["id"] == @PRODUCT_ID
             return p.has_key?(productParameter) ? p[productParameter] : ""
          end
      }
      return "" 
    end

    def CreatePartitions
      Builtins.y2milestone("********Starting partitioning")

      ret = nil
      hwinfo = get_hw_info
      manufacturer = Ops.get(hwinfo, 0, "") # "FUJITSU", "IBM", "HP", "Dell Inc."
      model = Ops.get(hwinfo, 1, "") # "PowerEdge R620", "PowerEdge R910"

      Builtins.foreach(@productPartitioningList) do |productPartitioning|
        # For HANA we have hardware-dependent partitioning and if we don't know the manufacturer
        # show warnings
        partXML=@partXMLPath + '/' + productPartitioning + ".xml"
        if productPartitioning == Convert.to_string(SAPMedia.ConfigValue("HANA", "partitioning"))
          if !Builtins.contains(
              [
                "FUJITSU",
                "IBM",
                "HP",
                "Dell Inc.",
                "Huawei Technologies Co., Ltd."
              ],
              manufacturer
            )
            warningText = "Found Machine Manufacturer " + manufacturer + ".\n" +
                          "This manufacturer is not supported for SAP HANA with Business One!\n" +
                          "For supported models check https://service.sap.com/pam.\n" +
                          "No proper storage partitioning scheme can be determined.\n" +
                          "SAP HANA will be installed into root file system.";
            Popup.LongWarning(warningText)
            ret = false
            next deep_copy(ret)
          end
          if manufacturer != "Dell Inc."
            partXML = @partXMLPath + '/' + productPartitioning + "_" + manufacturer + "_generic.xml"
          else
            # for Dell servers
            partXML = @partXMLPath + '/' + productPartitioning + "_" + manufacturer + "_" + model + ".xml"
            if !FileUtils.Exists(partXML)
              warningText = "Found machine model " + model + ".\n" +
                            "This model is not supported for SAP HANA with Business One!\n" +
                            "For supported models check https://service.sap.com/pam.\n" +
                            "No proper storage partitioning scheme can be determined.\n" +
                            "SAP HANA will be installed into root file system."
              Popup.LongWarning(warningText)
              ret = false
              next deep_copy(ret)
            end
          end
        end
        ret = WFM.CallFunction( "sap_create_storage", [ partXML ])
      end
      Builtins.y2milestone("MANUFACTURER: %1", manufacturer)
      Builtins.y2milestone("Modell: %1", model)
      deep_copy(ret)
    end

    def ShowPartitions(info)
      ret = nil
      partitionTable = Table()
      partitionTable = Builtins.add(
        partitionTable,
        Header("device", "mountpoint", "fs type", "size")
      )
      items = []
      i = 0
      devmap = Storage.GetTargetMap
      Builtins.foreach(devmap) do |devkey, devvalue|
        if Ops.get_string(devvalue, "name", "") != "tmpfs" &&
            Ops.get_string(devvalue, "device", "") != "tmpfs"
          i = Ops.add(i, 1)
          items = Builtins.add(
            items,
            Item(
              Id(i),
              Ops.get_string(devvalue, "device", ""),
              "",
              "",
              Ops.add(
                Builtins.tostring(
                  Ops.divide(
                    Ops.divide(
                      Builtins.tofloat(Ops.get_integer(devvalue, "size_k", 0)),
                      Convert.convert(1024, :from => "integer", :to => "float")
                    ),
                    Convert.convert(1024, :from => "integer", :to => "float")
                  ),
                  0
                ),
                " G"
              )
            )
          )
        end
        partitions = Ops.get_list(devmap, [devkey, "partitions"], [])
        Builtins.maplist(partitions) do |partition|
          if Ops.get_string(partition, "name", "") != "tmpfs" &&
              Ops.get_string(partition, "device", "") != "tmpfs"
            i = Ops.add(i, 1)
            items = Builtins.add(
              items,
              Item(
                Id(i),
                Ops.get_string(partition, "device", ""),
                Ops.get_string(partition, "mount", ""),
                Builtins.substring(
                  Builtins.tostring(Ops.get(partition, "detected_fs")),
                  1
                ),
                Ops.add(
                  Builtins.tostring(
                    Ops.divide(
                      Ops.divide(
                        Builtins.tofloat(
                          Ops.get_integer(partition, "size_k", 0)
                        ),
                        Convert.convert(
                          1024,
                          :from => "integer",
                          :to   => "float"
                        )
                      ),
                      Convert.convert(1024, :from => "integer", :to => "float")
                    ),
                    0
                  ),
                  " G"
                )
              )
            )
          end
        end
      end
      partitionTable = Builtins.add(partitionTable, items)
      UI.OpenDialog(
        VBox(
          Heading(info),
          MinSize(60, Ops.add(i, 2), partitionTable),
          PushButton("&OK")
        )
      )
      ret = UI.UserInput
      UI.CloseDialog
      deep_copy(ret)
    end

    def CreateHANAPartitions(void)
        @productPartitioningList = ["hana_partitioning"]
	CreatePartitions()
	ShowPartitions("SAP file system creation successfully done:")
    end

    # ***********************************
    # Finish our installation and run scripts
    # TODO Must be cleaned why we do need it
    #
    def WriteProductDatas(productData)
      Builtins.y2milestone("-- WriteProductDatas --")
      Builtins.y2milestone("@mediaList %1 ",@mediaList)
      productData = deep_copy(productData)

      set_date
      params = Builtins.sformat(
        " -m \"%1\" -i \"%2\" -t \"%3\" -y \"%4\" -d \"%5\"  >> /var/adm/autoinstall/logs/sap_inst.%6.log 2>/var/adm/autoinstall/logs/sap_inst.%6.err",
        Ops.get_string(productData, "instMaster", ""),
        Ops.get_string(productData, "PRODUCT_ID", ""),
        Ops.get_string(productData, "DB", ""),
        Ops.get_string(productData, "TYPE", ""),
        Ops.get_string(productData, "instDir", ""),
        @date
      )

      # Add script
      @productScriptsList << "/bin/sh -x " + Ops.get_string(productData, "SCRIPT_NAME", "") + params

      # Add product partitioning
      ret = Ops.get_string(productData, "PARTITIONING", "")
      if ret == nil
        # Default is base_partitioning
        ret = "base_partitioning"
      end
      @productPartitioningList << ret if ret != "NO"

      if !File.exists?( @instDir + "/product.data" )
        SCR.Write( path(".target.ycp"), @instDir + "/product.data", productData )
      end

      Builtins.y2milestone("scripts-list now %1", @productScriptsList)
      Builtins.y2milestone("partitioning-list now %1", @productPartitioningList)

      nil
    end

    #Published functions
    publish :function => :Read,                :type => "boolean ()"
    publish :function => :Write,               :type => "void ()"
    publish :function => :UmountSources,       :type => "void ()"
    publish :function => :MakeTemp,            :type => "string ()"
    publish :function => :DirName,             :type => "string ()"
    publish :function => :ParseXML,            :type => "boolean ()"
    publish :function => :MountSource,         :type => "string ()"
    publish :function => :CopyFiles,           :type => "void ()"
    publish :function => :CreatePartitions,    :type => "void ()"
    publish :function => :ShowPartitions,      :type => "string ()"
    publish :function => :CreateHANAPartitions,:type => "void()"
    publish :function => :GetProductParameter, :type => "string ()"
    publish :function => :WriteProductDatas,   :type => "void ()"
    
    # Published module variables
    publish :variable => :createLinks,       :type => "boolean"
    publish :variable => :mediaList,         :type => "list"
    publish :variable => :productList,       :type => "list"
    publish :variable => :PRODUCT_ID,        :type => "string"
    publish :variable => :PRODUCT_NAME,      :type => "string"
    publish :variable => :DB,                :type => "string"
    publish :variable => :instDir,           :type => "string"
    publish :variable => :instDirBase,       :type => "string"
    publish :variable => :instMasterPath,    :type => "string"
    publish :variable => :instMasterType,    :type => "string"
    publish :variable => :instMasterVersion, :type => "string"
    publish :variable => :instMode,          :type => "string"
    publish :variable => :instType,          :type => "string"
    publish :variable => :mountPoint,        :type => "string"
    publish :variable => :mediaDir,          :type => "string"
    publish :variable => :mediaDirBase,      :type => "string"
    publish :variable => :productXML,        :type => "string"
    publish :variable => :partXMLPath,       :type => "string"
    publish :variable => :ayXMLPath,         :type => "string"
    publish :variable => :prodCount,         :type => "integer"


    private
    #***********************************
    # Read in our configuration file in /etc/sysconfig
    # set some defaults if its not there
    #
    def parse_sysconfig
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

      nil
    end

    def get_hw_info
      hwinfo = []
      product = ""
      product_vendor = ""
      bios = Convert.to_list(SCR.Read(path(".probe.bios")))
    
      if Builtins.size(bios) != 1
        Builtins.y2warning("Warning: BIOS list size is %1", Builtins.size(bios))
      end
    
      biosinfo = Ops.get_map(bios, 0, {})
      smbios = Ops.get_list(biosinfo, "smbios", [])
    
      sysinfo = {}
    
      Builtins.foreach(smbios) do |inf|
        sysinfo = deep_copy(inf) if Ops.get_string(inf, "type", "") == "sysinfo"
      end
    
      if Ops.greater_than(Builtins.size(sysinfo), 0)
        Ops.set(hwinfo, 0, Ops.get_string(sysinfo, "manufacturer", "default"))
        Ops.set(hwinfo, 1, Ops.get_string(sysinfo, "product", "default"))
      end
    
      deep_copy(hwinfo)
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
    
    #***********************************
    # Look if we have the media we need locally available
    #
    # returns string if found or empty string if not
    #
    # if we have same Instmaster, try to copy MEDIA from local Directory
    # check if we have in our local dir's the same label e.g.:RDBMS-DB6
    # if yes the copy from /data/SAP_CDs/x/RDBMS-DB6 instead of /mnt2/SAP_BS2008SR1/RDBMS-DB6
    #       means          $localIMPathList/$key instead of $val
    #
    def check_local_path(label, sourceDir)
      copyPath = ""
      srcLabel = ""
      lclLabel = ""
    
      Builtins.foreach(@localIMPathList) do |_Path|
        if FileUtils.Exists(_Path + "/" + label)
          Builtins.y2milestone("Local directory found: %1/%2", _Path, label)
    
          # Only if the LABEL.ASC are identical
          srcLabel = SAPMedia.read_labelfile( sourceDir + "/" + "/LABEL.ASC")
          next if srcLabel == ""
    
          lclLabel = SAPMedia.read_labelfile( _Path + "/" + label + "/LABEL.ASC")
          next if lclLabel == ""
    
          if srcLabel == lclLabel
            Builtins.y2milestone( "Local directory has same label - we can use it")
            copyPath = _Path + "/" + label
            raise Break
          end
        end
      end
      Builtins.y2milestone("Copy Media from :%1", copyPath)
      copyPath
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

  SAPInst = SAPInstClass.new
  SAPInst.main

end

