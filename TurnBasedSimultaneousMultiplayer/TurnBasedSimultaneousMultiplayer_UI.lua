-- TurnBasedSimultaneousMultiplayer_UI
-- Author: petty
-- DateCreated: 6/3/2023 8:59:50 PM
--------------------------------------------------------------
-- TBSM_UI
-- Author: Patrick Fink
-- DateCreated: 4/4/2020 1:53:04 PM
--------------------------------------------------------------

include("TutorialUIRoot_Expansion1.lua");
include("PopupDialog.lua");

-- Settings
local tbsm_Setting_MilitaryActionsPerTurn = 1;
local tbsm_Setting_AttackerFirstStrikeBonusFactor = 2;
local tbsm_Setting_MovementActionsPerTurn = 0;
local tbsm_Setting_RotatoryMode = true;
local tbsm_Setting_MilitaryActionsForMovementAllowed = true;

-- State
local tbsm_RemainingMilitaryActions = {}; -- Table: PlayerID -> RemainingMilitaryActions
local tbsm_RemainingMovementActions = {}; -- Table  PlayerID -> RemainingMovementActions

local function Verbose(message)
   print(message);
end

Verbose("Start Initialization");


local function Refresh()
	local myRemainingActions = tbsm_RemainingMilitaryActions[Game.GetLocalPlayer()];
	Controls.TBSMRemainingActions:SetText( Locale.Lookup("LOC_TBSM_REMAINING_ACTIONS") .. ": " ..  tostring(myRemainingActions));
end


local function Initialize()
	playerID = Game.GetLocalPlayer();
	Verbose("PlayerID" .. playerID);
	tbsm_RemainingMilitaryActions[playerID] = tbsm_Setting_MilitaryActionsPerTurn;
	Refresh();
end

-----------------
-- UI Mutators --
-----------------


local function AddButtonToTopPanel()
  Verbose("TBSM: AddButtonToTopPanel");

  local topPanel = ContextPtr:LookUpControl("/InGame/TopPanel/RightContents"); -- Top-right stack with Clock, Civilopedia, and Menu
  Controls.TBSMContents:ChangeParent(topPanel);
  topPanel:AddChildAtIndex(Controls.TBSMContents, 5); -- Insert left to the clock
  topPanel:CalculateSize();
  topPanel:ReprocessAnchoring();
end


local function ShowDialog()
  Verbose("TBSM: ShowDialog");
  local m_kPopupDialog:table = PopupDialogInGame:new( "TBSMPrompt" );
  m_kPopupDialog:AddTitle(Locale.Lookup("LOC_TBSM_ACTION_NOT_POSSIBLE_DIALOG_TITLE"));
  m_kPopupDialog:AddText(Locale.Lookup("LOC_TBSM_ACTION_NOT_POSSIBLE_DIALOG_TEXT"));
  m_kPopupDialog:AddConfirmButton(Locale.Lookup("LOC_OK_BUTTON"), function()

  end );
  m_kPopupDialog:Open();
end

---------------
-- Callbacks --
---------------


-- The top panel button next to the CivPedia
local function OnTopPanelButtonClick()
  Verbose("TBSM: OnTopPanelButtonClick");
  ShowDialog();
end

local function unitIsMilitary(unit)
	Verbose("Attacks remaining: " .. unit:GetAttacksRemaining());
	Verbose("Combat: " .. unit:GetCombat());
	Verbose("RangedCombat: " .. unit:GetRangedCombat());
	Verbose("BombardCombat: " .. unit:GetBombardCombat());
	Verbose("AntiAirCombat: " .. unit:GetAntiAirCombat());
	Verbose("isCannotAttack: " .. tostring(unit:IsCannotAttack()));
	return unit:GetCombat() > 0 or unit:GetRangedCombat() > 0 or unit:GetBombardCombat() > 0 or unit:GetAntiAirCombat() > 0; -- A bit glitchy, but the most efficient way I know to find out all military unit types; units with no attacks remaining don't have to be blocked because they have no action left anyway
end

local function forbidAllMilitaryActions()
	local count = 0
	for key, val in pairs(Players) do Verbose("Key " .. key) end
	Verbose("bla " .. count);
	local localPlayer = Game.GetLocalPlayer();
	Verbose("Player " .. localPlayer);
	Verbose("Players " .. tostring(Players[localPlayer]));
	local playerUnits = Players[localPlayer]:GetUnits();
	for i, unit in playerUnits:Members() do
		local unitType:string = GameInfo.Units[pUnit:GetUnitType()].UnitType;
		--local unitTypeName = UnitManager.GetTypeName(unit);
		Verbose("Unit Type:  " .. unitType);		
		if unitIsMilitary(unit) then 
			LuaEvents.Tutorial_AddUnitHexRestriction(unitType, {});
			AddMapUnitMoveRestriction(unitType);
			DisableUnitAction("UNITOPERATION_MOVE_TO", unitType);
		end		
		--DisableUnitAction( "UNITCOMMAND_AUTOMATE", unitType );
		--DisableUnitAction( "UNITOPERATION_AUTOMATE_EXPLORE", unitType );
		--DisableUnitAction( "UNITOPERATION_SKIP_TURN", unitType );
		--DisableUnitAction( "UNITOPERATION_FORTIFY", unitType);
		--DisableUnitAction( "UNITOPERATION_HEAL",	unitType);
		--DisableUnitAction( "UNITCOMMAND_CANCEL",	unitType);
		--DisableUnitAction( "UNITOPERATION_SLEEP",	unitType);
	end
end


local function OnUnitMoved( playerID:number, unitID:number )
	Verbose("TBSM: OnUnitMoved " .. unitID);
	
	pUnit = UnitManager.GetUnit(playerID, unitID);
	Verbose("test " .. tostring(pUnit));
	Verbose("playerID " .. playerID);

	if unitIsMilitary(pUnit) and tbsm_RemainingMilitaryActions[playerID] ~= nil then
		local unitType:string = GameInfo.Units[pUnit:GetUnitType()].UnitType;	
		tbsm_RemainingMilitaryActions[playerID] = tbsm_RemainingMilitaryActions[playerID] - 1;

		if tbsm_RemainingMilitaryActions[playerID] <= 0 then
			forbidAllMilitaryActions()
		end
	end

	Refresh();	
end

-- Callback when we load into the game for the first time
local function OnLoadGameViewStateDone()
  Verbose("TBSM: OnLoadGameViewStateDone");
  Initialize();
  AddButtonToTopPanel();  
  ContextPtr:SetHide(false);
end


----------------
-- Main Setup --
----------------

Events.LoadGameViewStateDone.Add(OnLoadGameViewStateDone);
ContextPtr:SetInputHandler(InputHandler, true);

Controls.TBSMNextTurnButton:RegisterCallback(Mouse.eLClick, OnTopPanelButtonClick);

ActivateInputFiltering();
EnableTutorialCheck();



Events.UnitMoved.Add(OnUnitMoved);

--Events.PlayerTurnActivated.Add(OnPlayerTurnActivated);

Verbose("End Initialization" );