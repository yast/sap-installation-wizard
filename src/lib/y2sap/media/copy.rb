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
  module MediaCopy
    include Yast
    def start_copy(source, target, subdir)
      log.info("CopyFiles called: #{source}, #{target}, #{subdir}")
      cmd = "mkdir -p '%s/%s'" % [ target , subdir ]
      SCR.Execute(path(".target.bash"), cmd)

      # our copy command
      cmd = "find '%1/'* -maxdepth 0 -exec cp -a '{}' '%2/%3/' \\;" % [ source, target + "/" + subdir ]
      pid = Convert.to_integer(SCR.Execute(path(".process.start_shell"), cmd))
      return pid
    end

    def tech_size(dir)
      out = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "du -s0 '%s' | awk '{printf $1}'" %  dir )
      )
      Builtins.tointeger(Ops.get_string(out, "stdout", "0"))
    end

    def human_size(dir)
      out = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "du -sh0 '%s' | awk '{printf $1}'" %  dir )
      )
      Builtins.tointeger(Ops.get_string(out, "stdout", "0"))
    end
  end
end
