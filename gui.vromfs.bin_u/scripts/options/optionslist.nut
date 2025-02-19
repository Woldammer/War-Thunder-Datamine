local safeAreaMenu = require("scripts/options/safeAreaMenu.nut")
local safeAreaHud = require("scripts/options/safeAreaHud.nut")
local contentPreset = require("scripts/customization/contentPreset.nut")
local soundDevice = require("soundDevice")
local { is_stereo_mode } = ::require_native("vr")
local { chatStatesCanUseVoice } = require("scripts/chat/chatStates.nut")
local { onSystemOptionsApply, canUseGraphicsOptions } = require("scripts/options/systemOptions.nut")
local { isPlatformSony, isPlatformXboxOne } = require("scripts/clientState/platform.nut")
//


local { getPlayerCurUnit } = require("scripts/slotbar/playerCurUnit.nut")

local getSystemOptions = @() {
  name = "graphicsParameters"
  fillFuncName = "fillSystemOptions"
  onApplyHandler = @() onSystemOptionsApply()
  options = []
}

local overrideMainOptionsFn = null

local getMainOptions = function()
{
  if (overrideMainOptionsFn != null)
    return overrideMainOptionsFn()

  local isFirstTutorial = (::current_campaign_name == "tutorial_pacific_41") &&
    (::current_campaign_mission == "tutorial01")
  local canChangeViewType = !isFirstTutorial && (getPlayerCurUnit()?.unitType.canChangeViewType ?? false)

  return {
    name = ::is_in_flight() ? "main" : "mainParameters"
    isSearchAvaliable = true
    options = [
      ["options/mainParameters"],
      [::USEROPT_LANGUAGE, "spinner", ! ::is_in_flight() && ::canSwitchGameLocalization()],
      [::USEROPT_PS4_CROSSPLAY, "spinner", isPlatformSony && ::has_feature("PS4CrossNetwork") && !::is_in_flight()],
      [::USEROPT_PS4_ONLY_LEADERBOARD, "spinner", isPlatformSony && ::has_feature("ConsoleSeparateLeaderboards")],
      [::USEROPT_CLUSTER, "spinner", ! ::is_in_flight() && isPlatformSony],
      //


      [::USEROPT_FONTS_CSS, "spinner"],
      [::USEROPT_GAMMA, "slider", !::is_hdr_enabled() && ::target_platform != "macosx"
                                  && (!::is_platform_windows
                                      || ::getSystemConfigOption("video/mode") == "fullscreen") ],
      [::USEROPT_AUTOLOGIN, "spinner", ! ::is_in_flight() && !(isPlatformSony || isPlatformXboxOne)],
      [::USEROPT_PRELOADER_SETTINGS, "button", ::has_feature("LoadingBackgroundFilter") && !::is_in_flight()],
      [::USEROPT_REVEAL_NOTIFICATIONS, "button"],
      [::USEROPT_POSTFX_SETTINGS, "button", !::is_compatibility_mode()],
      [::USEROPT_HDR_SETTINGS, "button", ::is_hdr_enabled()],

      ["options/header/commonBattleParameters"],
      [::USEROPT_HUD_SHOW_BONUSES, "spinner"],
      [::USEROPT_DAMAGE_INDICATOR_SIZE, "slider"],
      [::USEROPT_CAMERA_SHAKE_MULTIPLIER, "slider"],
      [::USEROPT_VR_CAMERA_SHAKE_MULTIPLIER, "slider", is_stereo_mode()],
      [::USEROPT_FPS_CAMERA_PHYSICS, "slider"],
      [::USEROPT_FPS_VR_CAMERA_PHYSICS, "slider", is_stereo_mode()],
      [::USEROPT_AUTO_SQUAD, "spinner"],
      [::USEROPT_QUEUE_JIP, "spinner"],
      [::USEROPT_ORDER_AUTO_ACTIVATE, "spinner", ::has_feature("OrderAutoActivate")],
      [::USEROPT_TANK_ALT_CROSSHAIR, "spinner", ::can_add_tank_alt_crosshair()
                                                && (::has_feature("TankAltCrosshair")
                                                    || ::get_user_alt_crosshairs().len()
                                                   )],

      ["options/header/air"],
      [::USEROPT_HUE_AIRCRAFT_HUD, "spinner", ::has_feature("reactivGuiForAircraft")],
      [::USEROPT_HUE_AIRCRAFT_PARAM_HUD, "spinner",  ::has_feature("reactivGuiForAircraft")],
      [::USEROPT_HUE_AIRCRAFT_HUD_ALERT, "spinner",  ::has_feature("reactivGuiForAircraft")],
      [::USEROPT_VIEWTYPE, "spinner", ! ::is_in_flight()],
      [::USEROPT_GUN_TARGET_DISTANCE, "spinner", ! ::is_in_flight()],
      [::USEROPT_GUN_VERTICAL_TARGETING, "spinner", ! ::is_in_flight()],
      [::USEROPT_BOMB_ACTIVATION_TIME, "spinner", ! ::is_in_flight()],
      [::USEROPT_BOMB_SERIES, "spinner", ! ::is_in_flight()],
      [::USEROPT_COUNTERMEASURES_SERIES_PERIODS, "spinner", ! ::is_in_flight()],
      [::USEROPT_COUNTERMEASURES_PERIODS, "spinner", ! ::is_in_flight()],
      [::USEROPT_COUNTERMEASURES_SERIES, "spinner", ! ::is_in_flight()],
      [::USEROPT_SHOW_PILOT, "spinner"],
      [::USEROPT_AUTOPILOT_ON_BOMBVIEW, "spinner"],
      [::USEROPT_AUTOREARM_ON_AIRFIELD, "spinner"],
      [::USEROPT_ENABLE_LASER_DESIGNATOR_ON_LAUNCH, "spinner"],
      [::USEROPT_AUTO_AIMLOCK_ON_SHOOT, "spinner"],
      [::USEROPT_ACTIVATE_AIRBORNE_RADAR_ON_SPAWN, "spinner"],
      [::USEROPT_USE_RECTANGULAR_RADAR_INDICATOR, "spinner"],
      [::USEROPT_USE_RADAR_HUD_IN_COCKPIT, "spinner"],
      [::USEROPT_ACTIVATE_AIRBORNE_ACTIVE_COUNTER_MEASURES_ON_SPAWN, "spinner"],
      [::USEROPT_AIR_RADAR_SIZE, "slider"],
      [::USEROPT_CROSSHAIR_TYPE, "combobox"],
      [::USEROPT_CROSSHAIR_COLOR, "combobox"],
      [::USEROPT_INDICATED_SPEED_TYPE, "spinner"],
      [::USEROPT_CROSSHAIR_DEFLECTION, "spinner"],
      [::USEROPT_AIR_DAMAGE_DISPLAY, "spinner", ! ::is_in_flight()],
      [::USEROPT_GUNNER_FPS_CAMERA, "spinner"],
      [::USEROPT_ACTIVATE_AIRBORNE_WEAPON_SELECTION_ON_SPAWN, "spinner"],

      ["options/header/helicopter"],
      [::USEROPT_HUE_HELICOPTER_HUD, "spinner"],
      [::USEROPT_HUE_HELICOPTER_PARAM_HUD, "spinner"],
      [::USEROPT_HUE_HELICOPTER_HUD_ALERT, "spinner"],
      [::USEROPT_HUE_HELICOPTER_MFD, "spinner"],
      [::USEROPT_HORIZONTAL_SPEED, "spinner"],
      [::USEROPT_HELICOPTER_HELMET_AIM, "spinner", !(isPlatformSony || isPlatformXboxOne)],
      [::USEROPT_HELICOPTER_AUTOPILOT_ON_GUNNERVIEW, "spinner"],

      ["options/header/tank"],
      [::USEROPT_GRASS_IN_TANK_VISION, "spinner"],
      [::USEROPT_XRAY_DEATH, "spinner", ::has_feature("Tanks") && ::has_feature("XrayDeath")],
      [::USEROPT_XRAY_KILL, "spinner", ::has_feature("Tanks") && ::has_feature("XrayKill")],
      [::USEROPT_TANK_GUNNER_CAMERA_FROM_SIGHT, "spinner",
        ::has_feature("Tanks") && ( ! ::is_in_flight() || ! ::is_tank_gunner_camera_from_sight_available())],
      [::USEROPT_SHOW_DESTROYED_PARTS, "spinner", ::has_feature("Tanks")],
      [::USEROPT_ACTIVATE_GROUND_RADAR_ON_SPAWN, "spinner", ::has_feature("Tanks")],
      [::USEROPT_ACTIVATE_GROUND_ACTIVE_COUNTER_MEASURES_ON_SPAWN, "spinner", ::has_feature("Tanks")],
      [::USEROPT_TACTICAL_MAP_SIZE, "slider"],
      [::USEROPT_MAP_ZOOM_BY_LEVEL, "spinner", !(isPlatformSony || isPlatformXboxOne) && !::is_platform_android],
      // show option by code != -1 need for compatibility with 1_93_0_X
      // TODO: remove after 1_93_0_X
      [::USEROPT_SHOW_COMPASS_IN_TANK_HUD, "spinner"],
      [::USEROPT_HUE_TANK_THERMOVISION, "spinner"],
      [::USEROPT_PITCH_BLOCKER_WHILE_BRACKING, "spinner"],
      [::USEROPT_COMMANDER_CAMERA_IN_VIEWS, "spinner"],
      [::USEROPT_SAVE_DIR_WHILE_SWITCH_TRIGGER, "spinner"],

      ["options/header/ship"],
      [::USEROPT_DEPTHCHARGE_ACTIVATION_TIME, "spinner", ! ::is_in_flight()],
      [::USEROPT_USE_PERFECT_RANGEFINDER, "spinner", ::has_feature("Ships")],
      [::USEROPT_SAVE_AI_TARGET_TYPE, "spinner", ::has_feature("Ships")],
      [::USEROPT_DEFAULT_AI_TARGET_TYPE, "spinner", ::has_feature("Ships")],
      [::USEROPT_DEFAULT_TORPEDO_FORESTALL_ACTIVE, "spinner", ::has_feature("Ships")],
      [::USEROPT_BULLET_FALL_INDICATOR_SHIP, "spinner", ::has_feature("Ships")],
      [::USEROPT_BULLET_FALL_SPOT_SHIP, "spinner", ::has_feature("Ships")],
      [::USEROPT_BULLET_FALL_SOUND_SHIP, "spinner", ::has_feature("Ships")],
      [::USEROPT_AUTO_TARGET_CHANGE_SHIP, "spinner", ::has_feature("Ships")],
      [::USEROPT_REALISTIC_AIMING_SHIP, "spinner", ::has_feature("Ships")
        && (!::is_in_flight() || ::get_mission_difficulty() == ::g_difficulty.ARCADE.gameTypeName)],
      // TODO: separate from tank [::USEROPT_TACTICAL_MAP_SIZE, "slider"],
      // TODO: separate from tank [::USEROPT_MAP_ZOOM_BY_LEVEL, "spinner"],
      [::USEROPT_FOLLOW_BULLET_CAMERA, "spinner", ::has_feature("Ships") && ::has_feature("enableFollowBulletCamera")],

      ["options/header/interface"],
      [::USEROPT_HUD_SCREEN_SAFE_AREA, "spinner", safeAreaHud.canChangeValue()],
      [::USEROPT_GAME_HUD, "spinner"],
      [::USEROPT_HUD_INDICATORS, "spinner", "get_option_hud_indicators" in getroottable()],
      [::USEROPT_HUE_SQUAD, "spinner"],
      [::USEROPT_HUE_ALLY, "spinner"],
      [::USEROPT_HUE_ENEMY, "spinner"],
      [::USEROPT_HUE_RELOAD, "spinner"],
      [::USEROPT_HUE_RELOAD_DONE, "spinner"],
      [::USEROPT_HUE_ARBITER_HUD, "spinner", ::has_feature("reactivGuiForArbitrer")],
      [::USEROPT_STROBE_ALLY, "spinner"],
      [::USEROPT_STROBE_ENEMY, "spinner"],
      [::USEROPT_HUD_SHOW_FUEL, "spinner"],
      [::USEROPT_HUD_SHOW_AMMO, "spinner"],
      [::USEROPT_HUD_SHOW_TEMPERATURE, "spinner"],
      [::USEROPT_INGAME_VIEWTYPE, "spinner", ::is_in_flight() && canChangeViewType],

      ["options/header/measureUnits"],
      [::USEROPT_MEASUREUNITS_SPEED, "spinner"],
      [::USEROPT_MEASUREUNITS_ALT, "spinner"],
      [::USEROPT_MEASUREUNITS_DIST, "spinner"],
      [::USEROPT_MEASUREUNITS_CLIMBSPEED, "spinner"],
      [::USEROPT_MEASUREUNITS_TEMPERATURE, "spinner"],
      [::USEROPT_MEASUREUNITS_WING_LOADING, "spinner", ::has_feature("CardAirplaneWingLoadingParameter")],
      [::USEROPT_MEASUREUNITS_POWER_TO_WEIGHT_RATIO, "spinner", ::has_feature("CardAirplanePowerParameter")],

      ["options/header/playersMarkers"],
      [::USEROPT_SHOW_INDICATORS, "spinner"],
      [::USEROPT_SHOW_INDICATORS_TYPE, "spinner"],
      [::USEROPT_SHOW_INDICATORS_NICK, "spinner"],
      [::USEROPT_SHOW_INDICATORS_AIRCRAFT, "spinner"],
      [::USEROPT_SHOW_INDICATORS_TITLE, "spinner"],
      [::USEROPT_SHOW_INDICATORS_DIST, "spinner"],

      ["options/header/chatAndVoiceChat"],
      [::USEROPT_PS4_CROSSNETWORK_CHAT, "spinner", isPlatformSony && ::has_feature("PS4CrossNetwork")],
      [::USEROPT_ONLY_FRIENDLIST_CONTACT, "spinner", ! ::is_in_flight()],
      [::USEROPT_AUTO_SHOW_CHAT, "spinner"],
      [::USEROPT_CHAT_MESSAGES_FILTER, "spinner"],
      [::USEROPT_CHAT_FILTER, "spinner"],
      [::USEROPT_MARK_DIRECT_MESSAGES_AS_PERSONAL, "spinner"],

      //TODO fillVoiceChatOptions
      //[::USEROPT_VOICE_CHAT, "spinner"],
      //[::USEROPT_VOLUME_VOICE_IN, "slider"],
      //[::USEROPT_VOLUME_VOICE_OUT, "slider"],
      //[::USEROPT_PTT, "spinner"],

      ["options/header/gamepad"],
      [::USEROPT_ENABLE_CONSOLE_MODE, "spinner", !::get_is_console_mode_force_enabled()],
      [::USEROPT_GAMEPAD_CURSOR_CONTROLLER, "spinner", ::g_gamepad_cursor_controls.canChangeValue()],
      [::USEROPT_XCHG_STICKS, "spinner"],
      [::USEROPT_VIBRATION, "spinner"],
      [::USEROPT_GAMEPAD_VIBRATION_ENGINE, "spinner", !isPlatformSony],
      [::USEROPT_JOY_MIN_VIBRATION, "slider"],
      [::USEROPT_GAMEPAD_ENGINE_DEADZONE, "spinner"],
      [::USEROPT_GAMEPAD_GYRO_TILT_CORRECTION, "spinner", isPlatformSony],
      [::USEROPT_USE_CONTROLLER_LIGHT, "spinner", isPlatformSony && ::has_feature("ControllerLight")],

      ["options/header/replaysAndSpectatorMode", null, ::has_feature("ClientReplay") || ::has_feature("ServerReplay") || ::has_feature("Spectator")],
      [::USEROPT_AUTOSAVE_REPLAYS, "spinner", !::is_in_flight() && ::has_feature("ClientReplay")],
      [::USEROPT_HUE_SPECTATOR_ALLY, "spinner", ::has_feature("ClientReplay") || ::has_feature("ServerReplay") || ::has_feature("Spectator")],
      [::USEROPT_HUE_SPECTATOR_ENEMY, "spinner", ::has_feature("ClientReplay") || ::has_feature("ServerReplay") || ::has_feature("Spectator")],
      [::USEROPT_REPLAY_ALL_INDICATORS, "spinner", ::has_feature("ClientReplay") || ::has_feature("ServerReplay") || ::has_feature("Spectator")],
      [::USEROPT_REPLAY_LOAD_COCKPIT, "spinner", ::has_feature("ClientReplay") || ::has_feature("ServerReplay") || ::has_feature("Spectator")],
      [::USEROPT_HIDE_MOUSE_SPECTATOR, "spinner", ::has_feature("ClientReplay") || ::has_feature("ServerReplay") || ::has_feature("Spectator")],

      ["options/header/userGeneratedContent"],
      [::USEROPT_CONTENT_ALLOWED_PRESET_ARCADE,    "combobox", contentPreset.getContentPresets().len()],
      [::USEROPT_CONTENT_ALLOWED_PRESET_REALISTIC, "combobox", contentPreset.getContentPresets().len()],
      [::USEROPT_CONTENT_ALLOWED_PRESET_SIMULATOR, "combobox",
        contentPreset.getContentPresets().len() &&
        ::g_difficulty.SIMULATOR.isAvailable(::GM_DOMINATION)],
      [::USEROPT_DELAYED_DOWNLOAD_CONTENT, "spinner", ::has_feature("delayedDownloadContent")],

      ["options/header/privacy", null, ::has_feature("PrivacySettings")],
      [::USEROPT_REPLACE_MY_NICK_LOCAL, "editbox", ::has_feature("PrivacySettings")],
      [::USEROPT_SHOW_SOCIAL_NOTIFICATIONS, "spinner", ::has_feature("PrivacySettings")],
      [::USEROPT_ALLOW_ADDED_TO_CONTACTS, "spinner", ::has_feature("PrivacySettings")],
      [::USEROPT_ALLOW_ADDED_TO_LEADERBOARDS, "spinner", ::has_feature("PrivacySettings")],

      ["options/header/otherOptions"],
      [::USEROPT_MENU_SCREEN_SAFE_AREA, "spinner", safeAreaMenu.canChangeValue()],
      [::USEROPT_SUBTITLES, "spinner"],
      [::USEROPT_HUD_SCREENSHOT_LOGO, "spinner", ::is_platform_pc],
      [::USEROPT_SAVE_ZOOM_CAMERA, "spinner", !::u.isNull(::get_option_save_zoom_camera())] //compatibility with wop_1_77_2_X
    ]
  }
}

