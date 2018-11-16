#!/usr/bin/env rspec
# encoding: utf-8
#
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
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "../spec_helper"

require "y2sap/configuration/base_config"
require "yast"
Yast.import "Misc"

describe Y2Sap::Configuration::BaseConfig do
  subject { described_class.new }
  context "no sysconfig file exist" do
    it "reads the default base configuration" do
      expect(subject.mount_point()).to eq "/mnt"
      expect(subject.inst_mode()).to   eq "manual"
    end
  end
  context "sysconfig file exist" do
    before do
      change_scr_root(File.join(DATA_PATH, "system"))
      subject { described_class.new }
    end
    it "reads the base configuration from sysconfig file" do
      expect(subject.mount_point()).to eq "/tmp/mnt"
      expect(subject.inst_mode()).to   eq "auto"
    end
  end
end

