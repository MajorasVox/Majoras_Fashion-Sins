---@alias VisualCreationData {ID:FixedString, Params:ClientMultiVisualAddVisualOptions}
---@alias EffectCreationData {Effect:FixedString, WeaponBones:string}
---@alias VisualSettingsData {ID:string, CanCreate:(fun(character:EclCharacter, params:EclEquipmentVisualSystemSetParam):boolean)|nil, Visuals:VisualCreationData[], Effects:EffectCreationData[], CanDelete:(fun(character:EclCharacter, params:EclEquipmentVisualSystemSetParam):boolean)|nil}
---@alias CharacterVisualRootData {ID:string, Require:{VisualTemplate:FixedString|nil}|nil, Visuals:VisualSettingsData[]}

---@type table<NETID, table<string, table<string, ComponentHandle>>>
local _CreatedHandlers = {}

local function _HelmetIsHidden(character)
	if not character.PlayerData then
		return false
	end
	return character.PlayerData.HelmetOptionState == false
end


local VisualSettings = {
	{
		ID = "ElfFemaleExtras",
		Require = {
			VisualTemplate = "466d39b0-519d-4e00-809b-2da4ee3dbfc4", -- Elf Female Hero Base
		},
		Visuals = {
			{
				ID = "TentacleHeadThing",
				---@param character EclCharacter
				---@param params EclEquipmentVisualSystemSetParam
				CanCreate = function(character, params)
					return params.VisualResourceID == "af0f09bf-3960-4392-bacb-9b8af45c633e" --	and not _HelmetIsHidden(character)
				end,
				---@param character EclCharacter
				---@param params EclEquipmentVisualSystemSetParam
				CanDelete = function(character, params)
					--Only delete the visual if the requested equipment slot is the chest slot
					return params.Slot == "Breast"
				end,
				Visuals = {
					{
						ID = "b140d1aa-2694-4644-aca8-6f7d64b09da9",
						Params = {
							Bone = "Head_Bone",
							Armor = true,
							SyncAnimationWithParent = true,
							InheritAnimations = true,
						},
					}
				},
			}
		}
	}
}

---@param character EclCharacter
---@param requirements table<string,any>
local function _RequirementsMet(character, requirements)
	if requirements == nil then
		return true
	end
	for k,v in pairs(requirements) do
		if character.CurrentTemplate[k] ~= v then
			return false
		end
	end
	return true
end

local function _DeleteHandlers(tbl)
	for id,handlerID in pairs(tbl) do
		local handler = Ext.Visual.Get(handlerID)
		if handler then
			handler:Delete()
		end
	end
end

local function _TableHasEntry(tbl)
	for _,v in pairs(tbl) do
		return true
	end
	return false
end

---@param character EclCharacter
---@param data VisualSettingsData
---@param creationParams EclEquipmentVisualSystemSetParam
local function _CanDelete(character, data, creationParams)
	if data.CanDelete then
		return data.CanDelete(character, creationParams)
	end
	return true
end

---@param character EclCharacter
---@param data VisualSettingsData
---@param handlers table<string, ComponentHandle>
---@param creationParams EclEquipmentVisualSystemSetParam
local function _ProcessVisualSettings(character, data, handlers, creationParams)
	local addedVisual = false
	local handler = nil
	local handlerID = handlers[data.ID]
	if handlerID then
		handler = Ext.Visual.Get(handlerID)
	end
	if data.CanCreate(character, creationParams) then
		if not handler then
			handler = Ext.Visual.CreateOnCharacter(character.Translate, character, character)
			if data.Visuals then
				for _,v in pairs(data.Visuals) do
					handler:AddVisual(v.ID, v.Params or {})
					addedVisual = true
				end
			end
			if data.Effects then
				for _,v in pairs(data.Effects) do
					handler:ParseFromStats(v.Effect, v.WeaponBones or "")
					addedVisual = true
				end
			end
			handlers[data.ID] = handler.Handle
		end
	elseif handler and _CanDelete(character, data, creationParams) then
		handler:Delete()
		handlers[data.ID] = nil
	end
	return addedVisual
end

---@param character EclCharacter
---@param data CharacterVisualRootData
---@param allHandlers table<string, table<string, ComponentHandle>>
---@param creationParams EclEquipmentVisualSystemSetParam
local function _ProcessCharacterSettings(character, data, allHandlers, creationParams)
	local addedVisual = false
	local handlers = allHandlers[data.ID] or {}
	if _RequirementsMet(character, data.Require) then
		for _,visualSettings in pairs(data.Visuals) do
			if _ProcessVisualSettings(character, visualSettings, handlers, creationParams) then
				addedVisual = true
			end
		end
		if addedVisual then
			allHandlers[data.ID] = handlers
		end
	elseif handlers then
		_DeleteHandlers(handlers)
		allHandlers[data.ID] = nil
	end
	return addedVisual
end

Ext.Events.CreateEquipmentVisualsRequest:Subscribe(function (e)
	local character = e.Character
	if not character then
		return
	end
	local creationParams = e.Params
	for _,data in pairs(VisualSettings) do
		local allHandlers = _CreatedHandlers[e.Character.NetID] or {}
		if _ProcessCharacterSettings(character, data, allHandlers, creationParams) then
			_CreatedHandlers[e.Character.NetID] = allHandlers
		elseif not _TableHasEntry(allHandlers) then
			_CreatedHandlers[e.Character.NetID] = nil
		end
	end
end)

if Mods.LeaderLib then
	Mods.LeaderLib.Events.BeforeLuaReset:Subscribe(function (e)
		for netid,allHandlers in pairs(_CreatedHandlers) do
			for id,handlers in pairs(allHandlers) do
				_DeleteHandlers(handlers)
			end
		end
	end)
end