local Event = require("ui/event")
local UIManager = require("ui/uimanager")

---@param AirPlaneMode table
return function(AirPlaneMode)
  --[[
  Extends AirPlaneMode with footer status in reader
  ]]
  --

  ---Refresh status bars footer content
  ---@return nil
  function AirPlaneMode:update_status_bars()
    if self.show_value_in_footer then
      UIManager:broadcastEvent(Event:new("RefreshAdditionalContent"))
    end
  end

  ---Add additional content to reader footer
  ---@return nil
  function AirPlaneMode:addAdditionalFooterContent()
    if self.ui.view then
      self.ui.view.footer:addAdditionalFooterContent(self.additional_footer_content_func)
      self:update_status_bars()
      UIManager:broadcastEvent(Event:new("UpdateFooter", true))
    end
  end

  ---Remove additional footer content
  ---@return nil
  function AirPlaneMode:removeAdditionalFooterContent()
    if self.ui.view then
      self.ui.view.footer:removeAdditionalFooterContent(self.additional_footer_content_func)
      self:update_status_bars()
      UIManager:broadcastEvent(Event:new("UpdateFooter", true))
    end
  end
end
