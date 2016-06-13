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
Yast.import "Service"
Yast.import "Package"
Yast.import "SAPMedia"

module SAPInstaller
    class TuningWizardDialog
        include Yast::UIShortcuts
        include Yast::I18n
        include Yast::Logger

        TUNING_PROFILES = {
            "throughput-performance" => {
                "desc" => "A generic performance-biased profile, it does not tune for any particular SAP product."
            },
            "sap-netweaver" => {
                "desc" => "Best choice for SAP NetWeaver application and non-HANA database server."
            },
            "sap-hana" => {
                "desc" => "Best choice for SAP HANA and HANA-based products such as BusinessOne."
            }
        }

        def initialize
            textdomain "sap-installation-wizard"
            case Yast::SAPMedia.instMasterType.downcase
            when /hana/
                @recommended_profile = "sap-hana"
            when /b1/
                # Both HANA and BusinessOne use the hana tuning profile
                @recommended_profile = "sap-hana"
            else
                @recommended_profile = "sap-netweaver"
            end
        end

        # Return a ruby symbol that directs Yast Wizard workflow (for example :next, :back, :abort)
        def run
            if Yast::SAPMedia.instMode == "preauto"
                # Skip the dialog if installation is only collecting profiles (i.e. not actually installing SAP software)
                return :next
            end
            # Must have sapconf and tuned installed
            pkg_to_install = []
            if !Yast::Package.Installed("sapconf")
                pkg_to_install += ["sapconf"]
            end
            if !Yast::Package.Installed("tuned")
                pkg_to_install += ["tuned"]
            end
            if pkg_to_install.length > 0
                if !Yast::Package.DoInstall(pkg_to_install)
                    Yast::Popup.Error(_("Failed to install software package \"sapconf\" or \"tuned\".\n" +
                        "The system will not be tuned for optimal performance, however you may still proceed to install SAP software."))
                    return :next # skip the dialog
                end
            end

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
                    if Yast::Popup.ReallyAbort(false)
                        Yast::Wizard.CloseDialog
                        return :abort
                    end
                else
                    # Check whether user has made a choice different from the recommended one
                    choice = Yast::UI.QueryWidget(Id(:profile_name), :Value)
                    if choice != @recommended_profile
                        if !Yast::Popup.YesNo(_("You chose to use profile %s, but for your SAP installation we strongly recommend profile %s.\n" +
                                          "Are you sure to proceed with your choice?") %
                                        [choice, @recommended_profile])
                            redo
                        end
                    end
                    Yast::UI.ReplaceWidget(Id(:busy), Label(Id(:busy_ind), _("Applying, this may take a while...")))
                    # Enable tuned daemon and apply profile
                    Yast::Service.Enable("tuned")
                    if !Yast::Service.Active("tuned")
                        Yast::Service.Start("tuned")
                    end
                    if Yast::SCR.Execute(Yast::Path.new(".target.bash"), "tuned-adm profile " + choice) == 0
                        Yast::Popup.Message(_("Tuning profile has been successfully activated."))
                    else
                        Yast::Popup.Error(_("Failed to activate tuning profile.\n" +
                            "The system is not tuned for optimal performance, however you may still proceed to install SAP software."))
                    end
                    return :next
                end
            end
        end

        private
        def render_all
            Yast::Wizard.SetContents(
                _("Tune your system for optimal performance"),
                HVSquash(Frame("", VBox(
                    Left(Label(_("The tuning profile automatically adjusts your system for optimal performance."))),
                    Left(Label(_("The recommended profile choice has been selected as default."))),
                    VSpacing(2.0),
                    Left(ComboBox(Id(:profile_name), Opt(:notify), "Profile name",
                        TUNING_PROFILES.map { |name, val| Item(name, name == @recommended_profile)})),
                    Label(Id(:profile_desc), TUNING_PROFILES[@recommended_profile]["desc"]),
                    VSpacing(2.0),
                    ReplacePoint(Id(:busy), Empty())
                ))),
                _("Choose a tuning profile that will tune your system for optimal performance.\n" +
                  "System tuning is carried out by software package \"sapconf\".\n" +
                  "If you wish to change tuning profile later on, use \"sapconf\" in combination with \"tuned-adm\" utility.\n" +
                  "Read more about system tuning control in manual page \"man sapconf\", \"man tuned\" and \"man tuned-adm\"."),
                true,
                true
            )
            Yast::Wizard.RestoreAbortButton
        end
    end
end
