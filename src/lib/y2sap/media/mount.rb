# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may
# find current contact information at www.novell.com.
require "shellwords"
module Y2Sap
  # Module containing to mount the source medias
  module MediaMount
    include Yast
    Yast.import "URL"

    def mount_source(scheme, location)
      log.info("MountSource called #{scheme}, #{location}")
      @location_cache = location
      WFM.Execute(path(".local.umount"), @mount_point) # old (dead) mounts
      case scheme
      when "device"
        mount_device(location)
      when "nfs"
        mount_nfs(location)
      when "smb"
        mount_smb(location)
      when "local"
        @source_dir = location
        mount_local(location)
      when "cdrom"
        mount_device("cdrom/" + location)
      when /^cdrom::(?<dev>.*)/
        mount_device(dev + "/" + location)
      else
        return "ERROR unknown media scheme"
      end
    end

    # Mounts the sap media server configured in SAP_CDS_URL
    def mount_sap_cds
      return if @sap_cds_url == ""
      # Un-mount it, in case if the location was previously mounted
      # Run twice to umount it forcibly and surely
      SCR.Execute(path(".target.bash_output"), "/usr/bin/umount -lfr " + @media_dir)
      SCR.Execute(path(".target.bash_output"), "/usr/bin/umount -lfr " + @media_dir)
      # Make sure the mount point exists
      SCR.Execute(path(".target.bash_output"), "/usr/bin/mkdir -p " + @media_dir)
      # Mount new network location
      url     = URL.Parse(@sap_cds_url)
      command = ""
      case url["scheme"]
      when "nfs"
        command = "mount -o nolock " + url["host"] + ":" + url["path"].shellescape + " " + @media_dir
      when "smb"
        mopts = "-o ro"
        mopts += if url["workgroup"] != ""
          ",username=" + url["workgroup"] + "/" + url["user"] + ",password=" + url["pass"].shellescape
        elsif url["user"] != ""
          ",username=" + url["user"] + ",password=" + url["pass"].shellescape
        else
          ",guest"
        end
        mopts += ",dir_mode=0777,file_mode=0777"
        if url["host"] =~ /windows.net$/
          mopts += ",sec=ntlmssp,vers=3.0"
        end
        command = "/sbin/mount.cifs //" + url["host"] + url["path"].shellescape + " " + @media_dir + " " + mopts
      end
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))
      return Ops.get_string(out, "stderr", "") == ""
    end

    def umount_sap_cds
      # Un-mount it, in case if the location was previously mounted
      # Run twice to umount it forcibly and surely
      SCR.Execute(path(".target.bash_output"), "/usr/bin/umount -lfr " + @media_dir)
      SCR.Execute(path(".target.bash_output"), "/usr/bin/umount -lfr " + @media_dir)
    end

    def mount_device(location)
      url = URL.Parse("device://" + location)
      log.info("parsed URL: #{url}")
      url["host"] = "/dev/" + url["host"]
      if !Convert.to_boolean(
        SCR.Execute(
          path(".target.mount"),
          [url["host"], @mount_point],
          "-o shortname=mixed"
        )
      ) &&
          !Convert.to_boolean(
            SCR.Execute(
              path(".local.mount"),
              [url["host"], @mount_point]
            )
          )
        return "ERROR:Can not mount required device."
      end
      @need_umount = true
      @source_dir  = @mount_point + "/" + url["path"].shellescape
      log.info("MountSource url #{url}")
    end

    def mount_nfs(location)
      url = URL.Parse("nfs://" + location)
      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          "mount -o nolock " + url["host"] + ":" + url["path"].shellescape + " '" + @mount_point + "'"
        )
      )
      log.info("MountSource url #{url}")
      if Ops.get_string(out, "stderr", "") != ""
        return "ERROR:" + Ops.get_string(out, "stderr", "")
      end
      @source_dir = @mount_point
      return ""
    end

    def mount_smb(location)
      at = location.rindex("@")
      if !at.nil?
        userinfo = location[0, at].split(":", 2)
        location = URL.EscapeString(userinfo[0], URL.transform_map_passwd) +
          ":" + URL.EscapeString(userinfo[1], URL.transform_map_passwd) +
          "@" + location[at + 1..-1]
      end
      url = URL.Parse("smb://" + location)
      mpath = url["path"].shellescape
      mopts = "-o ro"
      mopts += if url.key?("workgroup") && url["workgroup"] != ""
        ",user=" + url["workgroup"] + "/" + url["user"] + ",password=" + url["pass"].shellescape
      elsif url.key?("user") && url["user"] != ""
        ",user=" + url["user"] + ",password=" + url["pass"].shellescape
      else
        ",guest"
      end

      log.info("smbMount: /sbin/mount.cifs //" + url["host"] + mpath + "' '" + @mount_point + "' " + mopts)
      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          "/sbin/mount.cifs '//" + url["host"] + mpath + "' '" + @mount_point + "' " + mopts
        )
      )
      log.info("MountSource url #{url}")
      if Ops.get_string(out, "stderr", "") != ""
        return "ERROR:" + Ops.get_string(out, "stderr", "")
      end
      @source_dir = @mount_point
      return ""
    end

    def mount_local(location)
      if SCR.Read(path(".target.lstat"), location) == {}
        return "ERROR: Can not find local path:" + location
      end
      return ""
    end

    def umount_source
      WFM.Execute(path(".local.umount"), @mount_point)
    end
  end
end
