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

require "y2sap/media"

module Y2Sap
  module Dialogs
    module Media
      def copy_dir(sourceDir, targetDir, subDir)
	pid=Y2Sap::Media::Copy.start(sourceDir, targetDir, subDir)
	if pid == nil || pid < 1
	  return ask_me_to_retry(sourceDir, targetDir, subDir)
	end
      	progress = 0
	source_size = Y2Sap::Media::Copy.human_size(sourceDir)
	techsize   = Y2Sap::Media::Copy.tech_size(sourceDir)
        Progress.Simple(
          "Copying Media",
          "Copying SAP " + subDir + " ( 0M of " + source_size + " )",
          techsize,
          ""
        )
        Progress.NextStep
        while SCR.Read(path(".process.running"), pid) == true
	   sleep(1)
	   techsize  = Y2Sap::Media::Copy.tech_size(targetDir + "/" + subDir)
	   Progress.Step(techsize)
	   humansize = Y2Sap::Media::Copy.human_size(targetDir + "/" + subDir)
	   Progress.Title( "Copying Media " + subDir + " ( " + humansize + " of " + source_size + " )")

	   # Checking the exit code (0 = OK, nil = still running, 'else' = error)
           exitcode = Convert.to_integer(SCR.Read(path(".process.status"), pid))
           if exitcode != nil && exitcode != 0
             log.info("Copy has failed, exit code was: #{exitcode} stderr: %2" + SCR.Read(path(".process.read_stderr"), pid))
             error = Builtins.sformat(
               "Copy has failed, exit code was: %1, stderr: %2",
               exitcode,
               SCR.Read(path(".process.read_stderr"), pid)
             )
             Popup.Error(error)
	     return ask_me_to_retry(sourceDir, targetDir, subDir)
           end
        end
        # release the process from the agent
        SCR.Execute(path(".process.release"), pid)
        Progress.Finish
	return :next
      end


      def ask_me_to_retry(sourceDir, targetDir, subDir)
        if Popup.ErrorAnyQuestion(
            "Failed to copy files from medium",
            "Would you like to retry?",
            "Retry",
            "Abort",
            :focus_yes
          )
          copy_dir(sourceDir, targetDir, subDir)
        else
          UI.CloseDialog
          return :abort
        end
      end

      def parse_xml(file)
         ret =  WFM.CallFunction("ayast_setup", ["setup","filename="+file, "dopackages=yes" ] )
	 log.info("ayast_setup returned '" + ret + "' for: " + file)
	 return ret
      end
    end
  end
end
