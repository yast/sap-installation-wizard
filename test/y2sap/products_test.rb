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

require "y2sap/media"
require "y2sap/products"
require "yast"

describe Y2Sap::Products do

  subject { described_class.new(media) }

  context "no sysconfig file exist" do
    let(:media) { Y2Sap::Media.new }
    before do
      subject.media.product_definitions = DATA_PATH + "/system/etc/sap-installation-wizard.xml"
    end
    it "check the initalization of global variables" do
      expect(subject.products_to_install).to be_a(Array)
      expect(subject.product_map).to be_a(Hash)
      expect(subject.product_name).to eq ""
      expect(subject.product_list.count).to eq 4
    end
    it "reads the default base configuration" do
      expect(subject.media.mount_point).to eq "/mnt"
      expect(subject.media.inst_mode).to   eq "manual"
      expect(subject.media.inst_dir).to    eq "/data/SAP_INST/0"
      expect(subject.media.unfinished_installations).to be_a(Array)
    end
    it "initialize a HANA product enviroment" do
      subject.media.inst_master_type = "HANA"
      subject.init_envinroment
      expect(subject.product_name).to eq "HANA"
    end
    it "initialize a B1 product enviroment" do
      subject.media.inst_master_type = "B1"
      subject.init_envinroment
      expect(subject.product_name).to eq "B1"
    end
  end
  context "sysconfig file does exist" do
    let(:media) { Y2Sap::Media.new }
    around do |example|
      # change the SCR root to a testing directory
      change_scr_root(File.join(DATA_PATH, "system"))
      subject.media.product_definitions = DATA_PATH + "/system/etc/sap-installation-wizard.xml"
      example.run
      # restore it back
      reset_scr_root
    end
    it "reads the base configuration from sysconfig file" do
      expect(subject.media.mount_point).to eq "/tmp/mnt"
      expect(subject.media.inst_mode).to   eq "auto"
      expect(subject.media.inst_dir).to    eq "/data/SAP_INST/0"
    end
  end

end