local overrideSoundOptionsFn = null

local getSoundOptions = @() overrideSoundOptionsFn?() ?? {
  name = "sound"
  options = [
    [::USEROPT_SOUND_ENABLE, "switchbox", ::is_platform_pc],
    [::USEROPT_SOUND_DEVICE_OUT, "combobox", ::is_platform_pc && soundDevice.get_out_devices().len() > 0],
    [::USEROPT_SOUND_SPEAKERS_MODE, "combobox", ::is_platform_pc],
    [::USEROPT_VOICE_MESSAGE_VOICE, "spinner"],
    [::USEROPT_SPEECH_TYPE, "spinner", ! ::is_in_flight()],
    [::USEROPT_VOLUME_MASTER, "slider"],
    [::USEROPT_VOLUME_MUSIC, "slider"],
    [::USEROPT_VOLUME_MENU_MUSIC, "slider"],
    [::USEROPT_VOLUME_SFX, "slider"],
    [::USEROPT_VOLUME_ENGINE, "slider"],
    [::USEROPT_VOLUME_MY_ENGINE, "slider"],
    [::USEROPT_VOLUME_GUNS, "slider"],
    [::USEROPT_VOLUME_RADIO, "slider"],
    [::USEROPT_VOLUME_DIALOGS, "slider"],
    [::USEROPT_VOLUME_TINNITUS, "slider"],
    [::USEROPT_HANGAR_SOUND, "spinner"],
    [::USEROPT_PLAY_INACTIVE_WINDOW_SOUND, "spinner", ::is_platform_pc],
    [::USEROPT_ENABLE_SOUND_SPEED, "spinner", (! ::is_in_flight()) || (::get_mission_difficulty_int() != ::DIFFICULTY_HARDCORE) ]
  ]
}

