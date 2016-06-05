# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2015 SUSE LINUX GmbH, Nuernberg, Germany.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE Linux GmbH.
#
# ------------------------------------------------------------------------------

# File: clients/sap-inst_auto.ycp
# Module:       Configuration of authentication client
# Summary:      Client file, including commandline handlers
# Authors:      Peter Varkoly <varkoly@suse.com>
#               Christian Kornacker <ckornacker@suse.com>
#
# This is a client for autoinstallation. It takes its arguments,
# goes through the configuration and return the setting.
# Does not do any changes to the configuration.

# @param first a map of authentication settings
# @return [Hash] edited settings or an empty map if canceled
# @example map mm = $[ "FAIL_DELAY" : "77" ];
# @example map ret = WFM::CallModule ("sap-inst_auto", [ mm ]);

module Yast
  class SAPInstAuto < Client
    def main
      textdomain "sap-media"
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("sap-inst auto started")
      Yast.import "SAPMedia"
      Yast.import "SAPProduct"
      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end
      #TODO make y2debug if it works correctly
      Builtins.y2milestone("func=%1",  @func)
      Builtins.y2milestone("param=%1", @param)
      case @func
        when "Import"
          @ret = SAPMedia.Import(@param)
        when "Summary"
          @ret = SAPMedia.Summary()
        when "Reset"
          SAPMedia.Import({})
          SAPMedia.SetModified(false)
          @ret = {}
        when "Change"
          SAPMedia.SetModified(true)
        when "Export"
          @ret = SAPMedia.Export
        when "Read"
          SAPMedia.Read
          @ret = SAPMedia.Export
        when "GetModified"
          @ret = SAPMedia.GetModified
        when "SetModified"
          SAPMedia.SetModified(true)
          @ret = true
        when "Write"
          SAPMedia.Write
        when "Packages"
          @ret = { "install" => ["" ], "remove" => [] }
        else
          Builtins.y2error("Unknown function: %1", @func)
          @ret = false
      end
      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("SAPInst auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret)
    end
  end
end

Yast::SAPMediaAuto.new.main
