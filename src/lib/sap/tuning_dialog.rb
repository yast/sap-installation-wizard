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
# Summary: In the wizard workflow, display a dialog to let user choose a system tuning profile.
# Authors: Howard Guo <hguo@suse.com>

require "yast"
Yast.import "UI"
Yast.import "Label"
Yast.import "Popup"

module SAPInstaller
    class TuningWizardDialog
        include Yast::UIShortcuts
        include Yast::I18n
        include Yast::Logger
        
        TUNING_PROFILES = {
            "throughput-performance" => {
                "desc" => "A generic performance-biased profile, it does not tune any particular SAP product."
            },
            "sap-netweaver" => {
                "desc" => "Best choice for SAP NetWeaver application and non-HANA database server."
            },
            "sap-haha" => {
                "desc" => "Best choice for SAP HANA database server."
            }
        }
        
        def initialize
            textdomain "sap-installation-wizard"
            @recommended_profile = "throughput-performance"
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
                when :profile_name
                    # Display profile description text when user choice changes
                    choice = Yast::UI.QueryWidget(Id(:profile_name), :Value)
                    Yast::UI.ChangeWidget(Id(:profile_desc), :Value, TUNING_PROFILES[choice]["desc"])
                    Yast::UI.RecalcLayout
                when :back
                    return :back
                when :abort, :cancel
                    return :abort
                else
                    choice = Yast::UI.QueryWidget(Id(:profile_name), :Value)
                    if choice != @recommended_profile
                        if !Yast::Popup.YesNo(_("You chose to use profile %s, but for your SAP installation we strongly recommend profile %s.\n" +
                                          "Are you sure to proceed with your choice?") %
                                        [choice, @recommended_profile])
                            redo
                        end
                    end
                    if Yast::SCR.Execute(Yast::Path.new(".target.bash"), "tuned-adm profile " + choice) == 0
                        Yast::Popup.Message(_("Tuning profile has been successfully activated."))
                    else
                        Yast::Popup.Message(_("Non-fatal error: failed to activate tuning profile.\n" +
                                              "However you may still proceed to install SAP software."))
                    end
                    return :next
                end
            end
        end
        
        private
        def render_all
            Yast::Wizard.SetContents(
                _("Tune your system for best performance"),
                VBox(
                    Label(_("The tuning profile will automatically adjust your system for best performance.")),
                    Label(_("The recommended profile choice has been selected as default.")),
                    Frame("",VBox(
                        ComboBox(Id(:profile_name), Opt(:notify), "Profile name",
                            TUNING_PROFILES.map { |name, val| Item(name, name == @recommended_profile)}),
                        Label(Id(:profile_desc), TUNING_PROFILES[@recommended_profile]["desc"])
                    ))
                ),
                _("Choose a tuning profile that will tune your system for best performance.\n" +
                  "System tuning is carried out by software package \"tuned\".\n" +
                  "If you wish to change tuning profile later on, use \"tuned-adm\" utility.\n" +
                  "Read more about system tuning control in manual page \"man tuned\" and \"man tuned-adm\"."),
                true,
                true
            )
            Yast::Wizard.RestoreAbortButton
        end
    end
end