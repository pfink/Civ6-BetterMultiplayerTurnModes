--[[
TODOs:

- Menu Configuration
- Declare War: Clean Turn Queue Update
- Testing

- ... (or no military actions left)
- (let attacker start war)
- (Restrict Units based on GameInfo.Units)
- (Allies)
- (Optimize Queue)
- (Persistence)
- (Limited Simoultanous Mode)
- (Bonus Movement Points)
- (First Strike Bonus)


DONE
- Give unlimited actions when oponent has ended turn
- Initial Loading (Randomized)
- Triangle Wars
- Switch beginning player each Civ turn
- Re-enable military actions when count goes > 0
- Continue button
- Peace
--]]


include("TutorialUIRoot.lua");
include("PopupDialog.lua");

-- Debugging
local singlePlayerTestingMode = true and not GameConfiguration.IsAnyMultiplayer();

-- Settings
local bmtm_Setting_MilitaryActionsPerTurn = 1;
local bmtm_Setting_AttackerFirstStrikeBonusFactor = 2;
local bmtm_Setting_MovementActionsPerTurn = 0;
local bmtm_Setting_RotatoryMode = true;
local bmtm_Setting_MilitaryActionsForMovementAllowed = true;

-- State
local bmtm_RemainingMilitaryActions = {}; -- Table: PlayerID -> RemainingMilitaryActions
local bmtm_RemainingMovementActions = {}; -- Table: PlayerID -> RemainingMovementActions
local bmtm_WarParticipants = {};		  -- Table: bmtmWarParticipantID -> PlayerID (contains players that are in war with local player + transitively/recursively all players who are in war with those players)
local bmtm_WarParticipantsQueueIndex :number = 0;

local function Verbose(message)
   print(message);
end

Verbose("Start Initialization");


local function RefreshUI()
	local myRemainingActions = bmtm_RemainingMilitaryActions[Game.GetLocalPlayer()];
	if myRemainingActions > 0 then
		Controls.BMTMRemainingActions:SetText( Locale.Lookup("LOC_BMTM_REMAINING_ACTIONS") .. ": " ..  tostring(myRemainingActions));
		Controls.BMTMNextTurnButton_Stack:SetHide(false);
	else
		Controls.BMTMRemainingActions:SetText( Locale.Lookup("LOC_BMTM_NOT_YOUR_TURN") );
		Controls.BMTMNextTurnButton_Stack:SetHide(true);
	end
end

-----------------
-- Utility --
-----------------


function table_contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

-----------------
-- UI Mutators --
-----------------


local function initTbsmUI()
  Verbose("BMTM: AddButtonToTopPanel");

  local topPanel = ContextPtr:LookUpControl("/InGame/TopPanel/RightContents"); -- Top-right stack with Clock, Civilopedia, and Menu  
  Controls.BmtmSection:ChangeParent(topPanel);
  topPanel:AddChildAtIndex(Controls.BmtmSection, 5); -- Insert left to the clock
  topPanel:CalculateSize();
  topPanel:ReprocessAnchoring();  
end

local function ShowTbsmUI()
  Controls.BmtmSection:SetHide(false);
end

local function HideTbsmUI()
  Controls.BmtmSection:SetHide(true);
end


local function ShowDialog()
  Verbose("BMTM: ShowDialog");
  local m_kPopupDialog:table = PopupDialogInGame:new( "BMTMPrompt" );
  m_kPopupDialog:AddTitle(Locale.Lookup("LOC_BMTM_ACTION_NOT_POSSIBLE_DIALOG_TITLE"));
  m_kPopupDialog:AddText(Locale.Lookup("LOC_BMTM_ACTION_NOT_POSSIBLE_DIALOG_TEXT"));
  m_kPopupDialog:AddConfirmButton(Locale.Lookup("LOC_OK_BUTTON"), function()

  end );
  m_kPopupDialog:Open();
end
---------------
-- Callbacks --
---------------

local function isAtWarWithHumans(playerID:number)
	return Players[playerID]:GetDiplomacy():IsAtWarWithHumans() 
	or singlePlayerTestingMode;
end

local function unitIsMilitary(unit)
	--Verbose("Attacks remaining: " .. unit:GetAttacksRemaining());
	--Verbose("Combat: " .. unit:GetCombat());
	--Verbose("RangedCombat: " .. unit:GetRangedCombat());
	--Verbose("BombardCombat: " .. unit:GetBombardCombat());
	--Verbose("AntiAirCombat: " .. unit:GetAntiAirCombat());
	--Verbose("isCannotAttack: " .. tostring(unit:IsCannotAttack()));
	return unit:GetCombat() > 0 or unit:GetRangedCombat() > 0 or unit:GetBombardCombat() > 0 or unit:GetAntiAirCombat() > 0; -- A bit glitchy, but the most efficient way I know to find out all military unit types; units with no attacks remaining don't have to be blocked because they have no action left anyway
