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
  subject(:sapproduct) do
   described_class.new(media)
  end
  let(:media) do
     instance_double(Y2Sap::Media)
  end
  before do
    allow(Y2Sap::Media).to receive(:new).and_return(media)
    allow(Y2Sap::Media).to receive(:mount_point).and_return("/mnt")
  end

  describe "no sysconfig file exist" do
    it "check the initalisation of global variables" do
      expect(sapproduct.products_to_install()).to be_a(Array)
      expect(sapproduct.product_map()).to be_a(Hash)
      #expect(sapproduct.media()).to be_a(Class)
    end
    #it "reads the default base configuration" do
    #  expect(sapproduct.media.mount_point()).to eq "/mnt"
    #  expect(sapproduct.media.inst_mode()).to   eq "manual"
    #  expect(sapproduct.media.inst_dir()).to    eq "/data/SAP_INST/0"
    #  expect(sapproduct.media.unfinished_installations()).to be_a(Array)
    end
  end
end

