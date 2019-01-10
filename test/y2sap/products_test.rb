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

  let(:media) { Y2Sap::Media.new }

  subject(:sapproduct) do
    described_class.new(media)
  end

  describe "no sysconfig file exist" do
    it "check the initalization of global variables" do
      expect(sapproduct.products_to_install).to be_a(Array)
      expect(sapproduct.product_map).to be_a(Hash)
      expect(sapproduct.PRODUCT_NAME).to eq ""
    end
    it "reads the default base configuration" do
      expect(sapproduct.media.mount_point).to eq "/mnt"
      expect(sapproduct.media.inst_mode).to   eq "manual"
      expect(sapproduct.media.inst_dir).to    eq "/data/SAP_INST/0"
      expect(sapproduct.media.unfinished_installations).to be_a(Array)
    end
    it "initialize the a HANA product enviroment" do
      sapproduct.media.inst_master_type = "HANA"
      sapproduct.init_envinroment
      expect(sapproduct.PRODUCT_NAME).to eq "HANA"
    end
  end
end