local getVoicechatOptions = function()
{
  local voiceOptions = {
    name = "voicechat"
    fillFuncName = "fillVoiceChatOptions"
    options = [
      [::USEROPT_VOICE_CHAT, "spinner"],
      [::USEROPT_VOLUME_VOICE_IN, "slider"],
      [::USEROPT_VOLUME_VOICE_OUT, "slider"],
      [::USEROPT_PTT, "spinner"]
    ]
  }

  if (!isPlatformSony && !isPlatformXboxOne)
  {
    if (soundDevice.get_record_devices().len() > 0)
      voiceOptions.options.insert(1, [::USEROPT_VOICE_DEVICE_IN, "combobox"])
  }

  return voiceOptions
}

local getSocialOptions = @() {
  name = "social"
  fillFuncName = "fillSocialOptions"
  options = []
}

local getInternetRadioOptions = @() {
  name = "internet_radio"
  fillFuncName = "fillInternetRadioOptions"
  options = [
    [::USEROPT_INTERNET_RADIO_ACTIVE, "spinner"],
    [::USEROPT_INTERNET_RADIO_STATION, "combobox"],
  ]
}

local getOptionsList = function() {
  local options = [ getMainOptions() ]

  if (canUseGraphicsOptions())
    options.append(getSystemOptions())

  options.append(getSoundOptions())

  if (chatStatesCanUseVoice())
    options.append(getVoicechatOptions())

  if (::has_feature("Radio"))
    options.append(getInternetRadioOptions())

  if (::has_feature("Facebook"))
    options.append(getSocialOptions())

  return options
}

return {
  getOptionsList = getOptionsList
  overrideMainOptions = @(fn) overrideMainOptionsFn = fn
  overrideSoundOptions = @(fn) overrideSoundOptionsFn = fn
}
