# encoding: utf-8
# Authors: Peter Varkoly <varkoly@suse.com>

# ex: set tabstop=4 expandtab:
# vim: set tabstop=4: set expandtab
require "yast"
require "fileutils"

module Yast
  class SAPProductClass < Module
    def main
      Yast.import "URL"
      Yast.import "UI"
      Yast.import "XML"
      Yast.import "SAPXML"
      Yast.import "SAPMedia"

      textdomain "sap-media"
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("SAP Product Installer Started")
    end
  end
  SAPProduct = SAPProductClass.new
  SAPProduct.main
end
   
