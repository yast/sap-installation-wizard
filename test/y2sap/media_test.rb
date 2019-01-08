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
require "yast"

describe Y2Sap::Media do
  context "no sysconfig file exist" do
    before do
      subject { described_class.new }
    end
    it "reads the default base configuration" do
      expect(subject.mount_point).to eq "/mnt"
      expect(subject.inst_mode).to   eq "manual"
      expect(subject.inst_dir).to    eq "/data/SAP_INST/0"
      expect(subject.unfinished_installations).to be_a(Array)
    end
    it "check for not supported scheme" do
      expect(subject.mount_source("cifs", "/bla/fasel")).to eq "ERROR unknown media scheme"
    end
    it "check searching the sap content on a media" do
      expect(subject.find_sap_media).to be_a(Hash)
    end
  end
  context "sysconfig file does exist" do
    before do
      change_scr_root(File.join(DATA_PATH, "system"))
      subject { described_class.new }
    end
    it "reads the base configuration from sysconfig file" do
      expect(subject.mount_point).to eq "/tmp/mnt"
      expect(subject.inst_mode).to   eq "auto"
      expect(subject.inst_dir).to    eq "/data/SAP_INST/0"
    end
  end
  context "test the MediaCopy functions" do
    let(:out) { { "exit" => 0, "stdout" => "200" } }

    before do
      allow(Yast::SCR).to receive(:Execute).with(Yast::Path.new(".target.bash_output"), /du/)
        .and_return(out)
      change_scr_root(File.join(DATA_PATH, "system"))
      subject { described_class.new }
    end
    it "reads the tech size of /etc" do
      expect(subject.tech_size("/etc")).to eq(200)
    end

    context "when it is not possible to read the size" do
      let(:out) { { "exit" => 1, "stdout" => "" } }

      it "returns 0" do
        expect(subject.tech_size("/etc")).to eq(0)
      end
    end
  end
end