end

local function ForbidAllMilitaryActions()
	Verbose("Forbid Military actions");
	local localPlayer = Game.GetLocalPlayer();
	local playerUnits = Players[localPlayer]:GetUnits();
	for i, unit in playerUnits:Members() do
		local unitType:string = GameInfo.Units[unit:GetUnitType()].UnitType;
		--local unitTypeName = UnitManager.GetTypeName(unit);
		--Verbose("Unit Type:  " .. unitType);		
		if unitIsMilitary(unit) then 
			LuaEvents.Tutorial_AddUnitHexRestriction(unitType, {});
			AddMapUnitMoveRestriction(unitType);
			DisableUnitAction("UNITOPERATION_MOVE_TO", unitType);
			DisableUnitAction("UNITOPERATION_MOVE_TO_UNIT", unitType);
			DisableUnitAction("UNITOPERATION_AIR_ATTACK", unitType);
			DisableUnitAction("UNITOPERATION_COASTAL_RAID", unitType);
			DisableUnitAction("UNITOPERATION_WMD_STRIKE", unitType);
			DisableUnitAction("UNITOPERATION_UPGRADE", unitType);
			DisableUnitAction("UNITOPERATION_EMBARK", unitType);
			DisableUnitAction("UNITOPERATION_DISEMBARK", unitType); 
		end
	end
end

local function AllowAllMilitaryActions()
	Verbose("Allow Military actions");
	local localPlayer = Game.GetLocalPlayer();	
	local playerUnits = Players[localPlayer]:GetUnits();
	for i, unit in playerUnits:Members() do
		local unitType:string = GameInfo.Units[unit:GetUnitType()].UnitType;
		if unitIsMilitary(unit) then 
			LuaEvents.Tutorial_AddUnitHexRestriction(unitType, {});
			RemoveMapUnitMoveRestriction(unitType);
			EnableUnitAction("UNITOPERATION_MOVE_TO", unitType);
			EnableUnitAction("UNITOPERATION_MOVE_TO_UNIT", unitType);
			EnableUnitAction("UNITOPERATION_AIR_ATTACK", unitType);
			EnableUnitAction("UNITOPERATION_COASTAL_RAID", unitType);
			EnableUnitAction("UNITOPERATION_WMD_STRIKE", unitType);
			EnableUnitAction("UNITOPERATION_UPGRADE", unitType);
			EnableUnitAction("UNITOPERATION_EMBARK", unitType);
			EnableUnitAction("UNITOPERATION_DISEMBARK", unitType); 
		end
	end
end

local function Initialize(playerID:number, isHisTurn:boolean)
	Verbose("Initialize PlayerID" .. playerID);
	bmtm_RemainingMilitaryActions[playerID] = isHisTurn and bmtm_Setting_MilitaryActionsPerTurn or 0;

	if playerID == Game.GetLocalPlayer() then
		RefreshUI();
		if isHisTurn then
			AllowAllMilitaryActions();
		else
			ForbidAllMilitaryActions();
		end
	end
end


local function initNextTbsmTurn()
	Verbose("Init next BMTM turn. Queue Index before:" .. bmtm_WarParticipantsQueueIndex);
	local i = 0;
	Verbose(bmtm_WarParticipants[bmtm_WarParticipantsQueueIndex+1]);
	Verbose(Players[bmtm_WarParticipants[bmtm_WarParticipantsQueueIndex+1]]);
	Verbose(Players[bmtm_WarParticipants[bmtm_WarParticipantsQueueIndex+1]]:IsHuman());
	Verbose(Players[bmtm_WarParticipants[bmtm_WarParticipantsQueueIndex+1]]:IsTurnActive());
	-- Skip players who have ended their turn
	while not Players[bmtm_WarParticipants[bmtm_WarParticipantsQueueIndex+1]]:IsTurnActive()
		  and Players[bmtm_WarParticipants[bmtm_WarParticipantsQueueIndex+1]]:IsHuman()
		  and i <= #bmtm_WarParticipants do
		bmtm_WarParticipantsQueueIndex = (bmtm_WarParticipantsQueueIndex + 1) % #bmtm_WarParticipants;
		i = i + 1;	
	end
	-- Initialize next BMTM turn
	for i, iPlayer in ipairs(bmtm_WarParticipants) do
		Verbose("War Participant ID:" .. i);
		Initialize(iPlayer, (i-1) == bmtm_WarParticipantsQueueIndex); -- Lua table index begins at 1, that's why we have to substract		
	end	
	bmtm_WarParticipantsQueueIndex = (bmtm_WarParticipantsQueueIndex + 1) % #bmtm_WarParticipants;
	Verbose("Queue Index after:" .. bmtm_WarParticipantsQueueIndex);
