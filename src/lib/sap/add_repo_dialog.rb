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
#
# Summary: In the wizard workflow, display a dialog to let user add additional zypper repos.
# Authors: Howard Guo <hguo@suse.com>

require "yast"
Yast.import "UI"
Yast.import "Label"
Yast.import "Popup"

module SAPInstaller
    class AddRepoWizardDialog
        include Yast::UIShortcuts
        include Yast::I18n
        include Yast::Logger
        
        def initialize
            textdomain "sap-installation-wizard"
        end
        
        # Return a ruby symbol that directs Yast Wizard workflow (for example :next, :back, :abort)
        def run
            render_all
            return ui_event_loop
        end
        
        # Return a ruby symbol that directs Yast Wizard workflow (for example :next, :back, :abort)
        def ui_event_loop
            loop do
                case Yast::UI.UserInput
                when :add_repo
                    Yast::SCR.Execute(Yast::Path.new(".target.bash"), "/usr/sbin/yast2 repositories")
                    return :next
                when :back
                    return :back
                when :abort, :cancel
                    return :abort
                else
                    return :next
                end
            end
        end
        
        private
        def render_all
            Yast::Wizard.SetContents(
                _("Add additional software repositories for your SAP installation"),
                VBox(
                     Label(_("Do you have additional software repositores to add at this stage?\n" + 
                             "If so, please click to button to add software repositories.")),
                     PushButton(Id(:add_repo), _("Manage additional software repositories")),
                     Label(_("Otherwise, click \"Next\" to continue."))
                ),
                _("You now have an opportunity to manage software repositories, for example: adding repository for SAP partner solutions.\n" + 
                  "The step is completely optional, simply click \"Next\" if you do not use any additional repositories."),
                true,
                true
            )
            Yast::Wizard.RestoreAbortButton
        end
    end
end