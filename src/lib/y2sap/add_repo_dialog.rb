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

module Yast
  # The class invokes add-reposotiry dialog
  # It must live in Yast namespace because it uses the legacy Yast.include mechanism
  # It must also inherit from Client, or the dialog will not be able to run
  class AddRepoInvokerClass < Client
    include Yast::I18n
    def show
      Yast.include self, "add-on/add-on-workflow.rb"
      MediaSelect()
    end
  end
  AddRepoInvoker = AddRepoInvokerClass.new
end

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
          begin
            begin
                Yast::AddRepoInvoker.show
            rescue
            end
          end while Yast::Popup.YesNo(_("Do you have more software repositories to add?"))
          return :next
        when :back
          return :back
        when :abort, :cancel
          if Yast::Popup.ReallyAbort(false)
            Yast::Wizard.CloseDialog
            return :abort
          end
        else
          return :next
        end
      end
    end
    
    private
    def render_all
      Yast::Wizard.SetContents(
        _("Additional software repositories for your SAP installation"),
        HVSquash(Frame("", VBox(
            Left(Label(_("Do you use additional software repositories, such as 3rd-party SAP add-ons?"))),
            Left(Label(_("Feel free to add them now. Otherwise, click \"Next\" to continue."))),
            PushButton(Id(:add_repo), _("Add new software repositories")),
        ))),
        _("You now have an opportunity to add software repositories, for example: repositores for SAP partner solutions.\n" + 
          "The step is completely optional, simply click \"Next\" if you do not use any additional repositories."),
        true,
        true
      )
      Yast::Wizard.RestoreAbortButton
    end
  end
end

