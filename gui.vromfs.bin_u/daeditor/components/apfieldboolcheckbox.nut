from "%darg/ui_imports.nut" import *
from "ecs" import *

local {ControlBg, Interactive, Hover} = require("style.nut").colors
local {setValToObj, getValFromObj} = require("attrUtil.nut")
local entity_editor = require("entity_editor")

local getVal = @(eid, comp_name, path) path==null ? obsolete_dbg_get_comp_val(eid, comp_name) : getValFromObj(eid, comp_name, path)
local function fieldBoolCheckbox(params = {}) {
  local {eid, comp_name, path} = params
  local curVal = getVal(eid, comp_name, path)
  curVal = Watched(curVal)

  local group = ElemGroup()
  local stateFlags = Watched(0)
  local function onClick() {
    local val = !getVal(eid, comp_name, path)
    if (path!=null)
      setValToObj(eid, comp_name, path, val)
    else
      obsolete_dbg_set_comp_val(eid, comp_name, val)
    entity_editor.save_component(eid, comp_name)
    curVal.update(val)
    params?.onChange?()
  }


  return function () {
    local mark = null
    if (curVal.value) {
      mark = {
        rendObj = ROBJ_SOLID
        color = (stateFlags.value & S_HOVER) ? Hover : Interactive
        group
        size = [pw(50), ph(50)]
        hplace = ALIGN_CENTER
        vplace = ALIGN_CENTER
      }
    }

    return {
      key = comp_name
      size = [fontH(80), fontH(80)]
      rendObj = ROBJ_SOLID
      color = ControlBg

      behavior = Behaviors.Button
      group

      watch = [curVal, stateFlags]

      children = mark

      onElemState = @(sf) stateFlags.update(sf)

      onClick
    }
  }
}

return fieldBoolCheckbox
