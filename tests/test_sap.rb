# encoding: utf-8

module Yast
  class TestSapClient < Client
    def main
      Yast.import "SAPMedia"

      # MAIN
      textdomain "sap-installation-wizard"
      SAPMedia.Read()
 
    end
  end
end

Yast::TestSapClient.new.main