end

local function initNextCivTurn()
	--Game.GetLocalPlayer()
	if isAtWarWithHumans(Game.GetLocalPlayer()) then
		bmtm_WarParticipantsQueueIndex = Game.GetCurrentGameTurn() % #bmtm_WarParticipants;
		initNextTbsmTurn();
	end
end

local function consumeIfMilitaryAction(playerID:number, unitID:number)
	pUnit = UnitManager.GetUnit(playerID, unitID);
	Verbose("isUnit " .. tostring(pUnit));
	Verbose("May consume Action of PlayerID " .. playerID);

	if isAtWarWithHumans(playerID) and unitIsMilitary(pUnit) and bmtm_RemainingMilitaryActions[playerID] ~= nil then
		Verbose("Consume Action");
		bmtm_RemainingMilitaryActions[playerID] = bmtm_RemainingMilitaryActions[playerID] - 1;

		if bmtm_RemainingMilitaryActions[playerID] == 0 then -- bmtm_RemainingMilitaryActions[playerID] <= 0 causes issues because sometimes one action calls the callback multiple times which will cause multiple turn changes. Anyhow, later on there could may be extra handling for values < 0 for safe fallback
			initNextTbsmTurn(); --(playerID, false);
		end
	end
end

local function addWarParticipantsRecursive(actingPlayer:number)
	if not table_contains(bmtm_WarParticipants, actingPlayer) then
		table.insert(bmtm_WarParticipants, actingPlayer);
		Verbose("War Participant added: " .. actingPlayer);
				
		for i, pPlayer in ipairs(PlayerManager.GetAliveMajors()) do
			local iPlayer :number = pPlayer:GetID();
			if (pPlayer:IsHuman() or singlePlayerTestingMode)
			    and pPlayer:GetDiplomacy():IsAtWarWith(actingPlayer) then
				
				addWarParticipantsRecursive(iPlayer);				
			end
		end
	end	
end

local function initWarParticipants()
	bmtm_WarParticipants = {};

	local localPlayer = Game.GetLocalPlayer();
	if isAtWarWithHumans(localPlayer) or singlePlayerTestingMode then
		addWarParticipantsRecursive(localPlayer);
		table.sort(bmtm_WarParticipants);
	end
end

-- The top panel button next to the CivPedia
local function OnTopPanelButtonClick()
  Verbose("BMTM: OnTopPanelButtonClick");
  if bmtm_RemainingMilitaryActions[Game.GetLocalPlayer()] > 0 then
	for i, iPlayer in ipairs(bmtm_WarParticipants) do
		if iPlayer ~= Game.GetLocalPlayer() then
			Network.SendChat(".bmtm_next_player", -2, iPlayer);
		end
		initNextTbsmTurn();
	end
  end
  --ShowDialog();
end

local function OnUnitMoved(playerID:number, unitID:number )
	Verbose("BMTM: OnUnitMoved " .. unitID);
	consumeIfMilitaryAction(playerID, unitID);
end

function OnCombatVisBegin(combatMembers)	
	local attacker = combatMembers[0];
	Verbose("BMTM: OnCombatVisBegin " .. attacker.componentID);
	Verbose("Type " .. attacker.componentType);
	Verbose("Type Unit " .. ComponentType.UNIT);
	if attacker.componentType == ComponentType.UNIT then
		consumeIfMilitaryAction(attacker.playerID, attacker.componentID);	
	end
end

