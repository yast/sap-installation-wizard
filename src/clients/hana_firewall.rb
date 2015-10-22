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
# Summary: Run HANA firewall configuration wizard dialog stand-alone.
# Authors: Howard Guo <hguo@suse.com>

require "yast"
require "sap/config_hanafw_dialog"

# Create a wizard environment for the wizard dialog to run
Yast::Wizard.CreateDialog
SAPInstaller::ConfigHANAFirewallDialog.new(false).run
Yast::Wizard.CloseDialog