local mapPreferencesModal = require("scripts/missions/mapPreferencesModal.nut")
local mapPreferencesParams = require("scripts/missions/mapPreferencesParams.nut")
local clustersModule = require("scripts/clusterSelect.nut")
local crossplayModule = require("scripts/social/crossplay.nut")
local u = require("sqStdLibs/helpers/u.nut")
local Callback = require("sqStdLibs/helpers/callback.nut").Callback
local unitTypes = require("scripts/unit/unitTypesList.nut")
local {
  checkAndShowMultiplayerPrivilegeWarning,
  isMultiplayerPrivilegeAvailable } = require("scripts/user/xboxFeatures.nut")
local { needUseHangarDof } = require("scripts/viewUtils/hangarDof.nut")

::dagui_propid.add_name_id("modeId")

class ::gui_handlers.GameModeSelect extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneTplName = "gui/gameModeSelect/gameModeSelect"
  shouldBlurSceneBgFn = needUseHangarDof
  needAnimatedSwitchScene = false

  restoreFromModal = false
  newIconWidgetsByGameModeID = {}
  gameModesWithTimer = {}

  filledGameModes = []

  categories = [
    {
      id = "general_game_modes"
      separator = false
      modesGenFunc = "createGameModesView"
      textWhenEmpty = "#mainmenu/gamemodesNotLoaded/desc"
    }
    {
      id = "featured_game_modes"
      separator = true
      modesGenFunc = "createFeaturedModesView"
    }
    {
      id = "debug_game_modes"
      separator = false
      modesGenFunc = "createDebugGameModesView"
    }
  ]

  static basePanelConfig = [
    ::ES_UNIT_TYPE_AIRCRAFT,
    ::ES_UNIT_TYPE_TANK,
    ::ES_UNIT_TYPE_SHIP
  ]

  static function open()
  {
    ::gui_start_modal_wnd(::gui_handlers.GameModeSelect)
  }

  function getSceneTplView()
  {
    return { categories = categories }
  }

  function initScreen()
  {
    backSceneFunc = ::gui_start_mainmenu
    updateContent()
  }

  function fillModesList()
  {
    filledGameModes.clear()

    foreach (cat in categories)
    {
      local modes = this[cat.modesGenFunc]()
      if (modes.len() == 0)
      {
        filledGameModes.append({
          isEmpty = true
          textWhenEmpty = cat?.textWhenEmpty || ""
          isMode = false
        })
        continue
      }

      if (cat?.separator)
        filledGameModes.append({ separator = true, isMode = false })
      filledGameModes.extend(modes)
    }

    local placeObj = scene.findObject("general_game_modes")
    if (!::check_obj(placeObj))
      return

    local data = ::handyman.renderCached("gui/gameModeSelect/gameModeBlock", { block = filledGameModes })
    guiScene.replaceContentFromText(placeObj, data, data.len(), this)

    setGameModesTimer()
  }

  function updateContent()
  {
    gameModesWithTimer.clear()
    newIconWidgetsByGameModeID.clear()

    fillModesList()

    registerNewIconWidgets()
    updateClusters()
    updateButtons()
    updateEventDescriptionConsoleButton(::game_mode_manager.getCurrentGameMode())

    updateSelection()
  }

  function updateSelection()
  {
    local curGM = ::game_mode_manager.getCurrentGameMode()
    if (curGM == null)
      return

    local curGameModeObj = scene.findObject("general_game_modes")
    if (!::check_obj(curGameModeObj))
      return

    local index = filledGameModes.findindex(@(gm) gm.isMode && gm?.hasContent && gm.modeId == curGM.id) ?? -1
    curGameModeObj.setValue(index)
    ::move_mouse_on_child(curGameModeObj, index)
  }

  function registerNewIconWidgets()
  {
    foreach (gameMode in filledGameModes)
    {
      if (!gameMode.isMode || !gameMode?.hasContent)
        continue

      local widgetObj = scene.findObject(getWidgetId(gameMode.id))
      if (!::check_obj(widgetObj))
        continue

      local widget = NewIconWidget(guiScene, widgetObj)
      newIconWidgetsByGameModeID[gameMode.id] <- widget
      widget.setWidgetVisible(!::game_mode_manager.isSeen(gameMode.id))
    }
  }

  function createFeaturedModesView()
  {
    local view = []
    view.extend(getViewArray(::game_mode_manager.getPveBattlesGameModes()))
    view.extend(getViewArray(::game_mode_manager.getFeaturedGameModes()))
    view.extend(createFeaturedLinksView())
    view.extend(getViewArray(::game_mode_manager.getClanBattlesGameModes()))
    return view
  }

  function getViewArray(gameModesArray)
  {
    local view = []
    // First go all wide featured game modes then - non-wide.
    local numNonWideGameModes = 0
    foreach (isWide in [ true, false ])
    {
      while (true)
      {
        local gameMode = getGameModeByCondition(gameModesArray,
          @(gameMode) gameMode.displayWide == isWide) // warning disable: -iterator-in-lambda
        if (gameMode == null)
          break
        if (!isWide)
          ++numNonWideGameModes
        local index = ::find_in_array(gameModesArray, gameMode)
        gameModesArray.remove(index)
        view.append(createGameModeView(gameMode))
      }
    }
    sortByUnitType(view)
    // Putting a dummy block to show featured links in one line.
    if ((numNonWideGameModes & 1) == 1)
      view.append(createGameModeView(null))
    return view
  }

  function sortByUnitType(gameModeViews)
  {
    gameModeViews.sort(function(a, b) { // warning disable: -return-different-types
      foreach(unitType in unitTypes.types)
      {
        if(b.isWide != a.isWide)
          return b.isWide <=> a.isWide
        local isAContainsType = a.gameMode.unitTypes.indexof(unitType.esUnitType) != null
        local isBContainsType = b.gameMode.unitTypes.indexof(unitType.esUnitType) != null
        if( ! isAContainsType && ! isBContainsType)
          continue
        return isBContainsType <=> isAContainsType
        || b.gameMode.unitTypes.len() <=> a.gameMode.unitTypes.len()
      }
      return 0
    })
  }

  function createDebugGameModesView()
  {
    local view = []
    local debugGameModes = ::game_mode_manager.getDebugGameModes()
    foreach (gameMode in debugGameModes)
      view.append(createGameModeView(gameMode))
    return view
  }

  function createFeaturedLinksView()
  {
    local res = []
    foreach (idx, mode in ::featured_modes)
    {
      if (!mode.isVisible())
        continue

      local id = ::game_mode_manager.getGameModeItemId(mode.modeId)
      local hasNewIconWidget = mode.hasNewIconWidget && !::game_mode_manager.isSeen(id)
      local newIconWidgetContent = hasNewIconWidget? NewIconWidget.createLayout() : null

      res.append({
        id = id
        modeId = mode.modeId
        hasContent = true
        isMode = true
        text  = mode.text
        textDescription = mode.textDescription
        hasCountries = false
        isWide = mode.isWide
        image = mode.image()
        gameMode = mode
        checkBox = false
        linkIcon = true
        isFeatured = true
        onClick = "onGameModeSelect"
        onHover = "markGameModeSeen"
        showEventDescription = false
        newIconWidgetId = getWidgetId(id)
        newIconWidgetContent = newIconWidgetContent
        inactiveColor = mode?.inactiveColor ?? @() false
        crossPlayRestricted = mode?.crossPlayRestricted ?? @() false
        crossplayTooltip = mode?.crossplayTooltip
        isCrossPlayRequired = mode?.isCrossPlayRequired ?? @() false
      })
      if (mode?.updateByTimeFunc)
        gameModesWithTimer[id] <- mode.updateByTimeFunc
    }
    return res
  }

  function createGameModesView()
  {
    local gameModesView = []
    local partitions = ::game_mode_manager.getGameModesPartitions()
    foreach (partition in partitions)
    {
      local partitionView = createGameModesPartitionView(partition)
      if (partitionView)
        gameModesView.extend(partitionView)
    }
    return gameModesView
  }

  function createGameModeView(gameMode, separator = false, isNarrow = false)
  {
    if (gameMode == null)
      return {
        hasContent = false
        isNarrow = isNarrow
        isMode = true
      }

    local countries = createGameModeCountriesView(gameMode)
    local isLink = gameMode.displayType.showInEventsWindow
    local event = ::game_mode_manager.getGameModeEvent(gameMode)
    local trophyName = ::events.getEventPVETrophyName(event)

    local id = ::game_mode_manager.getGameModeItemId(gameMode.id)
    local hasNewIconWidget = !::game_mode_manager.isSeen(id)
    local newIconWidgetContent = hasNewIconWidget? NewIconWidget.createLayout() : null

    local crossPlayRestricted = isMultiplayerPrivilegeAvailable() && !isCrossPlayEventAvailable(event)
    local inactiveColor = !isMultiplayerPrivilegeAvailable() || crossPlayRestricted
    if (gameMode?.updateByTimeFunc)
      gameModesWithTimer[id] <- mode.updateByTimeFunc

    return {
      id = id
      modeId = gameMode.id
      hasContent = true
      isMode = true
      isConsoleBtn = ::show_console_buttons
      text = gameMode.text
      getEvent = gameMode?.getEvent
      textDescription = ::getTblValue("textDescription", gameMode, null)
      tooltip = gameMode.getTooltipText()
      hasCountries = countries.len() != 0
      countries = countries
      isCurrentGameMode = gameMode.id == ::game_mode_manager.getCurrentGameModeId()
      isWide = gameMode.displayWide
      isNarrow = isNarrow
      image = gameMode.image
      videoPreview = gameMode.videoPreview
      checkBox = !isLink
      linkIcon = isLink
      newIconWidgetId = getWidgetId(id)
      newIconWidgetContent = newIconWidgetContent
      isFeatured = true
      onClick = "onGameModeSelect"
      onHover = "markGameModeSeen"
      // Used to easily backtrack corresponding game mode.
      gameMode = gameMode
      inactiveColor = (gameMode?.inactiveColor ?? @() false)() || inactiveColor
      crossPlayRestricted = crossPlayRestricted
      crossplayTooltip = getRestrictionTooltipText(event)
      isCrossPlayRequired = crossplayModule.needShowCrossPlayInfo() && !::events.isEventPlatformOnlyAllowed(event)
      showEventDescription = !isLink && ::events.isEventNeedInfoButton(event)
      eventTrophyImage = getTrophyMarkUpData(trophyName)
      isTrophyRecieved = trophyName == ""? false : !::can_receive_pve_trophy(-1, trophyName)
      mapPreferences = isShowMapPreferences(gameMode?.getEvent())
      prefTitle = mapPreferencesParams.getPrefTitle(gameMode?.getEvent())
    }
  }

  function getRestrictionTooltipText(event)
  {
    if (!isMultiplayerPrivilegeAvailable())
      return ::loc("xbox/noMultiplayer")

    if (!crossplayModule.needShowCrossPlayInfo()) //No need tooltip on other platforms
      return null

    //Always send to other platform if enabled
    //Need to notify about it
    if (crossplayModule.isCrossPlayEnabled())
      return ::loc("xbox/crossPlayEnabled")

    //If only platform - no need to notify
    if (::events.isEventPlatformOnlyAllowed(event))
      return null

    //Notify that crossplay is strongly required
    return ::loc("xbox/crossPlayRequired")
  }

  function isCrossPlayEventAvailable(event)
  {
    return crossplayModule.isCrossPlayEnabled()
           || ::events.isEventPlatformOnlyAllowed(event)
  }

  function getWidgetId(gameModeId)
  {
    return gameModeId + "_widget"
  }

  function getTrophyMarkUpData(trophyName)
  {
    if (::u.isEmpty(trophyName))
      return null

    local trophyItem = ::ItemsManager.findItemById(trophyName, itemType.TROPHY)
    if (!trophyItem)
      return null

    return trophyItem.getNameMarkup(0, false)
  }

  function createGameModeCountriesView(gameMode)
  {
    local res = []
    local countries = gameMode.countries
    if (!countries.len() || countries.len() >= ::g_crews_list.get().len())
      return res

    local needShowLocked = false
    if (countries.len() >= 0.7 * ::g_crews_list.get().len())
    {
      local lockedCountries = []
      foreach(countryData in ::g_crews_list.get())
      {
        local country = countryData.country
        if (!::isInArray(country, countries))
          lockedCountries.append(country)
      }

      needShowLocked = true
      countries = lockedCountries
    }

    foreach (country in countries)
      res.append({ img = ::get_country_icon(country, false, needShowLocked) })
    return res
  }

  function createGameModesPartitionView(partition)
  {
    if (partition.gameModes.len() == 0)
      return null

    local gameModes = partition.gameModes
    local needEmptyGameModeBlocks = !!::u.search(gameModes, @(gm) !gm.displayWide)
    local view = []
    foreach (idx, esUnitType in basePanelConfig)
    {
      local gameMode = chooseGameModeEsUnitType(gameModes, esUnitType, basePanelConfig)
      if (gameMode)
        view.append(createGameModeView(gameMode, false, true))
      else if (needEmptyGameModeBlocks)
        view.append(createGameModeView(null, false, true))
    }

    return view
  }

  /**
   * Find appropriate game mode from array and returns it.
   * If game mode is not null, it will be removed from array.
   */
  function chooseGameModeEsUnitType(gameModes, esUnitType, esUnitTypesFilter)
  {
    return getGameModeByCondition(gameModes,
      @(gameMode) u.max(::game_mode_manager.getRequiredUnitTypes(gameMode).filter(
        @(esUType) ::isInArray(esUType, esUnitTypesFilter))) == esUnitType)
  }

  function getGameModeByCondition(gameModes, conditionFunc)
  {
    return ::u.search(gameModes, conditionFunc)
  }

  function onGameModeSelect(obj)
  {
    if (!checkAndShowMultiplayerPrivilegeWarning())
      return

    markGameModeSeen(obj)
    local gameModeView = u.search(filledGameModes, @(gm) gm.isMode && gm?.hasContent && gm.modeId == obj.modeId)
    performGameModeSelect(gameModeView.gameMode)
  }

  function performGameModeSelect(gameMode)
  {
    if (gameMode?.diffCode == ::DIFFICULTY_HARDCORE &&
        !::check_package_and_ask_download("pkg_main"))
      return

    local event = ::game_mode_manager.getGameModeEvent(gameMode)
    if (event && !isCrossPlayEventAvailable(event))
    {
      if (!::xbox_try_show_crossnetwork_message())
        ::showInfoMsgBox(::loc("xbox/actionNotAvailableCrossNetworkPlay"))
      return
    }

    guiScene.performDelayed(this, function() {
      if (!isValid())
        return
      goBack()

      if ("startFunction" in gameMode)
        gameMode.startFunction()
      else if (gameMode?.displayType?.showInEventsWindow)
        ::gui_start_modal_events({ event = event?.name })
      else
        ::game_mode_manager.setCurrentGameModeById(gameMode.modeId, true)
    })
  }

  function markGameModeSeen(obj)
  {
    if (!obj?.id || ::game_mode_manager.isSeen(obj.id))
      return

    local widget = ::getTblValue(obj.id, newIconWidgetsByGameModeID)
    if (!widget)
      return

    ::game_mode_manager.markShowingGameModeAsSeen(obj.id)
    widget.setWidgetVisible(false)
  }

  function onGameModeGamepadSelect(obj)
  {
    local val = obj.getValue()
    if (val < 0 || val >= obj.childrenCount())
      return

    local gmView = filledGameModes[val]
    local modeObj = scene.findObject(gmView.id)

    markGameModeSeen(modeObj)
    updateEventDescriptionConsoleButton(gmView.gameMode)
  }

  function onOpenClusterSelect(obj)
  {
    clustersModule.createClusterSelectMenu(obj)
  }

  function onEventClusterChange(params)
  {
    updateClusters()
  }

  function updateClusters()
  {
    local clustersObj = showBtn("cluster_select_button", isMultiplayerPrivilegeAvailable())
    clustersModule.updateClusters(clustersObj.findObject("cluster_select_button_text"))
  }

  function onClusterSelectActivate(obj)
  {
    local value = obj.getValue()
    local childObj = (value >= 0 && value < obj.childrenCount()) ? obj.getChild(value) : null
    if (::checkObj(childObj))
      onOpenClusterSelect(childObj)
  }

  function onGameModeActivate(obj)
  {
    local value = ::get_obj_valid_index(obj)
    if (value < 0)
      return

    performGameModeSelect(filledGameModes[value].gameMode)
  }

  function onEventDescription(obj)
  {
    openEventDescription(::game_mode_manager.getGameModeById(obj.modeId))
  }

  function onGamepadEventDescription(obj)
  {
    local gameModesObject = getObj("general_game_modes")
    if (!::checkObj(gameModesObject))
      return

    local value = gameModesObject.getValue()
    if (value < 0)
      return

    openEventDescription(filledGameModes[value].gameMode)
  }

  function openEventDescription(gameMode)
  {
    local event = ::game_mode_manager.getGameModeEvent(gameMode)
    if (event != null)
    {
      restoreFromModal = true
      ::events.openEventInfo(event)
    }
  }

  function updateEventDescriptionConsoleButton(gameMode)
  {
    showSceneBtn("event_description_console_button", gameMode != null
      && gameMode?.forClan
      && ::show_console_buttons
      && isMultiplayerPrivilegeAvailable()
    )

    local prefObj = showSceneBtn("map_preferences_console_button", isShowMapPreferences(gameMode?.getEvent())
      && ::show_console_buttons)

    if (!::check_obj(prefObj))
      return

    prefObj.setValue(mapPreferencesParams.getPrefTitle(gameMode?.getEvent()))
    prefObj.modeId = gameMode?.id
  }

  function onEventCurrentGameModeIdChanged(p) { updateContent() }
  function onEventGameModesUpdated(p) { updateContent() }
  function onEventWWLoadOperation(p) { updateContent() }
  function onEventWWStopWorldWar(p) { updateContent() }
  function onEventWWShortGlobalStatusChanged(p) { updateContent() }
  function onEventCrossPlayOptionChanged(p) { updateContent() }

  function updateButtons()
  {
    ::showBtn("wiki_link", ::has_feature("AllowExternalLink") && !::is_vendor_tencent(), scene)
  }

  function setGameModesTimer()
  {
    local timerObj = scene.findObject("game_modes_timer")
    if (::check_obj(timerObj))
      timerObj.setUserData(gameModesWithTimer.len()? this : null)
  }

  function onTimerUpdate(obj, dt)
  {
    foreach (gameModeId, updateFunc in gameModesWithTimer)
    {
      updateFunc(scene, gameModeId)
    }
  }

  function isShowMapPreferences(curEvent)
  {
    return ::has_feature("MapPreferences") && !::is_me_newbie()
      && isMultiplayerPrivilegeAvailable()
      && mapPreferencesParams.hasPreferences(curEvent)
      && ((curEvent?.maxDislikedMissions ?? 0) > 0 || (curEvent?.maxBannedMissions ?? 0) > 0)
  }

  function onMapPreferences(obj)
  {
    local curEvent = obj?.modeId != null
      ? ::game_mode_manager.getGameModeById(obj.modeId)?.getEvent()
      : ::game_mode_manager.getCurrentGameMode()?.getEvent()
    ::g_squad_utils.checkSquadUnreadyAndDo(
      Callback(@() mapPreferencesModal.open({curEvent = curEvent}), this),
      null, shouldCheckCrewsReady)
  }
}