-- Callback when we load into the game for the first time
local function OnLoadGameViewStateDone()
	initTbsmUI();
	initWarParticipants();
	Verbose("BMTM: War Participant Count " .. #bmtm_WarParticipants);
	if #bmtm_WarParticipants > 0 then
		initNextCivTurn(); -- TODO: Persistence
		ShowTbsmUI();
		ContextPtr:SetHide(false);
	else
		HideTbsmUI();
	end
end

local function isRelevantWar(actingPlayer:number, reactingPlayer:number)
	localPlayer = Game.GetLocalPlayer();
	return
		(
		Players[actingPlayer]:IsHuman() and Players[reactingPlayer]:IsHuman() or singlePlayerTestingMode
		)
		and
		(
		actingPlayer == localPlayer or reactingPlayer == localPlayer
		or table_contains(bmtm_WarParticipants, actingPlayer)
		or table_contains(bmtm_WarParticipants, reactingPlayer)
		);
end

local function OnDiplomacyDeclareWar(actingPlayer:number, reactingPlayer:number)
  Verbose("BMTM: OnDiplomacyDeclareWar");  
  if isRelevantWar(actingPlayer, reactingPlayer) then
	initWarParticipants();
	initNextTbsmTurn(); --(actingPlayer, true);
	ShowTbsmUI();
	ContextPtr:SetHide(false);
  end
  
end

local function OnDiplomacyMakePeace(actingPlayer:number, reactingPlayer:number)
	if isRelevantWar(actingPlayer, reactingPlayer) then
		initWarParticipants();
	end
	if not isAtWarWithHumans(Game.GetLocalPlayer()) then
		AllowAllMilitaryActions();
		HideTbsmUI();
	end	
end

local function OnTurnBegin()
	initNextCivTurn();
end

function OnPlayerTurnDeactivated( iPlayer:number )
	if isAtWarWithHumans(Game.GetLocalPlayer()) and bmtm_RemainingMilitaryActions[iPlayer] > 0 then
		initNextTbsmTurn();
	end
end

local function OnMultiplayerChat(fromPlayer, toPlayer, text, eTargetType)
	Verbose("Next turn initialized manuallly" .. fromPlayer);
	if string.lower(text) == ".bmtm_next_player" and bmtm_RemainingMilitaryActions[fromPlayer] > 0 then
		initNextTbsmTurn();
	end
end

----------------
-- Main Setup --
----------------

Events.LoadGameViewStateDone.Add(OnLoadGameViewStateDone);
Events.DiplomacyDeclareWar.Add(OnDiplomacyDeclareWar);
Events.DiplomacyMakePeace.Add(OnDiplomacyMakePeace);
Events.TurnBegin.Add(OnTurnBegin);
Events.PlayerTurnDeactivated.Add(OnPlayerTurnDeactivated);

--Events.UnitSelectionChanged.Add(OnUnitSelectionChanged);
Events.CombatVisBegin.Add(OnCombatVisBegin);
Events.MultiplayerChat.Add(OnMultiplayerChat);
--Events.UnitOperationStarted.Add(OnUnitOperationStarted);

--LuaEvents.TbsmNextTurnInitializedManually.Add(OnTbsmNextTurnInitializedManually)
ContextPtr:SetInputHandler(InputHandler, true);

Controls.BMTMNextTurnButton:RegisterCallback(Mouse.eLClick, OnTopPanelButtonClick);

ActivateInputFiltering();
EnableTutorialCheck();



Events.UnitMoved.Add(OnUnitMoved);

--Events.PlayerTurnActivated.Add(OnPlayerTurnActivated);

Verbose("End Initialization" );


-----------------
-- Archived Stuff --
-----------------

--[[
function OnUnitOperationStarted(ownerID:number, unitID:number, operationID:number)
	Verbose("BMTM: OnUnitOperationSegmentComplete " .. operationID);

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

		--DisableUnitAction( "UNITCOMMAND_AUTOMATE", unitType );
		--DisableUnitAction( "UNITOPERATION_AUTOMATE_EXPLORE", unitType );
		--DisableUnitAction( "UNITOPERATION_SKIP_TURN", unitType );
		--DisableUnitAction( "UNITOPERATION_FORTIFY", unitType);
		--DisableUnitAction( "UNITOPERATION_HEAL",	unitType);
		--DisableUnitAction( "UNITCOMMAND_CANCEL",	unitType);
		--DisableUnitAction( "UNITOPERATION_SLEEP",	unitType);


		--EnableUnitAction( "UNITCOMMAND_AUTOMATE", unitType );
		--EnableUnitAction( "UNITOPERATION_AUTOMATE_EXPLORE", unitType );
		--EnableUnitAction( "UNITOPERATION_SKIP_TURN", unitType );
		--EnableUnitAction( "UNITOPERATION_FORTIFY", unitType);
		--EnableUnitAction( "UNITOPERATION_HEAL",	unitType);
		--EnableUnitAction( "UNITCOMMAND_CANCEL",	unitType);
		--EnableUnitAction( "UNITOPERATION_SLEEP",	unitType);