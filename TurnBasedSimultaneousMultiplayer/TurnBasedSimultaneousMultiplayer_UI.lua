-- TurnBasedSimultaneousMultiplayer_UI
-- Author: petty
-- DateCreated: 6/3/2023 8:59:50 PM
--------------------------------------------------------------
-- TBSM_UI
-- Author: Patrick Fink
-- DateCreated: 4/4/2020 1:53:04 PM
--------------------------------------------------------------
--[[
TODOs:

- Peace
- Allies
- Triangle Wars
- Re-enable military actions when count goes > 0
- Initial Loading (Randomized)
- Testing
- Give unlimited actions when oponent has ended turn 
- ... (or no military actions left)
- (Optimize Queue)
- (Persistence)
- (Limited Simoultanous Mode)
- (Bonus Movement Points)
- (First Strike Bonus)

--]]


include("TutorialUIRoot_Expansion1.lua");
include("PopupDialog.lua");

-- Debugging
local singlePlayerTestingMode = true;

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


local function RefreshUI()
	local myRemainingActions = tbsm_RemainingMilitaryActions[Game.GetLocalPlayer()];
	Controls.TBSMRemainingActions:SetText( Locale.Lookup("LOC_TBSM_REMAINING_ACTIONS") .. ": " ..  tostring(myRemainingActions));
end


local function Initialize(playerID:number, isHisTurn:boolean)
	Verbose("Initialize PlayerID" .. playerID);
	tbsm_RemainingMilitaryActions[playerID] = isHisTurn and tbsm_Setting_MilitaryActionsPerTurn or 0;

	if playerID == Game.GetLocalPlayer() then
		RefreshUI();
	end
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
  initNextTbsmTurn(Game.GetLocalPlayer(), false); -- TODO: Fix runtime error
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

local function ForbidAllMilitaryActions()
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
			DisableUnitAction("UNITOPERATION_MOVE_TO_UNIT", unitType);
			DisableUnitAction("UNITOPERATION_AIR_ATTACK", unitType);
			DisableUnitAction("UNITOPERATION_COASTAL_RAID", unitType);
			DisableUnitAction("UNITOPERATION_WMD_STRIKE", unitType);
			DisableUnitAction("UNITOPERATION_UPGRADE", unitType); 
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

local function initNextTbsmTurn(actingPlayerID:number, isHisTurn:boolean)
	--local localPlayer = Game.GetLocalPlayer();
	local actingPlayer = Players[actingPlayerID];
	Verbose("PID: " .. actingPlayer:GetID());
	if actingPlayer:GetDiplomacy():IsAtWarWithHumans() or singlePlayerTestingMode then
	--if true then
		for i, pPlayer in ipairs(PlayerManager.GetAliveMajors()) do			
			local iPlayer :number = pPlayer:GetID();
			if (pPlayer:IsHuman() or singlePlayerTestingMode)
				and actingPlayer:GetDiplomacy():IsAtWarWith(iPlayer)
				--and (tbsm_RemainingMilitaryActions[iPlayer] == nil or tbsm_RemainingMilitaryActions[iPlayer] == 0)
			then
				Initialize(actingPlayerID, isHisTurn); -- Reset action counter
				Initialize(iPlayer, not isHisTurn);
			end
		end
	end
end

local function consumeIfMilitaryAction(playerID:number, unitID:number)
	pUnit = UnitManager.GetUnit(playerID, unitID);
	Verbose("isUnit " .. tostring(pUnit));
	Verbose("May consume Action of PlayerID " .. playerID);

	if (Players[playerID]:GetDiplomacy():IsAtWarWithHumans() or singlePlayerTestingMode) and unitIsMilitary(pUnit) and tbsm_RemainingMilitaryActions[playerID] ~= nil then
		Verbose("Consume Action");
		tbsm_RemainingMilitaryActions[playerID] = tbsm_RemainingMilitaryActions[playerID] - 1;

		if tbsm_RemainingMilitaryActions[playerID] <= 0 then
			initNextTbsmTurn(playerID, false);

			if Game.GetLocalPlayer() == playerID then
				RefreshUI();
				ForbidAllMilitaryActions();
			end
		end
	end
end


local function OnUnitMoved(playerID:number, unitID:number )
	Verbose("TBSM: OnUnitMoved " .. unitID);	

	consumeIfMilitaryAction(playerID, unitID);
end

function OnCombatVisBegin(combatMembers)	
	local attacker = combatMembers[0];
	Verbose("TBSM: OnCombatVisBegin " .. attacker.componentID);
	Verbose("Type " .. attacker.componentType);
	Verbose("Type Unit " .. ComponentType.UNIT);
	if attacker.componentType == ComponentType.UNIT then
		consumeIfMilitaryAction(attacker.playerID, attacker.componentID);	
	end
end

--[[
function OnUnitOperationStarted(ownerID:number, unitID:number, operationID:number)
	Verbose("TBSM: OnUnitOperationSegmentComplete " .. operationID);

	if operationID == UnitOperationTypes.MOVE_TO_UNIT or	   
	   operationID == UnitOperationTypes.RANGE_ATTACK or
	   operationID == UnitOperationTypes.AIR_ATTACK or
	   operationID == UnitOperationTypes.WMD_STRIKE or
	   operationID == UnitOperationTypes.COASTAL_RAID or
	   operationID == UnitOperationTypes.PILLAGE or	   
	   operationID == UnitOperationTypes.UPGRADE
	   -- TELEPORT_TO_CITY, DEPLOY, REBASE should may be covered by UnitMoved
	then
		consumeIfMilitaryAction();
	end	
end
--]]



-- Callback when we load into the game for the first time
local function OnLoadGameViewStateDone()
  --initNextTbsmTurn(Game.GetLocalPlayer()); -- TODO: Persistence
end

local function OnDiplomacyDeclareWar(actingPlayer, reactingPlayer)
  Verbose("TBSM: OnDiplomacyDeclareWar");
  --Initialize();
  initNextTbsmTurn(actingPlayer, true);
  AddButtonToTopPanel();  
  ContextPtr:SetHide(false);
end

--[[
local function OnUnitSelectionChanged()

end
--]]

----------------
-- Main Setup --
----------------

Events.LoadGameViewStateDone.Add(OnLoadGameViewStateDone);
Events.DiplomacyDeclareWar.Add(OnDiplomacyDeclareWar);
--Events.UnitSelectionChanged.Add(OnUnitSelectionChanged);
Events.CombatVisBegin.Add(OnCombatVisBegin);
--Events.UnitOperationStarted.Add(OnUnitOperationStarted);
ContextPtr:SetInputHandler(InputHandler, true);

Controls.TBSMNextTurnButton:RegisterCallback(Mouse.eLClick, OnTopPanelButtonClick);

ActivateInputFiltering();
EnableTutorialCheck();



Events.UnitMoved.Add(OnUnitMoved);

--Events.PlayerTurnActivated.Add(OnPlayerTurnActivated);

Verbose("End Initialization" );