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

module Y2Sap
  # Search different kind of SAP medias
  module MediaFind
    include Yast

    def find_sap_media
      make_hash = proc do |hash, key|
        hash[key] = Hash.new(&make_hash)
      end
      @path_map = Hash.new(&make_hash)
      @base     = @source_dir
      sap_lup
      exports
      linux_x86_64
      if @path_map.empty?
        lf = @base + "/LABEL.ASC"
        if File.exist?(lf)
          label = IO.readlines(lf, ":")
          if label.length > 2
            @path_map[base] = label[1].gsub(/\W/, "-") + label[2].gsub(/\W/, "-") + label[3].chop.gsub(/\W/, "-")
          end
        end
      end
      return @path_map
    end

    # Searches the SAPLUP media
    def sap_lup
      command = "find '" + @base + "' -maxdepth 5 -type d -name 'SL_CONTROLLER_*'"
      out     = SCR.Execute(path(".target.bash_output"), command)
      stdout  = out["stdout"] || ""
      stdout.split("\n").each do |d|
        lf = d + "/LABEL.ASC"
        next if !File.exist?(lf)
        label = IO.readlines(lf, ":")
        if label.length > 2
          @path_map[d] = label[1].gsub(/\W/, "-") + label[2].gsub(/\W/, "-")
        end
      end
    end

    # Searches all directories which name starts with EXP"
    def exports
      command = "find '" + @base + "' -maxdepth 5 -type d -name 'EXP?'"
      out     = SCR.Execute(path(".target.bash_output"), command)
      stdout  = out["stdout"] || ""
      stdout.split("\n").each do |d|
        lf = d + "/LABEL.ASC"
        next if !File.exist?(lf)
        label = IO.readlines(lf, ":")
        if label.length > 3
          @path_map[d] = label[4].chop.gsub(/\W/, "-")
        end
      end
    end

    # Searches all directories which names contains LINUX_X86_64"Y
    def linux_x86_64
      command = "find '" + @base + "' -maxdepth 5 -type d -name '*LINUX_X86_64'"
      out     = SCR.Execute(path(".target.bash_output"), command)
      stdout  = out["stdout"] || ""
      stdout.split("\n").each do |d|
        lf = d + "/LABEL.ASC"
        next if !File.exist?(lf)
        label = IO.readlines(lf, ":")
        if label.length > 3
          @path_map[d] = label[2].gsub(/\W/, "-") + label[3].gsub(/\W/, "-") + label[4].chop.gsub(/\W/, "-")
        end
      end
    end

    # @return [List<String>] Delivers a list of already copied media
    def local_media
      media = []
      if File.exist?(@media_dir)
        media = Dir.entries(@media_dir)
        media.delete(".")
        media.delete("..")
      end
      return media
    end
  end
end
