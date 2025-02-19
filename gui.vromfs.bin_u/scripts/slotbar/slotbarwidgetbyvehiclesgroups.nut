local slotbarPresets = require("scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
local selectGroupHandler = require("scripts/slotbar/selectGroupHandler.nut")
local { setShowUnit } = require("scripts/slotbar/playerCurUnit.nut")
local { getShopVisibleCountries } = require("scripts/shop/shopCountriesList.nut")

local handlerClass = class extends ::gui_handlers.SlotbarWidget
{
  unitsGroupsByCountry = null
  countryPresets = null
  emptyText = "#mainmenu/changeUnitsGroup"

  function validateParams()
  {
    base.validateParams()
    validatePresetsParams()
  }

  function validatePresetsParams()
  {
    local curPreset = slotbarPresets.getCurPreset()
    unitsGroupsByCountry = curPreset.groupsList
    countryPresets = curPreset.countryPresets
  }

  function gatherVisibleCrewsConfig(onlyForCountryIdx = null)
  {
    local res = []
    local country = getForcedCountry()
    foreach(idx, coutryCrews in ::g_crews_list.get())
    {
      if (onlyForCountryIdx != null && onlyForCountryIdx != idx)
        continue

      local visibleCountries = getShopVisibleCountries()
      local listCountry = coutryCrews.country
      if ((singleCountry != null && singleCountry != listCountry)
        || visibleCountries.indexof(listCountry) == null)
        continue

      local countryData = {
        country = listCountry
        id = idx
        isEnabled = (!country || country == listCountry)
        crews = []
      }
      res.append(countryData)

      if (!countryData.isEnabled)
        continue

      local crewsList = coutryCrews.crews
      local unitsList = countryPresets?[listCountry]
      local realCrewsCount = crewsList.len()
      local groupsList = unitsGroupsByCountry?[listCountry].groups
      local isVisualDisabled = groupsList == null
      local crewsCount = ::max(realCrewsCount, showNewSlot ? (groupsList?.len() ?? 0) : 0)
      for(local i = 0; i < crewsCount; i++)
      {
        local crew = crewsList?[i] ?? getDefaultCrew(listCountry, idx, i)
        local unit = unitsList?.units[i]
        local status = unit == null ? bit_unit_status.empty
          : isVisualDisabled || (unit != null && !(unit.name in availableUnits)) ? bit_unit_status.disabled
          : bit_unit_status.owned

        addCrewData(countryData.crews, {
          crew = crew,
          unit = unit,
          status = status,
          isSelectable = unit != null || groupsList == null
          isVisualDisabled = isVisualDisabled
          isLocalState = false
        })
      }
    }
    return res
  }

  function applySlotSelection(obj, selSlot)
  {
    curSlotCountryId = selSlot.countryId
    curSlotIdInCountry = selSlot.crewIdInCountry

    if (slotbarOninit)
    {
      if (afterSlotbarSelect)
        afterSlotbarSelect()
      return
    }

    local crewList = ::g_crews_list.get()?[curSlotCountryId]
    local country = crewList?.country ?? ""
    local crew = crewList?.crews[curSlotIdInCountry]
      ?? getDefaultCrew(country, curSlotCountryId, curSlotIdInCountry)
    local groupsList = unitsGroupsByCountry?[country].groups
    local unit = getCrewUnit(crew)
    if (unit || groupsList == null)
      setCrewUnit(unit)
    else if (needActionsWithEmptyCrews)
      onSlotChangeGroup()

    if (hasActions)
    {
      local slotItem = ::get_slot_obj(obj, curSlotCountryId, curSlotIdInCountry)
      openUnitActionsList(slotItem)
    }

    if (afterSlotbarSelect)
      afterSlotbarSelect()
  }

  getDefaultCrew = @(country, idCountry, idInCountry) {
    country = country
    idCountry = idCountry
    idInCountry = idInCountry
    id = -1
  }

  function getCurSlotUnit()
  {
    return countryPresets?[getCurCountry()].units[curSlotIdInCountry]
  }

  function getCrewUnit(crew)
  {
    return countryPresets?[crew.country].units[crew.idInCountry]
  }

  function getHangarFallbackUnitParams()
  {
    return {
      country = getCurCountry()
      slotbarUnits = (countryPresets?[getCurCountry()].units ?? [])
        .filter(@(unit) unit != null)
    }
  }

  function onEventPresetsByGroupsChanged(p)
  {
    local newCrew = p?.crew
    local newUnit = p?.unit
    if (newCrew != null && newUnit != null)
    {
      ::select_crew(newCrew.idCountry, newCrew.idInCountry)
      setShowUnit(newUnit)
    }
    validatePresetsParams()
    fullUpdate()
  }

  function getCurCrew()
  {
    return slotbarPresets.getSlotItem(curSlotCountryId, curSlotIdInCountry)
  }

  getParamsForActionsList = @() { hasSlotbarByUnitsGroups = true }
  function onSlotChangeGroup()
  {
    local crew = getCurCrew()
    if (!crew)
      return

    local slotbar = this
    ignoreCheckSlotbar = true
    checkedCrewAirChange(function() {
        ignoreCheckSlotbar = false
        selectGroupHandler.open(crew, slotbar)
      },
      function() {
        ignoreCheckSlotbar = false
        checkSlotbar()
      }
    )
  }

  getCrewDataParams = @(crewData) {
    bottomLineText = ::loc(
      slotbarPresets.getVehiclesGroupByUnit(
        crewData.unit, unitsGroupsByCountry?[crewData?.crew.country ?? ""])?.name ?? "")
  }

  getDefaultDblClickFunc = @() @(crew) null
}

::gui_handlers.slotbarWidgetByVehiclesGroups <- handlerClass

local function create(params)
{
  local nest = params?.scene
  if (!::check_obj(nest))
    return null

  if (params?.shouldAppendToObject ?? true) //we append to nav-bar by default
  {
    local data = "slotbarDiv { id:t='nav-slotbar' }"
    nest.getScene().appendWithBlk(nest, data)
    params.scene = nest.findObject("nav-slotbar")
  }

  return ::handlersManager.loadHandler(handlerClass, params)
}

return {
  create = create
}