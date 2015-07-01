# encoding: utf-8

module Yast
  class InstSapWrapperClient < Client
    def main
      Yast.import "UI"
      Yast.import "Wizard"
      textdomain "autoinst"
      go
      UI.CloseDialog

      nil
    end

    def go
      Wizard.CreateDialog
      WFM.CallFunction("inst_sap", [true, true])

      nil
    end
  end
end

Yast::InstSapWrapperClient.new.main
