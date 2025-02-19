local textInput = require("%darg/components/textInput.nut")
local colors = require("reactiveGui/style/colors.nut")
local focusBorder = require("reactiveGui/components/focusBorder.nut")


local hudFrame = @(inputObj, group, sf) {
  rendObj = ROBJ_BOX
  size = [flex(), ::fpx(30) + 2 * (::dp() + ::fpx(3))]
  fillColor = colors.menu.textInputBgColor
  borderColor = colors.menu.textInputBorderColor
  borderWidth = [::dp()]

  group = group
  children = [ inputObj,
    (sf & S_KB_FOCUS) != 0 ? focusBorder() : null
  ]
}


local export = class {
  hud = @(text_state, options={}) textInput(text_state, options, hudFrame)
  _call = @(self, text_state, options={}) textInput(text_state, options)
}()


return export