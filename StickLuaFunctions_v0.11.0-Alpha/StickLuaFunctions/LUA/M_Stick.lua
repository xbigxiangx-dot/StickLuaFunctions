-- 确保在LuaJIT环境下，位操作指令的兼容性
local bit = bit32 or require("bit")
if not bit32 and bit then
    bit32 = {
        band = bit.band,
        bor = bit.bor,
        bnot = bit.bnot,
        bxor = bit.bxor,
        lshift = bit.lshift,
        rshift = bit.rshift,
    }
    function bit32.extract(n, field, width)
		field = field or 1
        width = width or 1
        return bit.band(bit.rshift(n, field), bit.lshift(1, width) - 1)
    end
end

local versionHookAddress = EEex_Label("Hook-CAIGroup::IsPartyLeader()-Override")
if versionHookAddress == 0x14011ABFA then
	st_GameVersion = "2.6"
elseif versionHookAddress == 0x14011AC1A then
	st_GameVersion = "2.7"
else
	error(string.format(
		"M_Stick: unsupported game version, version hook address = 0x%X",
		versionHookAddress
	))
end

local st_EngineAddress27 = {
	[0x14039D837] = 0x14039DE77,
	[0x14039D840] = 0x14039DE80,
	[0x14039D9A3] = 0x14039DFE3,
	[0x1403B9547] = 0x1403B9B87,
	[0x1403B8439] = 0x1403B8A79,
	[0x14039DAD5] = 0x14039E115,
	[0x14039DFF4] = 0x14039E634,
	[0x14038FEF0] = 0x140390530,
	[0x14039E583] = 0x14039EBC3,
	[0x14039E618] = 0x14039EC58,
	[0x140390C72] = 0x1403912B2,
	[0x1402633E1] = 0x140263641,
	[0x140264B8F] = 0x140264DEF,
	[0x14034C97D] = 0x14034CFBD,
	[0x140390605] = 0x140390C45,
	[0x1403906B0] = 0x140390CF0,
	[0x1403906D2] = 0x140390D12,
	[0x1403906D8] = 0x140390D18,
	[0x140390748] = 0x140390D88,
	[0x140390790] = 0x140390DD0,
	[0x140390794] = 0x140390DD4,
	[0x1403909B8] = 0x140390FF8,
	[0x1403909B3] = 0x140390FF3,
	[0x1405EA41D] = 0x1405EB7AD,
	[0x14039074F] = 0x140390D8F,
	[0x1403907A3] = 0x140390DE3,
	[0x14024ED06] = 0x14024EF66,
	[0x1401FB2F2] = 0x1401FB552,
	[0x1401CD64B] = 0x1401CD85B,
	[0x1402B8C7A] = 0x1402B92FA,
	[0x1402C75C1] = 0x1402C7C41,
	[0x1402BDC31] = 0x1402BE2B1,
	[0x14039E8AF] = 0x14039EEEF,
}

function ST_RegisterEngineAddress(address26, address27)
	local registeredAddress = st_EngineAddress27[address26]
	if registeredAddress and registeredAddress ~= address27 then
		error(string.format("M_Stick: conflicting 2.7 address for 0x%X", address26))
	end
	st_EngineAddress27[address26] = address27
end

function ST_GetEngineAddress(address26)
	if st_GameVersion == "2.6" then
		return address26
	end

	local address27 = st_EngineAddress27[address26]
	if not address27 then
		error(string.format("M_Stick: missing 2.7 address for 0x%X", address26))
	end
	return address27
end

EEex_DefineAssemblyLabel("ST_HideInPlainSight_Continue", ST_GetEngineAddress(0x14039D840))
EEex_DefineAssemblyLabel("ST_HideInPlainSight_Fail", ST_GetEngineAddress(0x14039D9A3))
EEex_DefineAssemblyLabel("ST_BackstabPosition_Continue", ST_GetEngineAddress(0x1403906D8))
EEex_DefineAssemblyLabel("ST_BackstabTargetImmune_Continue", ST_GetEngineAddress(0x140390790))
EEex_DefineAssemblyLabel("ST_BackstabInvisibilityInvalid", ST_GetEngineAddress(0x1403909B8))
EEex_DefineAssemblyLabel("ST_BackstabPositionInvalid", ST_GetEngineAddress(0x1403909B3))
EEex_DefineAssemblyLabel("ST_BackstabTargetImmune_String", ST_GetEngineAddress(0x1405EA41D))
EEex_DefineAssemblyLabel("ST_BackstabTargetImmune", ST_GetEngineAddress(0x14039074F))

--[[
+----------+
| 通用函数 |
+----------+
--]]
function ST_GetSprite(spriteOrId)
	if type(spriteOrId) == "number" then
		return EEex_GameObject_Get(spriteOrId)
	end
	return spriteOrId
end

function ST_Read_i32(x)
    return (x >= 0x80000000) and (x - 0x100000000) or x
end

function ST_GetResRef(m_resRef)
	local chars = ""
	for i = 0, 7 do
		if m_resRef:get(i) ~= 0 then
			chars = chars .. string.char(m_resRef:get(i))
		end
	end
	return chars
end

function ST_SetResRef(m_resRef, resRef)
	resRef = resRef or ""
	for i = 0, 7 do
		m_resRef:set(i, string.byte(resRef, i + 1) or 0)
	end
end

function ST_MatchIds(sprite, idsIndex, idsValue)
	local ST_IdsIndexToSpriteField = {
		[2] = function(sprite) return sprite.m_typeAI.m_EnemyAlly end,
		[3] = function(sprite) return sprite.m_typeAI.m_General end,
		[4] = function(sprite) return sprite.m_typeAI.m_Race end,
		[5] = function(sprite) return sprite.m_typeAI.m_Class end,
		[6] = function(sprite) return sprite.m_typeAI.m_Specifics end,
		[7] = function(sprite) return sprite.m_typeAI.m_Gender end,
		[8] = function(sprite) return sprite.m_typeAI.m_Alignment end,
	}
	
	if idsIndex == 9 then
		return ST_MatchKitId(sprite, idsValue)
	end

	local getter = ST_IdsIndexToSpriteField[idsIndex]
	if not getter then
		return false
	end

	local spriteValue = getter(sprite)

	if idsIndex == 8 then
		if idsValue == 0x00 then
			return spriteValue == 0x00
		end

		local isMask =
			idsValue == 0x01 or idsValue == 0x02 or idsValue == 0x03 or
			idsValue == 0x10 or idsValue == 0x20 or idsValue == 0x30

		if isMask then
			return bit32.band(spriteValue, idsValue) == idsValue
		end
	end
	
	return spriteValue == idsValue
end

-- 额外kitId读写
function ST_SetExKitId(sprite, exKitIndex, kitId)
	local variablePrefix = "ST_ExKit" .. tostring(exKitIndex)
	local high = EEex_RShift(kitId, 16)
	local low = EEex_BAnd(kitId, 0xFFFF)

	EEex_Sprite_SetLocalInt(sprite, variablePrefix .. "_HIGH", high)
	EEex_Sprite_SetLocalInt(sprite, variablePrefix .. "_LOW", low)
end

function ST_GetExKitId(sprite, exKitIndex)
	local variablePrefix = "ST_ExKit" .. tostring(exKitIndex)
	local high = EEex_Sprite_GetLocalInt(sprite, variablePrefix .. "_HIGH")
	local low = EEex_Sprite_GetLocalInt(sprite, variablePrefix .. "_LOW")

	return EEex_BOr(EEex_LShift(high, 16), EEex_BAnd(low, 0xFFFF))
end

-- 检测是否具有任何符合输入的kitId
function ST_MatchKitId(sprite, kitId)
    return
        kitId == sprite.m_derivedStats.m_nKit or
        kitId == ST_GetExKitId(sprite, 1) or
        kitId == ST_GetExKitId(sprite, 2)
end

-- 读取所有kitId为表格
function ST_GetAllKitIds(sprite, includeGeneralist)
	includeGeneralist = includeGeneralist or false

	local allKitIds = {}

	local kitId = sprite.m_derivedStats.m_nKit
	if kitId ~= 0 and (includeGeneralist or kitId ~= 0x4000) then
		table.insert(allKitIds, kitId)
	end

	kitId = ST_GetExKitId(sprite, 1)
	if kitId ~= 0 and (includeGeneralist or kitId ~= 0x4000) then
		table.insert(allKitIds, kitId)
	end

	kitId = ST_GetExKitId(sprite, 2)
	if kitId ~= 0 and (includeGeneralist or kitId ~= 0x4000) then
		table.insert(allKitIds, kitId)
	end

	return allKitIds
end

--[[
+-------------+
| 加载2da列表 |
+-------------+
--]]
local strMod_2DA = EEex_Resource_Load2DA('STRMOD')
local strModEx_2DA = EEex_Resource_Load2DA('STRMODEX')

--[[
+--------------+
| 读取当前武器 |
+--------------+
--]]
function ST_GetCurrentWeapon(sprite, getCurrentAttack)
	local leftAttackCount = sprite.m_leftAttack
	
	local isTwoHanded = false
	local isLeftAttack = false
	
	local fightingStyle = nil	-- 1 单手，2 双手，3 剑盾，4 双手
		
	local equipmentArray = sprite.m_equipment.m_items	-- 读取装备序列
	-- 读取主手物品
	local rightHandItem = equipmentArray:get(sprite.m_equipment.m_selectedWeapon)	-- 当前主手武器
	local rightHandItemRes = nil
	if rightHandItem then
		local rightHandItemName = rightHandItem.cResRef:get()
		rightHandItemRes = EEex_Resource_Fetch(rightHandItemName, "ITM")
		local rightHandItemFlags = rightHandItemRes.pHeader.itemFlags
		local weaponProficiencyIndex = rightHandItemRes.pHeader.proficiencyType
		if bit32.extract(rightHandItemFlags, 1) == 1 then	-- Two-handed flag
			isTwoHanded = true
			fightingStyle = 2
		elseif (weaponProficiencyIndex >= 89 and weaponProficiencyIndex <= 108) or (weaponProficiencyIndex >= 111 and weaponProficiencyIndex <= 115) then	-- 限制物品种类
			fightingStyle = 1
		end
	end
		
	-- 读取副手物品
	local leftHandItem = equipmentArray:get(9)
	local leftHandItemRes = nil
	if leftHandItem then
		local leftHandItemResName = leftHandItem.cResRef:get()
		leftHandItemRes = EEex_Resource_Fetch(leftHandItemResName, "ITM")
		if leftHandItemRes.pHeader.itemType ~= 12 then	-- 副手不是盾牌
			fightingStyle = 4
		elseif not isTwoHanded then	-- 副手是盾牌且主手不是双手武器
			fightingStyle = 3
		end
	end
	
	-- 判断当前攻击是否为副手攻击
	if (leftAttackCount == 1) and (fightingStyle == 4) then
		isLeftAttack = true
	end
	
	local weapon1Res = rightHandItemRes
	local weapon2Res = leftHandItemRes
	
	if getCurrentAttack and isLeftAttack then
		weapon1Res = leftHandItemRes
	end
	
	if getCurrentAttack then
		return weapon1Res, fightingStyle, isLeftAttack
	else
		return weapon1Res, weapon2Res, fightingStyle, isLeftAttack
	end
end
--[[
+------------  --+
| 读取武器熟练度 |
+---------  -----+
--]]
function ST_GetWeaponProficiency(sprite, statsIndex)
	local weaponProficiency1 = 0
	local weaponProficiency2 = 0
	if (statsIndex >= 89 and statsIndex <= 108) or (statsIndex >= 111 and statsIndex <= 115) then
		local weaponProficiency = EEex_Sprite_GetStat(sprite, statsIndex)
		weaponProficiency1 = bit32.band(weaponProficiency, 0x0F)
		weaponProficiency2 = bit32.rshift(bit32.band(weaponProficiency, 0xF0), 4)
	end
	-- if statsIndex < 89 or (statsIndex > 108 and statsIndex < 111) or statsIndex > 115 then
		-- error("statsIndex "..statsIndex.." 不在允许范围内")
	-- end

	return math.max(weaponProficiency1, weaponProficiency2)
end
--[[
+-----------+
| 读取state |
+-----------+
--]]
function ST_HasState(sprite, state)
	local stateMaskMap = {
		STATE_SLEEPING = 0x00000001,
		STATE_BERSERK = 0x00000002,
		STATE_PANIC = 0x00000004,
		STATE_STUNNED = 0x00000008,
		STATE_INVISIBLE = 0x00000010,
		STATE_HELPLESS = 0x00000020,

		STATE_IMMOBILE = 0x00000029,        -- 组合状态

		STATE_FROZEN_DEATH = 0x00000040,
		STATE_STONE_DEATH = 0x00000080,
		STATE_EXPLODING_DEATH = 0x00000100,
		STATE_FLAME_DEATH = 0x00000200,
		STATE_ACID_DEATH = 0x00000400,
		STATE_DEAD = 0x00000800,

		STATE_REALLY_DEAD = 0x00000FC0,     -- 组合状态

		STATE_SILENCED = 0x00001000,
		STATE_CHARMED = 0x00002000,
		STATE_POISONED = 0x00004000,
		STATE_HASTED = 0x00008000,
		STATE_SLOWED = 0x00010000,
		STATE_INFRAVISION = 0x00020000,
		STATE_BLIND = 0x00040000,
		STATE_DISEASED = 0x00080000,

		STATE_FEEBLEMINDED = 0x00100000,

		STATE_HARMLESS = 0x00102029,        -- 组合状态

		STATE_NONDETECTION = 0x00200000,
		STATE_IMPROVEDINVISIBILITY = 0x00400000,
		STATE_NOT_TARGETABLE = 0x00400010,  -- 组合状态

		STATE_BLESS = 0x00800000,
		STATE_CHANT = 0x01000000,
		STATE_DRAWUPONHOLYMIGHT = 0x02000000,
		STATE_LUCK = 0x04000000,
		STATE_AID = 0x08000000,
		STATE_CHANTBAD = 0x10000000,
		STATE_BLUR = 0x20000000,
		STATE_MIRRORIMAGE = 0x40000000,

		STATE_ILLUSIONS = 0x60400010,       -- 组合状态

		STATE_CONFUSED = 0x80000000,
	}
	
	if type(state) == 'string' then
		state = stateMaskMap[state] or stateMaskMap["STATE_" .. state] or 0x0	-- 输入参数可以是state名字符串（带不带STATE_前缀都可），也可以是bit mask。字符串无对应时视为0x0
	end

	local stateBits = sprite.m_derivedStats.m_generalState
	
	return bit32.band(stateBits, state) ~= 0
end

--[[
+--------------+
| 模拟物理攻击 |
+--------------+
--]]
function ST_MockAttack(sourceSprite, targetSprite, weaponRes, isLeftAttack, abilityIndex)
	-- 武器数据
	if not weaponRes then
		if not isLeftAttack then
			weaponRes = ST_GetCurrentWeapon(sourceSprite)
		else
			_, weaponRes = ST_GetCurrentWeapon(sourceSprite)
		end
	end
	
	abilityIndex = abilityIndex or sourceSprite.m_equipment.m_selectedWeaponAbility	-- 默认使用当前选择的 ability
	local address =  EEex_UDToPtr(weaponRes.pAbilities) + 0x38 * abilityIndex
	local ability = EEex_PtrToUD(address, "Item_ability_st")

	local itemFlags = weaponRes.pHeader.itemFlags
	local isMagical = bit32.extract(itemFlags, 6) == 1
	local enchantment = weaponRes.pHeader.attributes
	
	local itemType = weaponRes.pHeader.itemType	-- 物品类型
	local weaponType = ability.type	-- 近战/远程
	
	local damageType = ability.damageType	-- 武器伤害类型
	local damageDice = ability.damageDice
	local damageDiceCount = ability.damageDiceCount
	local damageDiceBonus = ability.damageDiceBonus
	
	local abilityFlags = ability.abilityFlags
	local addStrBonus = bit32.extract(abilityFlags, 0) == 1
	local addDamStrBonus = bit32.extract(abilityFlags, 2) == 1

	-- 致命一击修正
	local criticalHitMod = EEex_Sprite_GetStat(sourceSprite, 146)
	local criticalMissMod = 0
	
	local criticalEntryList = sourceSprite.m_derivedStats.m_cCriticalEntryList
	local node = criticalEntryList.m_pNodeHead
	while node do
		local criticalEntry = node.data
		if criticalEntry.m_hitOrMiss == 1 then	-- 0: hit, 1: miss
			if criticalEntry.m_slot == -1 or ((criticalEntry.m_slot == 9) == isLeftAttack) then
				if criticalEntry.m_attackType == 0 or criticalEntry.m_attackType == weaponType then
					criticalMissMod = criticalMissMod + criticalEntry.m_bonus
				end
			end
		end
		node = node.pNext
	end
	criticalHitMod = ST_Hook_CriticalHitMod(sourceSprite, targetSprite, criticalHitMod)	-- 调用Hook
	
	local hit = false
	local criticalHit = false
	local criticalMiss = false
	
	local hitRoll = math.random(0, 19)
	hitRoll = ST_Hook_HitRoll(sourceSprite, targetSprite, hitRoll) + 1	-- 调用Hook
	
	if ST_HasState(targetSprite, 'STATE_HELPLESS') then
		hit = true
	elseif hitRoll <= 1 + criticalMissMod then
		criticalMiss = true
	elseif hitRoll >= 20 - criticalHitMod then
		hit = true
		criticalHit = true
	end
	
	local str = EEex_Sprite_GetStat(sourceSprite, 36)	-- 角色力量	
	local hitModifier = 0	-- 命中修正值
	
	local resistPiercing = EEex_Sprite_GetStat(targetSprite, 88)
	local resistCrushing = EEex_Sprite_GetStat(targetSprite, 87)
	local resistSlashing = EEex_Sprite_GetStat(targetSprite, 86)
	local resistMissile = EEex_Sprite_GetStat(targetSprite, 89)
	
	if not (criticalHit or criticalMiss) then
		-- 基础命中值
		local thac0 = EEex_Sprite_GetStat(sourceSprite, 7)
		
		hitModifier =  hitModifier + EEex_Sprite_GetStat(sourceSprite, 84)	-- hitBonusRight

		-- 副手攻击修正
		if isLeftAttack then
			hitModifier = hitModifier + EEex_Sprite_GetStat(sourceSprite, 85)	-- hitBonusLeft
		end	

		-- 幸运修正
		local luck = EEex_Sprite_GetStat(sourceSprite, 32)
		hitModifier = hitModifier + luck

		-- local hitBonusMelee = EEex_Sprite_GetStat(sourceSprite, 166)	-- 近战命中修正，疑似包含在 hitBonusRight 里，无需计算
		
		-- 命中修正
		local hitBonus = sourceSprite.m_derivedStats.m_nHitBonus
		hitModifier = hitModifier + hitBonus

		if itemType == 28 then	-- 徒手攻击
			hitModifier = hitModifier + EEex_Sprite_GetStat(sourceSprite, 170)	-- fistHitModifier
		end

		-- 目标AC值
		local ac = EEex_Sprite_GetStat(targetSprite, 2)
		ac = math.max(ac, -20)
		ac = math.min(ac, 20)
		
		local acPiercing = EEex_Sprite_GetStat(targetSprite, 5)
		local acCrushing = EEex_Sprite_GetStat(targetSprite, 3)
		local acSlashing = EEex_Sprite_GetStat(targetSprite, 6)
		local acMissile = EEex_Sprite_GetStat(targetSprite, 4)
	
		local acModifiers = {
			[1] = acPiercing,
			[2] = acCrushing,
			[3] = acSlashing,
			[4] = acMissile,
			[6] = (resistPiercing <= resistCrushing) and acPiercing or acCrushing,
			[7] = (resistPiercing <= resistSlashing) and acPiercing or acSlashing,
			[8] = (resistSlashing <= resistCrushing) and acCrushing or acSlashing,
		}
		
		if acModifiers[damageType] then
			hitModifier = hitModifier + acModifiers[damageType]	-- 伤害类型带来的命中修正值
		end
		-- Infinity_DisplayString('hitModifier: ' .. hitModifier)
		
		-- 近战/远程惩罚
		local targetWeaponRes = ST_GetCurrentWeapon(targetSprite, false)
		address =  EEex_UDToPtr(targetWeaponRes.pAbilities) + 0x38 * targetSprite.m_equipment.m_selectedWeaponAbility
		local targetAbility = EEex_PtrToUD(address, "Item_ability_st")
		local targetWeaponType = targetAbility.type
		if weaponType == 1 and (targetWeaponType == 2 or targetWeaponType == 4) then
			hitModifier = hitModifier + 4
		elseif weaponType == 2 or weaponType == 4 then
			local dx = targetSprite.m_pos.x - sourceSprite.m_pos.x
			local dy = targetSprite.m_pos.y - sourceSprite.m_pos.y
			local distance = math.sqrt(dx * dx + dy * dy)
			if distance < 0x10 then
				hitModifier = hitModifier - 8
			end
		end
		
		-- 隐形修正
		if ST_HasState(sourceSprite, 'STATE_INVISIBLE') or ST_HasState(sourceSprite, 'STATE_IMPROVEDINVISIBILITY') then
			hitModifier = hitModifier + 4
		end
		if ST_HasState(targetSprite, 'STATE_INVISIBLE') or ST_HasState(targetSprite, 'STATE_IMPROVEDINVISIBILITY') then
			hitModifier = hitModifier - 4
		end
		
		-- 宿敌修正
		if sourceSprite.m_derivedStats.m_nHatedRace == targetSprite.m_typeAI.m_Race then
			hitModifier = hitModifier + 4
		end
		
		-- IDS 修正
		local matchedEffects = ST_FindEffectsAll(sourceSprite, {m_effectId = 177})
		local hitModifierIDS = 0
		for i = 1, #matchedEffects do
			local res = matchedEffects[i].m_res:get()
			local effect = EEex_Resource_Demand(res, 'EFF')
			if effect.m_effectId == 178 then
				if ST_MatchIds(targetSprite, effect.dwFlags, effect.effectAmount) then
					hitModifierIDS = math.max(hitModifierIDS, effect.m_effectAmount2)
				end
			end
		end
		hitModifierIDS = hitModifierIDS + hitModifierIDS
		
		-- 调用Hook
		hitModifier = ST_Hook_HitMod(sourceSprite, targetSprite, hitModifier)
		
		-- 命中判定
		hit = hitRoll + hitModifier >= thac0 - ac
	end
	
	local damModifier = 0
	local damModified = 0
	local blocked = false
	
	if hit then
		-- 是否武器无效
		local matchedEffects = {}
		
		if isMagical then
			matchedEffects = ST_FindEffectsAll(targetSprite, {m_effectId = 120, dwFlags = 1}, true)
		else
			matchedEffects = ST_FindEffectsAll(targetSprite, {m_effectId = 120, dwFlags = 2}, true)
		end
		blocked = (#matchedEffects > 0)
		
		matchedEffects = ST_FindEffectsAll(targetSprite, {m_effectId = 120, effectAmount = enchantment, dwFlags = 0}, true)
		blocked = blocked or (#matchedEffects > 0)
	
		if not blocked then	
			-- 伤害修正
			damModifier = damModifier + damageDiceBonus	-- 武器伤害加值
			damModifier = damModifier + sourceSprite.m_derivedStats.m_nDamageBonus	-- 通用伤害修正值
			damModifier = damModifier + sourceSprite.m_derivedStats.m_DamageBonusRight	-- 熟练度加值 + 武器风格加值 + 近战/远程修正值 + 效果（？）修正值
			
			-- 副手伤害修正
			if isLeftAttack then
				damModifier = damModifier + sourceSprite.m_derivedStats.m_DamageBonusLeft
			end	
			
			-- 力量修正		
			if addStrBonus or addDamStrBonus then
				local damStrBonus = EEex_Resource_GetAt2DALabels(strMod_2DA, 'DAMAGE', tostring(str))
				if str == 18 then
					local strExtra = EEex_Sprite_GetStat(sourceSprite, 37)
					damStrBonus = damStrBonus + EEex_Resource_GetAt2DALabels(strModEx_2DA, 'DAMAGE', tostring(strExtra))
				end
				damModifier = damModifier + damStrBonus
			end
				
			if itemType == 28 then	-- 徒手攻击
				damModifier = damModifier + EEex_Sprite_GetStat(sourceSprite, 171)	-- fistdamModifier
			end
			
			-- 宿敌修正
			if sourceSprite.m_derivedStats.m_nHatedRace == targetSprite.m_typeAI.m_Race then
				damModifier = damModifier + 4
			end
			
			-- IDS 修正
			local matchedEffects = ST_FindEffectsAll(sourceSprite, {m_effectId = 177})
			local damModifierIDS = 0
			for i = 1, #matchedEffects do
				local res = matchedEffects[i].m_res:get()
				local effect = EEex_Resource_Demand(res, 'EFF')
				if effect.m_effectId == 179 then
					if ST_MatchIds(targetSprite, effect.dwFlags, effect.effectAmount) then
						damModifierIDS = math.max(damModifierIDS, effect.m_effectAmount2)
					end
				end
			end
			damModifier = damModifier + damModifierIDS
			
			-- 调用Hook
			damModified = math.random(damageDice) * damageDiceCount + damModifier
			damModified = ST_Hook_AttackDamMod(sourceSprite, targetSprite, damModified)
		end
	end
	
	-- 致命一击是否被挡住
	local criticalHitBlocked = false
	local criticalHitMultiplier = 2
	
	if criticalHit and (not blocked) then
		local equipmentArray = targetSprite.m_equipment.m_items	-- 读取装备序列
		
		local scanSlots = {
			6, 7, 8, 9, 0, 1, 2, 3, 4, 5, 
			targetSprite.m_equipment.m_selectedWeapon,
		}	
		-- 读取物品
		for i = 1, #scanSlots do
			local item = equipmentArray:get(scanSlots[i])	-- 当前主手武器
			if item then
				local itemResRef = item.cResRef:get()
				local itemRes = EEex_Resource_Fetch(itemResRef, "ITM")
				if itemRes then
					local itemFlags = itemRes.pHeader.itemFlags
					local isHeadGear = itemRes.pHeader.itemType == 7
					local toggleCriticalHitFlag = bit32.extract(itemFlags, 25) == 1
					if isHeadGear ~= toggleCriticalHitFlag then
						criticalHitBlocked = true
						criticalHitMultiplier = criticalHitMultiplier - 1
						break
					end	
				end
			end
		end
		criticalHitMultiplier = ST_Hook_CriticalHitMultiplier(sourceSprite, targetSprite, criticalHitMultiplier)
	end

	-- 提示文本
	local sourceName = EEex_Sprite_GetName(sourceSprite)
	
	local hitRollString = ""
	if isLeftAttack then
		hitRollString = sourceName .. ": " .. Infinity_FetchString(8715) .. hitRoll	-- 副手攻击
	else
		hitRollString = sourceName .. ": " .. Infinity_FetchString(14643) .. hitRoll	-- 攻击检定
	end		
	if hitModifier >= 0 then
		hitRollString = hitRollString .. " + " .. hitModifier
	else
		hitRollString = hitRollString .. " - " .. -hitModifier
	end
	hitRollString = hitRollString .. " = " .. hitRoll + hitModifier .. " : "
	
	local resultString = hit and Infinity_FetchString(16460) or Infinity_FetchString(16461)
	hitRollString = hitRollString .. resultString
	
	if blocked then
		if hit then
			Infinity_DisplayString(Infinity_FetchString(11025))
		else
			Infinity_DisplayString(hitRollString)
		end
	else
		if criticalHit then
			if not criticalHitBlocked then
				Infinity_DisplayString(sourceName .. " : " .. Infinity_FetchString(16462))
			else
				Infinity_DisplayString(sourceName .. " : " .. Infinity_FetchString(20696))
			end
		elseif criticalMiss then
			Infinity_DisplayString(sourceName .. " : " .. Infinity_FetchString(16463))
		else
			Infinity_DisplayString(hitRollString)
		end
	end
	
	-- 造成效果
	if hit then	
		if blocked then
		else
			if criticalHit then
				damModified = damModified * criticalHitMultiplier
			end		
			-- 伤害参数
			local effectDamageType = {
				[1] = 0x00100000,	-- Piercing
				[2] = 0x00000000,	-- Crushing
				[3] = 0x01000000,	-- Slashing
				[4] = 0x00800000,	-- Missile
				[6] = (resistPiercing <= resistCrushing) and 0x00100000 or 0x00000000,
				[7] = (resistPiercing <= resistSlashing) and 0x00100000 or 0x01000000,
				[8] = (resistSlashing <= resistCrushing) and 0x00000000 or 0x01000000,
			}
			EEex_GameObject_ApplyEffect(targetSprite,{
				["effectID"] = 12,	-- opcode#12 造成伤害
				["effectList"] = 1,
				["effectAmount"] = damModified,				-- parameter 1 (Damage Amount)
				["dwFlags"] = effectDamageType[damageType],	-- parameter 2 (Mode & Damage Type)
				["durationType"] = 1,
				["sourceID"] = sourceSprite.m_id,
				})
			
			ST_ApplyWeaponHitEffects(sourceSprite, targetSprite, weaponRes, abilityIndex)
			if criticalHit then
				ST_ApplyCriticalEffects(sourceSprite, targetSprite, 0, weaponType)
			end	
		end
		
		if weaponType == 1 then	-- opcode#248 携带的命中效果
			ST_RunMeleeAttackListeners(sourceSprite, targetSprite, blocked)
			-- EEex_Opcode_Private_ApplyExtraMeleeEffects(sourceSprite, targetSprite)
		elseif weaponType == 2 or weaponType == 4 then	-- opcode#249 携带的命中效果
			-- EEex_Opcode_Private_ApplyExtraRangedEffects(sourceSprite, targetSprite)
		end
	elseif criticalMiss then
		ST_ApplyCriticalEffects(sourceSprite, targetSprite, 1, weaponType)
	end
	
	st_CurrentAttack.sourceTag = nil	-- 模拟攻击已完成，重置 sourceTag
end

function ST_ApplyWeaponHitEffects(sourceSprite, targetSprite, weaponRes, abilityIndex)
	weaponRes = weaponRes or ST_GetCurrentWeapon(sourceSprite, true)
	abilityIndex = abilityIndex or sourceSprite.m_equipment.m_selectedWeaponAbility
	
	local address =  EEex_UDToPtr(weaponRes.pAbilities) + 0x38 * abilityIndex
	local ability = EEex_PtrToUD(address, "Item_ability_st")
	local startingEffect = ability.startingEffect
	local effectCount = ability.effectCount
	
	for i = 1, effectCount do
		local address =  EEex_UDToPtr(weaponRes.pEffects) + 0x30 * (startingEffect + i - 1)
		local effect = EEex_PtrToUD(address, "Item_effect_st")
		EEex_GameObject_ApplyEffect(targetSprite,{
			["effectID"] = effect.effectID,
			["effectList"] = 1,
			["targetType"] = effect.targetType,
			["spellLevel"] = effect.spellLevel,
			["effectAmount"] = effect.effectAmount,
			["dwFlags"] = effect.dwFlags,
			["durationType"] = effect.durationType,
			["duration"] = effect.duration,
			["probabilityUpper"] = effect.probabilityUpper,
			["probabilityLower"] = effect.probabilityLower,
			["res"] = effect.res:get(),
			["numDice"] = effect.numDice,
			['diceSize'] = effect.diceSize,
			['savingThrow'] = effect.savingThrow,
			['saveMod'] = effect.saveMod,
			['special'] = effect.special,
			["sourceID"] = sourceSprite.m_id,
			["sourceTarget"] = targetSprite.m_id
			})
	end
end

function ST_ApplyCriticalEffects(sourceSprite, targetSprite, hitOrMiss, weaponType)	-- 0: hit, 1: miss
	hitOrMiss = hitOrMiss or 0	-- 默认为 hit 效果
	
	local node = sourceSprite.m_derivedStats.m_cCriticalEntryList.m_pNodeHead
	while node do
		local criticalEntry = node.data
		if criticalEntry.m_hitOrMiss == hitOrMiss then
			if criticalEntry.m_slot == -1 or criticalEntry.m_slot == sourceSprite.m_equipment.m_selectedWeapon then
				if criticalEntry.m_attackType == 0 or criticalEntry.m_attackType == weaponType then
					local effect = EEex_Resource_Demand(ST_GetResRef(criticalEntry.m_res.m_resRef), 'EFF')
					if effect then
						EEex_GameObject_ApplyEffect(targetSprite, {
						["effectID"] = effect.effectID,
						["effectList"] = 1,
						["targetType"] = effect.targetType,
						["spellLevel"] = effect.spellLevel,
						["effectAmount"] = effect.effectAmount,
						["dwFlags"] = effect.dwFlags,
						["durationType"] = effect.durationType,
						["duration"] = effect.duration,
						["probabilityUpper"] = effect.probabilityUpper,
						["probabilityLower"] = effect.probabilityLower,
						["res"] = effect.res:get(),
						["numDice"] = effect.numDice,
						["diceSize"] = effect.diceSize,
						["savingThrow"] = effect.savingThrow,
						["saveMod"] = effect.saveMod,
						['special'] = effect.special,
						["sourceID"] = sourceSprite.m_id,
						["sourceTarget"] = targetSprite.m_id,
						})
					end
				end
			end
		end
		node = node.pNext
	end
end
--[[
+------------+
| 法术位操作 |
+------------+
--]]
local spellTypeToField = {
	[0] = 'm_memorizedSpellsInnate',
	[1] = 'm_memorizedSpellsMage',
	[2] = 'm_memorizedSpellsPriest',
	[3] = 'm_memorizedSpellsInnate',
	[4] = 'm_memorizedSpellsInnate',
	[5] = 'm_memorizedSpellsInnate',
}

function ST_GetMemorizedSpellNodeList(sprite, spellName, spellType, spellLevel)	
	local spellRes = nil
	if spellType == nil or spellLevel == nil then
		spellRes = EEex_Resource_Fetch(spellName, 'SPL')
	end
	if spellType == nil then
		spellType = spellRes.pHeader.itemType
	end
	if spellType ~= 1 and spellType ~= 2 then	-- Innate一律视为1级
		spellLevel = 1
	elseif spellLevel == nil then
		spellLevel = spellRes.pHeader.spellLevel
	end
	
	local fieldName = spellTypeToField[spellType]
	
	local nodeList = sprite[fieldName]:getReference(spellLevel - 1)
	return nodeList
end

-- 修改已记忆法术的最大数量
function ST_SetMemorizedSpellNumMax(sprite, spellName, numToSetMax, spellType, spellLevel)
	local nodeList = ST_GetMemorizedSpellNodeList(sprite, spellName, spellType, spellLevel)
	local nodeCount = nodeList.m_nCount
	local node = nodeList.m_pNodeHead  -- 获取链表头部
	
	local matchedNodes = {}  -- 存储匹配的节点	
	local currentNumMax = 0

	while node ~= nil do
		if node.data.m_spellId:get() == spellName then
			table.insert(matchedNodes, node)
			currentNumMax = currentNumMax + 1	-- 记录法术数量
		end
		node = node.pNext
	end
	
	local nodeFree = nodeList.m_pNodeFree
	local nodeFreeCount = 0	-- 以后可能要用到，先留着
	while nodeFree do
		nodeFreeCount = nodeFreeCount + 1
		if not nodeFree.pNext then
			break
		end
		nodeFree = nodeFree.pNext
	end
	
	if currentNumMax > numToSetMax then
		for i = 1, (currentNumMax - numToSetMax) do
			local nodeToDelete = matchedNodes[i]
			if nodeToDelete then
				if nodeToDelete.pPrev then
					nodeToDelete.pPrev.pNext = nodeToDelete.pNext	-- 如果被删节点前存在节点，则将其与被删节点后的节点连接
				else
					nodeList.m_pNodeHead = nodeToDelete.pNext  -- 否则将被删节点后的节点设为头部
				end
				if nodeToDelete.pNext then
					nodeToDelete.pNext.pPrev = nodeToDelete.pPrev	-- 如果被删节点后存在节点，则将其与被删节点前的节点连接
				else
					nodeList.m_pNodeTail = nodeToDelete.pPrev  -- 否则将被删节点后的节点设为尾部
				end
				if nodeFree then	-- 归还nodeFree
					nodeFree.pNext = nodeToDelete
					nodeToDelete.pPrev = nodeFree
				else
					nodeToDelete.pPrev = nil
					nodeList.m_pNodeFree = nodeToDelete
				end
				nodeToDelete.pNext = nil	
				nodeFree = nodeToDelete
				nodeList.m_nCount = nodeList.m_nCount - 1
			end
		end
	elseif currentNumMax < numToSetMax then
		for i = 1, (numToSetMax - currentNumMax) do
			local spellData = EEex_NewUD("CCreatureFileMemorizedSpell")
			spellData.m_spellId:set(spellName)
			spellData.m_flags = 1
			nodeList:AddTail(spellData)
			-- if spellType == 1 or spellType == 2 then
				-- local spellData = EEex_NewUD("CCreatureFileMemorizedSpell")
				-- spellData.m_spellId:set(spellName)
				-- spellData.m_flags = 1
				-- nodeList:AddTail(spellData)
			-- else
				-- EEex_GameObject_ApplyEffect(sprite,{
					-- ["effectID"] = 171,
					-- ["effectAmount"] = 0,
					-- ["dwFlags"] = 0,
					-- ["durationType"] = 0,
					-- ["res"] = spellName,
				-- })
			-- end
		end
	end
end

-- 修改已记忆法术的记忆数量
function ST_SetMemorizedSpellNum(sprite, spellName, numToSet, spellType, spellLevel)
	local nodeList = ST_GetMemorizedSpellNodeList(sprite, spellName, spellType, spellLevel)
	local node = nodeList.m_pNodeHead  -- 获取链表头部
	
	local matchedNodes = {}  -- 存储匹配的节点	
	local currentNum = 0
	
	while node ~= nil do
		if node.data.m_spellId:get() == spellName then
			table.insert(matchedNodes, node)
			if node.data.m_flags == 1 then
				currentNum = currentNum + 1	-- 记录已记忆法术数量
			end
		end
		node = node.pNext
	end
	
	if currentNum ~= numToSet then
		for i = 1, #matchedNodes do
			node = matchedNodes[i]
			node.data.m_flags = (i <= numToSet) and 1 or 0
		end
	end
end

-- 增减已记忆法术的记忆数量
function ST_ChangeMemorizedSpellNum(sprite, spellName, numToChange, spellType, spellLevel)
	local nodeList = ST_GetMemorizedSpellNodeList(sprite, spellName, spellType, spellLevel)
	local node = nodeList.m_pNodeHead  -- 获取链表头部
	
	local matchedNodes = {}  -- 存储匹配的节点	
	
	while node ~= nil do
		if node.data.m_spellId:get() == spellName then
			table.insert(matchedNodes, node)
		end
		node = node.pNext
	end
	
	if numToChange ~= 0 then
		for i = 1, #matchedNodes do
			if numToChange == 0 then
				break
			end
		
			node = matchedNodes[i]
			if numToChange > 0 then
				if node.data.m_flags == 0 then
					node.data.m_flags = 1
					numToChange = numToChange - 1
				end
			elseif numToChange < 0 then
				if node.data.m_flags == 1 then
					node.data.m_flags = 0
					numToChange = numToChange + 1
				end
			end
		end
	end
end

-- 修改已记忆法术的代码
function ST_ReplaceMemorizedSpellRes(sprite, spellName, spellNameNew, spellType, spellLevel)
	local nodeList = ST_GetMemorizedSpellNodeList(sprite, spellName, spellType, spellLevel)
	local nodeCount = nodeList.m_nCount
	local node = nodeList.m_pNodeHead  -- 获取链表头部
	
	local matchedNodes = {}  -- 存储匹配的节点	
	local currentNumMax = 0
	
	while node ~= nil do
		if node.data.m_spellId:get() == spellName then
			table.insert(matchedNodes, node)
		end
		node = node.pNext
	end
	
	local args = {
		["m_spellId"] = spellNameNew  -- 你想要修改的字段
	}
	local writeDefs = {
		{ "m_spellId", EEex_WriteFailType.ERROR },
	}
	for i = 1, #matchedNodes do
		node = matchedNodes[i]
		EEex_WriteUDArgs(node.data, args, writeDefs)
	end
end
--[[
+-------------------+
| 查找指定的 effect |
+-------------------+
--]]
function ST_FindEffects(effectList, filter, firstOnly)
	local matchedEffects = {}
	
	local node = effectList.m_pNodeHead
	
	while node ~= nil do
		local effect = node.data
		local match = true
		
        for key, value in pairs(filter) do
			local e_value = effect[key]
			if type(e_value) == "userdata" then
				e_value = e_value:get()
			end
            if e_value ~= value then
                match = false
                break
            end
        end

        if match then
			table.insert(matchedEffects, effect)
			if firstOnly then
				break
			end
        end
		
		node = node.pNext
	end
	
	return matchedEffects
end

function ST_FindEffectsAll(sprite, filter, firstOnly)
	local matchedEffects = ST_FindEffects(sprite.m_equipedEffectList, filter, firstOnly)
	if #matchedEffects == 0 or (not firstOnly) then
		local timedEffect = ST_FindEffects(sprite.m_timedEffectList, filter, firstOnly)
		for i = 1, #timedEffect do
			table.insert(matchedEffects, timedEffect[i])
		end
	end
	if #matchedEffects == 0 or (not firstOnly) then
		local persistantEffects = ST_FindEffects(sprite.m_persistantEffects, filter, firstOnly)
		for i = 1, #persistantEffects do
			table.insert(matchedEffects, persistantEffects[i])
		end
	end
	
	return matchedEffects
end

--[[
+------------------+
| 随地潜行判定hook |
+------------------+
--]]
function ST_RegisterHook_HideInPlainSight()
	EEex_HookBeforeRestoreWithLabels(ST_GetEngineAddress(0x14039D837), 0, 0, 9, {
		{"hook_integrity_watchdog_ignore_registers", {
			EEex_HookIntegrityWatchdogRegister.RAX,
		}},
		{"manual_hook_integrity_exit", true}},
		EEex_FlattenTable({
			{[[	
				#MAKE_SHADOW_SPACE(64)
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], rax
				mov eax, dword ptr [rsi + 0x48]
			]]},
			EEex_GenLuaCall("ST_Hook_HideInPlainSight", {
				["args"] = {
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], rax #ENDL", {rspOffset}} end,
				},
				["returnType"] = EEex_LuaCallReturnType.Boolean,
			}),
			{[[
				call_error:
				
				no_error:
				
				test rax, rax
				jz hide_fail
				mov rax, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
				#DESTROY_SHADOW_SPACE(KEEP_ENTRY)
				#MANUAL_HOOK_EXIT(1)
				jmp #L(ST_HideInPlainSight_Continue)

				hide_fail:
				#RESUME_SHADOW_ENTRY
				mov rax, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
				#DESTROY_SHADOW_SPACE
				#MANUAL_HOOK_EXIT(0)
				jmp #L(ST_HideInPlainSight_Fail)
			]]},
		})
	)
end

function ST_Hook_HideInPlainSight(spriteId)
	local sprite = EEex_GameObject_Get(spriteId)
	
	local toHide = false
    for i = 1, #ST_HideInPlainSightListeners do
        local listener = ST_HideInPlainSightListeners[i]
        if listener(sprite) then
			toHide = true
		end
    end
	
	if ST_MatchKitId(sprite, 0x00004021) then	-- 具有影舞者宗派时直接通过检定
		return true
	end
	
	local matchedEffects = ST_FindEffectsAll(sprite, {m_effectId = 275, m_special = 1}, true)	-- opcode#275 special 值为1时允许随地潜行	
	if #matchedEffects > 0 then
		toHide = true
	end
	
	return toHide	-- 返回值存放在shadow space中，ptr [rsp+56]
end

ST_HideInPlainSightListeners = {}
function ST_AddHideInPlainSightListener(func)
    table.insert(ST_HideInPlainSightListeners, func)
end

--[[
+------------------+
| 物理攻击序号hook |
+------------------+
--]]


function ST_RegisterHook_AttackIndex()
    EEex_HookBeforeRestoreWithLabels(ST_GetEngineAddress(0x1403B9547), 0, 8, 8, {
        {"hook_integrity_watchdog_ignore_registers", {
            EEex_HookIntegrityWatchdogRegister.RAX, EEex_HookIntegrityWatchdogRegister.RCX, EEex_HookIntegrityWatchdogRegister.RDX,
            EEex_HookIntegrityWatchdogRegister.R8,  EEex_HookIntegrityWatchdogRegister.R9, EEex_HookIntegrityWatchdogRegister.R10,
            EEex_HookIntegrityWatchdogRegister.R11,
        }},
    }, EEex_FlattenTable({
        {[[
            #MAKE_SHADOW_SPACE(64)

            mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)],  rcx
            mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)], rdx

            mov ecx, dword ptr [rbx+0x48]
			mov r8d, dword ptr [r15+0x48]
        ]]},
        EEex_GenLuaCall("ST_Hook_AttackIndex", {
            ["args"] = {
                function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], rcx #ENDL", {rspOffset}} end,
				function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r8 #ENDL",  {rspOffset}} end,
                function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], rdx #ENDL", {rspOffset}} end,
            },
        }),
        {[[
			call_error:
			
			no_error:
            mov rcx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
            mov rdx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]

            #DESTROY_SHADOW_SPACE
        ]]},
    }))
end

local st_roundCounter = {}
local st_roundTimer = {}
function ST_Hook_AttackIndex(sourceId, targetId, attackIndex)
	local sourceSprite = EEex_GameObject_Get(sourceId)
	local targetSprite = EEex_GameObject_Get(targetId)
	local currentTime = EngineGlobals.g_pBaldurChitin.m_pObjectGame.m_worldTime.m_gameTime
	
	local isHasted  = ST_HasState(sourceSprite, 'STATE_HASTED')
	
	if not st_roundCounter[sourceId] then
		st_roundCounter[sourceId] = 0
		st_roundTimer[sourceId] = currentTime
	elseif attackIndex == 1 then
		st_roundCounter[sourceId] = st_roundCounter[sourceId] + 1
	end
	
	local roundTime = isHasted and 45 or 90
	if currentTime - st_roundTimer[sourceId] >= roundTime then
		st_roundCounter[sourceId] = 0
	end
	st_roundTimer[sourceId] = currentTime


    for i = 1, #ST_AttackIndexListeners do
        local listener = ST_AttackIndexListeners[i]
		listener(sourceSprite, targetSprite, attackIndex)
    end

	
	local function ST_DecodeAPR(key)
		local sign = key < 0 and -1 or 1
		local positiveKey = math.abs(key)
		local fullAttacks = positiveKey % 6
		local halfAttacks = math.floor(positiveKey / 6) * 0.5
		local attacksPerRound = fullAttacks + halfAttacks
		return attacksPerRound * sign
	end
	
	local leftAPRBonusEffects = ST_FindEffectsAll(sourceSprite, {m_effectId = 1, m_special = 1})
	local leftAPRBonus = 0
	for i = 1, #leftAPRBonusEffects do
		local effect = leftAPRBonusEffects[i]
		leftAPRBonus = leftAPRBonus + ST_DecodeAPR(effect.m_effectAmount)
	end
	
	local _, leftWeaponRes = ST_GetCurrentWeapon(sourceSprite)
	if leftWeaponRes then
		local address =  EEex_UDToPtr(leftWeaponRes.pEffects)
		for i = 1, leftWeaponRes.pHeader.equipedEffectCount do
			local effect = EEex_PtrToUD(address, "Item_effect_st")
			if effect.effectID == 1 and effect.targetType == 1 and effect.dwFlags == 0 then
				leftAPRBonus = leftAPRBonus + ST_DecodeAPR(effect.effectAmount)
			end
			address = address + 0x30
		end
	end
	
	if isHasted then
		local apr = ST_DecodeAPR(sourceSprite.m_derivedStats.m_nNumberOfAttacks)
		local integerAPR = math.floor(apr)
		local desiredExtraLeftAttacks = math.floor(leftAPRBonus * 2)
		local maxExtraLeftAttacks = math.max(0, integerAPR - 2)
		local extraLeftAttacks = math.min(desiredExtraLeftAttacks, maxExtraLeftAttacks)
		local halfRoundIndex = st_roundCounter[sourceId] % 2
		local fullRoundIndex = math.floor(st_roundCounter[sourceId] / 2)
		local extraLeftAttacksThisHalf = math.floor(extraLeftAttacks / 2)

		if extraLeftAttacks % 2 == 1 then
			local favoredHalfRound
			if apr % 1 == 0.5 then
				favoredHalfRound = 0
			else
				favoredHalfRound = fullRoundIndex % 2
			end

			if halfRoundIndex == favoredHalfRound then
				extraLeftAttacksThisHalf = extraLeftAttacksThisHalf + 1
			end
		end

		local useLeftAttack = false
		if extraLeftAttacksThisHalf == 1 then
			local preferredAttackIndex = math.floor((integerAPR + 1) / 2)
			useLeftAttack = attackIndex == preferredAttackIndex
		elseif extraLeftAttacksThisHalf >= 2 then
			useLeftAttack = attackIndex == 2 or attackIndex == 4
		end

		sourceSprite.m_leftAttack = useLeftAttack and 1 or 0
	else
		if attackIndex == 2 then
			if leftAPRBonus >= 1 then
				sourceSprite.m_leftAttack = 1
			elseif leftAPRBonus == 0.5 and sourceSprite.m_nHalfSwingCounter % 2 == 0 then
				sourceSprite.m_leftAttack = 1
			else
				sourceSprite.m_leftAttack = 0
			end
		else
			sourceSprite.m_leftAttack = 0
		end
	end
end

ST_AttackIndexListeners = {}
function ST_AddAttackIndexListener(func)
    table.insert(ST_AttackIndexListeners, func)
end

function ST_RegisterHook_AttackCancel()
	EEex_HookBeforeRestoreWithLabels(ST_GetEngineAddress(0x1403B8439), 0, 9, 9, {
		{"hook_integrity_watchdog_ignore_registers", {
			EEex_HookIntegrityWatchdogRegister.RAX, EEex_HookIntegrityWatchdogRegister.RCX, EEex_HookIntegrityWatchdogRegister.RDX,
			EEex_HookIntegrityWatchdogRegister.R8, EEex_HookIntegrityWatchdogRegister.R9, EEex_HookIntegrityWatchdogRegister.R10,
			EEex_HookIntegrityWatchdogRegister.R11,
		}},
	}, EEex_FlattenTable({
		{[[
			#MAKE_SHADOW_SPACE(96)

			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)],  rax
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)], rcx
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)], rdx
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-32)], r8
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-40)], r9
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-48)], r10
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-56)], r11

			mov r10d, dword ptr [rbx+0x48]
			mov r11d, dword ptr [r15+0x48]
		]]},

		EEex_GenLuaCall("ST_Hook_ShouldCancelAttack", {
			["args"] = {
				function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r10 #ENDL", {rspOffset}} end,
				function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r11 #ENDL", {rspOffset}} end,
			},
			["returnType"] = EEex_LuaCallReturnType.Boolean,
		}),

		{[[
			test eax, eax
			jz restore

			mov rax, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
			mov al, 6
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], rax
			jmp restore

			call_error:

			restore:
			mov r11, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-56)]
			mov r10, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-48)]
			mov r9,  qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-40)]
			mov r8,  qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-32)]
			mov rdx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)]
			mov rcx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
			mov rax, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]

			#DESTROY_SHADOW_SPACE
		]]},
	}))
end

ST_AttackCancelListeners = {}
function ST_AddAttackCancelListener(func)
	table.insert(ST_AttackCancelListeners, func)
end

function ST_Hook_ShouldCancelAttack(sourceId, targetId)
	local sourceSprite = EEex_GameObject_Get(sourceId)
	local targetSprite = EEex_GameObject_Get(targetId)

	for i = 1, #ST_AttackCancelListeners do
		if ST_AttackCancelListeners[i](sourceSprite, targetSprite) then
			return true
		end
	end

	return false
end

--[[
+--------------------+
| 物理攻击命中骰hook |
+--------------------+
--]]
function ST_RegisterHook_HitRoll()
	EEex_HookAfterCallWithLabels(ST_GetEngineAddress(0x14039DAD5), {
		{"hook_integrity_watchdog_ignore_registers", {EEex_HookIntegrityWatchdogRegister.RAX}}},
		EEex_FlattenTable({
			{[[
				#MAKE_SHADOW_SPACE(80)
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], r10
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)], r11
				mov r10d, dword ptr [rbx + 0x48]
				mov r11d, dword ptr [r14 + 0x48]
			]]},
			EEex_GenLuaCall("ST_Hook_HitRoll", {
				["args"] = {
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r10 #ENDL", {rspOffset}} end,
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r11 #ENDL", {rspOffset}} end,
					function(rspOffset) return {"mov dword ptr ss:[rsp+#$(1)], eax #ENDL", {rspOffset}} end,
				},
				["returnType"] = EEex_LuaCallReturnType.Number,
			}),
			{[[
				call_error:
				
				no_error:
				mov r11, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
				mov r10, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
				mov rax, qword ptr [rsp + 56]
				#DESTROY_SHADOW_SPACE
			]]},
		})
	)
end

st_CurrentAttack = {
    sourceSprite = nil,
    targetSprite = nil,
    hitRoll = nil,
	sourceTag = nil,
	rightWeaponRes = nil,
	leftWeaponRes = nil,
	attackWeaponRes = nil,
	isLeftAttack = false,
	fightingStyle = nil,
	backstabInvisibilityValid = true,
	backstabPositionValid = true,
	backstabTargetImmune = false,
	backstabImmunityBypassed = false,
}

function ST_Hook_HitRoll(sourceSpriteOrId, targetSpriteOrId, hitRoll)	-- hitRoll 的取值范围是0-19，所以它会比游戏里显示的小1
	local sourceSprite = ST_GetSprite(sourceSpriteOrId)
	local targetSprite = ST_GetSprite(targetSpriteOrId)
	local reRollTokens = 0
	local rightWeaponRes, leftWeaponRes, fightingStyle, isLeftAttack = ST_GetCurrentWeapon(sourceSprite, false)

	st_CurrentAttack.sourceSprite = sourceSprite
	st_CurrentAttack.targetSprite = targetSprite
	st_CurrentAttack.rightWeaponRes = rightWeaponRes
	st_CurrentAttack.leftWeaponRes = leftWeaponRes
	st_CurrentAttack.attackWeaponRes = isLeftAttack and leftWeaponRes or rightWeaponRes
	st_CurrentAttack.isLeftAttack = isLeftAttack
	st_CurrentAttack.fightingStyle = fightingStyle
	st_CurrentAttack.backstabInvisibilityValid = true
	st_CurrentAttack.backstabPositionValid = true
	st_CurrentAttack.backstabTargetImmune = false
	st_CurrentAttack.backstabImmunityBypassed = false
	
    for i = 1, #ST_HitRollListeners do
        local listener = ST_HitRollListeners[i]
        local reRollToken = listener(sourceSprite, targetSprite, hitRoll) or 0
		reRollTokens = reRollTokens + reRollToken
    end
	
	if reRollTokens ~= 0 then
		for i = 1, math.abs(reRollTokens) do
			local reRoll = math.random(0, 19)
			if reRollTokens > 0 then
				hitRoll = math.max(hitRoll, reRoll)
			else
				hitRoll = math.min(hitRoll, reRoll)
			end
		end
	end
	
	st_CurrentAttack.hitRoll = hitRoll
	return hitRoll
end

ST_HitRollListeners = {}
function ST_AddHitRollListener(func)
    table.insert(ST_HitRollListeners, func)
end

ST_AddHitRollListener(function(sourceSprite, targetSprite, hitRoll)	-- 用于测试
	-- local sourceName = EEex_Sprite_GetName(sourceSprite)
	
	-- Infinity_DisplayString(sourceName)
	-- Infinity_DisplayString('m_nDamageBonus: ' .. sourceSprite.m_derivedStats.m_nDamageBonus)	-- 通用伤害修正值
	
	
	-- Infinity_DisplayString('m_DamageBonusRight: ' .. sourceSprite.m_derivedStats.m_DamageBonusRight)	-- 熟练度加值 + 武器风格加值 + 近战/远程修正值 + 效果（？）修正值
	
	-- local criticalEntryList = sourceSprite.m_derivedStats.m_cCriticalEntryList
	-- local node = criticalEntryList.m_pNodeHead
	-- local i = 1
	-- while node do
		-- local criticalEntry = node.data
		-- Infinity_DisplayString('criticalEntry[' .. i .. ']:')
		-- Infinity_DisplayString('m_hitOrMiss: ' .. criticalEntry.m_hitOrMiss)	-- 0: hit, 1: miss
		-- Infinity_DisplayString('m_slot: ' .. criticalEntry.m_slot)	-- 对该slot的武器生效（-1对所有武器生效）
		-- Infinity_DisplayString('m_attackType: ' .. criticalEntry.m_attackType)
		-- Infinity_DisplayString('m_itemType: ' .. criticalEntry.m_itemType)
		-- Infinity_DisplayString('m_bonus: ' .. criticalEntry.m_bonus)
		-- if criticalEntry.m_hitOrMiss == 1 then
			
		-- end
		-- node = node.pNext
		-- i = i + 1
	-- end
	
	-- local effect = sourceSprite.m_equipedEffectList
	-- Infinity_DisplayString(effect.m_pNodeHead.data.m_effectId)
	-- Infinity_DisplayString(sourceSprite.m_derivedStats.m_nPhysicalSpeed)
	-- Infinity_DisplayString(targetSprite.m_derivedStats.m_nPhysicalSpeed)
	
	-- for i = 1, 40 do
		-- Infinity_DisplayString(i .. ': ' .. sourceSprite.m_weaponProficiencyList[i])
	-- end
	-- Infinity_DisplayString(type(sourceSprite.m_weaponProficiencyList.m_nProficiencyLongSword))
	

end)
--[[
+----------------------+
| 物理攻击命中修正hook |
+----------------------+
--]]
function ST_RegisterHook_HitMod()
	EEex_HookAfterCallWithLabels(ST_GetEngineAddress(0x14039DFF4), {
		{"hook_integrity_watchdog_ignore_registers", {EEex_HookIntegrityWatchdogRegister.RAX}}},
		EEex_FlattenTable({
			{[[
				#MAKE_SHADOW_SPACE(80)
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], r10
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)], r11
				mov r10d, dword ptr [rbx + 0x48]
				mov r11d, dword ptr [r14 + 0x48]
			]]},
			EEex_GenLuaCall("ST_Hook_HitMod", {
				["args"] = {
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r10 #ENDL", {rspOffset}} end,
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r11 #ENDL", {rspOffset}} end,
					function(rspOffset) return {"mov word ptr ss:[rsp+#$(1)], r15w #ENDL", {rspOffset}} end,
				},
				["returnType"] = EEex_LuaCallReturnType.Number,
			}),
			{[[
				call_error:
				
				no_error:
				mov r11, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
				mov r10, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
				mov r15w, word ptr [rsp + 56]
				#DESTROY_SHADOW_SPACE
			]]},
		})
	)

end

function ST_Hook_HitMod(sourceSpriteOrId, targetSpriteOrId, hitModified)
	local sourceSprite = ST_GetSprite(sourceSpriteOrId)
	local targetSprite = ST_GetSprite(targetSpriteOrId)
	
    for i = 1, #ST_HitModListeners do
        local listener = ST_HitModListeners[i]
        hitModified = listener(sourceSprite, targetSprite, hitModified) or hitModified
    end
	
	return hitModified
end

ST_HitModListeners = {}
function ST_AddHitModListener(func)
    table.insert(ST_HitModListeners, func)
end

ST_AddHitModListener(function(sourceSprite, targetSprite, hitModified)	-- 用于测试
	-- if targetSprite.m_typeAI.m_Race == 122 then
		-- Infinity_DisplayString('狼人杀手')
		-- hitModified = hitModified + 200
	-- end
	-- return hitModified
end)
--[[
+----------------------+
| 物理攻击伤害修正hook |
+----------------------+
--]]
function ST_RegisterHook_AttackDamMod()
	EEex_HookAfterCallWithLabels(ST_GetEngineAddress(0x14038FEF0), {
		{"hook_integrity_watchdog_ignore_registers", {EEex_HookIntegrityWatchdogRegister.RAX}}},
		EEex_FlattenTable({
			{[[
				#MAKE_SHADOW_SPACE(80)
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], r10
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)], r11
				mov r10d, dword ptr [rdi + 0x48]
				mov r11d, dword ptr [r15 + 0x48]
			]]},
			EEex_GenLuaCall("ST_Hook_AttackDamMod", {
				["args"] = {
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r10 #ENDL", {rspOffset}} end,
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r11 #ENDL", {rspOffset}} end,
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], rsi #ENDL", {rspOffset}} end,
				},
				["returnType"] = EEex_LuaCallReturnType.Number,
			}),
			{[[
				call_error:
				
				no_error:
				mov r11, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
				mov r10, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
				mov si, word ptr [rsp + 56]
				#DESTROY_SHADOW_SPACE
			]]},
		})
	)

end

function ST_Hook_AttackDamMod(sourceSpriteOrId, targetSpriteOrId, damModified)
	local sourceSprite = ST_GetSprite(sourceSpriteOrId)
	local targetSprite = ST_GetSprite(targetSpriteOrId)
	
    for i = 1, #ST_AttackDamModListeners do
        local listener = ST_AttackDamModListeners[i]
        damModified = listener(sourceSprite, targetSprite, damModified) or damModified
    end
	
	return damModified
end

ST_AttackDamModListeners = {}
function ST_AddAttackDamModListener(func)
    table.insert(ST_AttackDamModListeners, func)
end

--[[
+------------------+
| 致命一击阈值hook |
+------------------+
--]]
function ST_RegisterHook_CriticalHitMod()
	EEex_HookAfterCallWithLabels(ST_GetEngineAddress(0x14039E583), {
		{"hook_integrity_watchdog_ignore_registers", {
			EEex_HookIntegrityWatchdogRegister.RAX,
			EEex_HookIntegrityWatchdogRegister.R10,
		}}},
		EEex_FlattenTable({
			{[[
				#MAKE_SHADOW_SPACE(56)
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], rax
				mov r10d, eax
			]]},
			EEex_GenLuaCall("ST_Hook_CriticalHitMod", {
				["args"] = {
					function(rspOffset) return {"mov eax, dword ptr [rbx+48h] #ENDL mov qword ptr ss:[rsp+#$(1)], rax #ENDL", {rspOffset}} end,
					function(rspOffset) return {"mov eax, dword ptr [r14+48h] #ENDL mov qword ptr ss:[rsp+#$(1)], rax #ENDL", {rspOffset}} end,
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r10 #ENDL", {rspOffset}} end,
				},
				["returnType"] = EEex_LuaCallReturnType.Number,
			}),
			{[[
				call_error:
				mov rax, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]

				no_error:
				#DESTROY_SHADOW_SPACE
			]]},
		})
	)
end

function ST_Hook_CriticalHitMod(sourceSpriteOrId, targetSpriteOrId, criticalHitMod)
	local sourceSprite = ST_GetSprite(sourceSpriteOrId)
	local targetSprite = ST_GetSprite(targetSpriteOrId)

	for i = 1, #ST_CriticalHitModListeners do
		local listener = ST_CriticalHitModListeners[i]
		local newModifier = listener(sourceSprite, targetSprite, criticalHitMod)
		if newModifier ~= nil then
			criticalHitMod = newModifier
		end
	end
	
	return criticalHitMod
end

ST_CriticalHitModListeners = {}
function ST_AddCriticalHitModListener(func)
	table.insert(ST_CriticalHitModListeners, func)
end

--[[
+--------------+
| 致命一击hook |
+--------------+
--]]
function ST_RegisterHook_CriticalHit()
	EEex_HookAfterRestoreWithLabels(ST_GetEngineAddress(0x14039E618), 0, 7, 7, {
		{"hook_integrity_watchdog_ignore_registers", {
			EEex_HookIntegrityWatchdogRegister.RAX,
		}}},
		EEex_FlattenTable({
			{[[
				mov dword ptr [rax], 2
			]]},
		})
	)

	EEex_HookBeforeRestoreWithLabels(ST_GetEngineAddress(0x140390C72), 0, 8, 8, {
		{"hook_integrity_watchdog_ignore_registers", {
			EEex_HookIntegrityWatchdogRegister.RAX, EEex_HookIntegrityWatchdogRegister.RCX, EEex_HookIntegrityWatchdogRegister.RDX,
			EEex_HookIntegrityWatchdogRegister.R8, EEex_HookIntegrityWatchdogRegister.R9, EEex_HookIntegrityWatchdogRegister.R10,
			EEex_HookIntegrityWatchdogRegister.R11,
		}}},
		EEex_FlattenTable({
			{[[
				cmp dword ptr [rbp+6Fh], 2
				jne no_block
				dec eax

				no_block:
				mov r10d, eax
				#MAKE_SHADOW_SPACE(56)
			]]},
			EEex_GenLuaCall("ST_Hook_CriticalHitMultiplier", {
				["args"] = {
					function(rspOffset) return {"mov eax, dword ptr [rdi+48h] #ENDL mov qword ptr ss:[rsp+#$(1)], rax #ENDL", {rspOffset}} end,
					function(rspOffset) return {"mov eax, dword ptr [r15+48h] #ENDL mov qword ptr ss:[rsp+#$(1)], rax #ENDL", {rspOffset}} end,
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r10 #ENDL", {rspOffset}} end,
				},
				["returnType"] = EEex_LuaCallReturnType.Number,
			}),
			{[[
				call_error:

				no_error:
				#DESTROY_SHADOW_SPACE
			]]},
		})
	)
end

function ST_Hook_CriticalHitMultiplier(sourceSpriteOrId, targetSpriteOrId, multiplier)
	local sourceSprite = ST_GetSprite(sourceSpriteOrId)
	local targetSprite = ST_GetSprite(targetSpriteOrId)

	local isLeftAttack = st_CurrentAttack.isLeftAttack

	local criticalEntryList = sourceSprite.m_derivedStats.m_cCriticalEntryList
	
	local node = criticalEntryList.m_pNodeHead
	while node do
		local criticalEntry = node.data
		
		if criticalEntry.m_attackType == 5 or (criticalEntry.m_attackType - 5) == weaponType then
			if criticalEntry.m_hitOrMiss == 0 then
				if criticalEntry.m_slot == -1 or ((criticalEntry.m_slot == 9) == isLeftAttack) then
					multiplier = multiplier + criticalEntry.m_bonus
				end
			end
		end

		node = node.pNext
	end
	
    for i = 1, #ST_CriticalHitMultiplierListeners do
        local listener = ST_CriticalHitMultiplierListeners[i]
        multiplier = listener(sourceSprite, targetSprite, multiplier) or multiplier
    end
	
	return multiplier
end

ST_CriticalHitMultiplierListeners = {}
function ST_AddCriticalHitMultiplierListener(func)
    table.insert(ST_CriticalHitMultiplierListeners, func)
end

--[[
+------------------+
| 物理攻击命中hook |
+------------------+
--]]
ST_MeleeAttackListeners = {}

function ST_AddMeleeAttackListener(func)
	table.insert(ST_MeleeAttackListeners, func)
end

function ST_RunMeleeAttackListeners(sourceSprite, targetSprite, bBlocked)
	for i = 1, #ST_MeleeAttackListeners do
		local listener = ST_MeleeAttackListeners[i]
		local ok, err = pcall(listener, sourceSprite, targetSprite, bBlocked)

		if not ok then
			Infinity_DisplayString("ST_MeleeAttackListener error: " .. tostring(err))
		end
	end
end

local ST_EEex_Opcode_Hook_OnAfterSwingCheckedOp248 = EEex_Opcode_Hook_OnAfterSwingCheckedOp248

function EEex_Opcode_Hook_OnAfterSwingCheckedOp248(sourceSprite, targetSprite, bBlocked)
	-- 执行原始逻辑
	ST_EEex_Opcode_Hook_OnAfterSwingCheckedOp248(sourceSprite, targetSprite, bBlocked)
	-- 执行注册的监听器
	ST_RunMeleeAttackListeners(sourceSprite, targetSprite, bBlocked)
end

-- 向常驻监视器中添加调用
--[[
function ST_Opcode_AddListsResolvedListener(func)
	-- [EEex.dll]
	EEex.Opcode_LuaHook_AfterListsResolved_Enabled = true
	table.insert(EEex_Opcode_ListsResolvedListeners, func)
end

ST_Opcode_AddListsResolvedListener(function(sprite)	
end)
]]--

--[[
+----------+
| 按钮hook |
+----------+
--]]
local function ST_RegisterHook_ButtonPressed()
	EEex_HookBeforeRestoreWithLabels(ST_GetEngineAddress(0x1402633E1), 0, 8, 8, {
		{"hook_integrity_watchdog_ignore_registers", {
			EEex_HookIntegrityWatchdogRegister.RAX, EEex_HookIntegrityWatchdogRegister.RDX, EEex_HookIntegrityWatchdogRegister.R8,
			EEex_HookIntegrityWatchdogRegister.R9, EEex_HookIntegrityWatchdogRegister.R10, EEex_HookIntegrityWatchdogRegister.R11
		}}},
		EEex_FlattenTable({
			{[[
				#MAKE_SHADOW_SPACE(48)
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], rcx
			]]},
			EEex_GenLuaCall("ST_Hook_ButtonPressed", {
				["args"] = {
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r15 #ENDL", {rspOffset}} end,
				},
			}),
			{[[
				call_error:
				
				no_error:
				
				mov rcx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
				#DESTROY_SHADOW_SPACE
			]]},
		})
	)
end

function ST_Hook_ButtonPressed(buttonIndex)
    for i = 1, #ST_ButtonPressedListeners do
        local listener = ST_ButtonPressedListeners[i]
        listener(buttonIndex)
    end
end

ST_ButtonPressedListeners = {}
function ST_AddButtonPressedListener(func)
    table.insert(ST_ButtonPressedListeners, func)
end

-- 动作栏按钮右键 hook
local function ST_RegisterHook_RButtonPressed()
	EEex_HookBeforeRestoreWithLabels(ST_GetEngineAddress(0x140264B8F), 0, 7, 7, {
		{"hook_integrity_watchdog_ignore_registers", {
			EEex_HookIntegrityWatchdogRegister.RAX, EEex_HookIntegrityWatchdogRegister.RDX, EEex_HookIntegrityWatchdogRegister.R8,
			EEex_HookIntegrityWatchdogRegister.R9, EEex_HookIntegrityWatchdogRegister.R10, EEex_HookIntegrityWatchdogRegister.R11
		}}},
		EEex_FlattenTable({
			{[[
				#MAKE_SHADOW_SPACE(48)
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], rcx
			]]},
			EEex_GenLuaCall("ST_Hook_RButtonPressed", {
				["args"] = {
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], rdi #ENDL", {rspOffset}} end,
				},
			}),
			{[[
				call_error:

				no_error:

				mov rcx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
				#DESTROY_SHADOW_SPACE
			]]},
		})
	)
end

function ST_Hook_RButtonPressed(buttonIndex)
	for i = 1, #ST_RButtonPressedListeners do
		local listener = ST_RButtonPressedListeners[i]
		listener(buttonIndex)
	end
end

ST_RButtonPressedListeners = {}
function ST_AddRButtonPressedListener(func)
	table.insert(ST_RButtonPressedListeners, func)
end
--[[
+--------------------+
| 命中力量修正值hook |
+--------------------+
--]]
function ST_RegisterHook_HitStrMod()
	EEex_HookAfterCallWithLabels(ST_GetEngineAddress(0x14034C97D), {
		{"hook_integrity_watchdog_ignore_registers", {
			EEex_HookIntegrityWatchdogRegister.RAX, EEex_HookIntegrityWatchdogRegister.RDX, EEex_HookIntegrityWatchdogRegister.R8,
			EEex_HookIntegrityWatchdogRegister.R9, EEex_HookIntegrityWatchdogRegister.R10, EEex_HookIntegrityWatchdogRegister.R11
		}}},
		EEex_FlattenTable({
			{[[
				#MAKE_SHADOW_SPACE(80)
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], r10
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)], r11
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)], r12
				mov r10d, dword ptr [r14 + 0x48]
				movsx r11d, word ptr [rbp + 0x58]
				movsx r12d, word ptr [rbp - 0x48]
			]]},
			EEex_GenLuaCall("ST_Hook_HitStrMod", {
				["args"] = {
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r10 #ENDL", {rspOffset}} end,
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r11 #ENDL", {rspOffset}} end,
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r12 #ENDL", {rspOffset}} end,
				},
			}),
			{[[
				call_error:
				
				no_error:
						
				mov r12, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)]
				mov r11, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
				mov r10, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
				#DESTROY_SHADOW_SPACE
			]]},
		})
	)
end

function ST_Hook_HitStrMod(spriteId, hitStrMod, hitStrExMod)
	local sprite = EEex_GameObject_Get(spriteId)
	hitStrMod = ST_Read_i32(hitStrMod)	-- 将无符号数转化为符号数
	hitStrExMod = ST_Read_i32(hitStrExMod)
	
    for i = 1, #ST_HitStrModListeners do
        local listener = ST_HitStrModListeners[i]
        listener(sprite, hitStrMod, hitStrExMod)
    end
	
	-- Infinity_DisplayString(Infinity_FetchString(sprite.m_baseStats.m_name) .. ': ' .. hitStrMod .. ', ' .. hitStrExMod)
end

ST_HitStrModListeners = {}
function ST_AddHitStrModListener(func)
    table.insert(ST_HitStrModListeners, func)
end
--[[
+----------+
| 背刺hook |
+----------+
--]]
-- A/B/C 通过 st_CurrentAttack 向 D 传递本次攻击的背刺条件状态。
-- 每次命中骰开始和 Hook D 消费后都会恢复默认状态。
local function ST_GenBackstabConditionLuaCall(luaFunction)
	return EEex_FlattenTable({
		{[[
			#MAKE_SHADOW_SPACE(96)
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], rax
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)], rcx
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)], rdx
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-32)], r8
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-40)], r9
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-48)], r10
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-56)], r11
		]]},
		EEex_GenLuaCall(luaFunction),
		{[[
			call_error:
			no_error:
			mov r11, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-56)]
			mov r10, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-48)]
			mov r9, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-40)]
			mov r8, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-32)]
			mov rdx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)]
			mov rcx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
			mov rax, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
			#DESTROY_SHADOW_SPACE
		]]},
	})
end

-- Hook A：原本因“既未隐形，也没有 ASSASSINATE & 0x03”而跳转失败时，
-- 记录缺少隐形并改为继续执行倍率判定。
function ST_RegisterHook_BackstabInvisibilityInvalid()
	EEex_HookConditionalJumpOnSuccessWithLabels(ST_GetEngineAddress(0x140390605), 0, {
		{"hook_integrity_watchdog_ignore_registers", {
			EEex_HookIntegrityWatchdogRegister.RAX, EEex_HookIntegrityWatchdogRegister.RDX, EEex_HookIntegrityWatchdogRegister.R8,
			EEex_HookIntegrityWatchdogRegister.R9, EEex_HookIntegrityWatchdogRegister.R10, EEex_HookIntegrityWatchdogRegister.R11
		}}},
		EEex_FlattenTable({
			ST_GenBackstabConditionLuaCall("ST_Hook_BackstabInvisibilityInvalid"),
			{[[
				jmp #L(jmp_fail)
			]]},
		})
	)
end

function ST_Hook_BackstabInvisibilityInvalid()
	st_CurrentAttack.backstabInvisibilityValid = false
end

local function ST_RegisterHook_BackstabPositionInvalid_At(address)
	EEex_HookConditionalJumpWithLabels(address, 0, {
		{"hook_integrity_watchdog_ignore_registers", {
			EEex_HookIntegrityWatchdogRegister.RAX, EEex_HookIntegrityWatchdogRegister.RDX, EEex_HookIntegrityWatchdogRegister.R8,
			EEex_HookIntegrityWatchdogRegister.R9, EEex_HookIntegrityWatchdogRegister.R10, EEex_HookIntegrityWatchdogRegister.R11
		}}},
		{},
		EEex_FlattenTable({
			ST_GenBackstabConditionLuaCall("ST_Hook_BackstabPositionInvalid"),
			{[[
				#MANUAL_HOOK_EXIT(1)
				jmp #L(ST_BackstabPosition_Continue)
			]]},
		})
	)
end

-- Hook B：模 16 朝向算法有两个位置失败出口，两处都需要转为记录后继续。
function ST_RegisterHook_BackstabPositionInvalid()
	ST_RegisterHook_BackstabPositionInvalid_At(ST_GetEngineAddress(0x1403906B0))
	ST_RegisterHook_BackstabPositionInvalid_At(ST_GetEngineAddress(0x1403906D2))
end

function ST_Hook_BackstabPositionInvalid()
	st_CurrentAttack.backstabPositionValid = false
end

-- Hook C：目标具有 IMMUNITY_TO_BACKSTAB 时记录免疫，然后跳到 Hook D。
-- 是否真正绕过免疫由 Hook D 和监听器统一决定。
function ST_RegisterHook_BackstabTargetImmune()
	EEex_HookBeforeRestoreWithLabels(ST_GetEngineAddress(0x140390748), 0, 7, 7, {
		{"hook_integrity_watchdog_ignore_registers", {
			EEex_HookIntegrityWatchdogRegister.RAX, EEex_HookIntegrityWatchdogRegister.RDX, EEex_HookIntegrityWatchdogRegister.R8,
			EEex_HookIntegrityWatchdogRegister.R9, EEex_HookIntegrityWatchdogRegister.R10, EEex_HookIntegrityWatchdogRegister.R11
		}}},
		EEex_FlattenTable({
			{[[
				#MAKE_SHADOW_SPACE(64)
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], r10
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)], r11
				mov r10d, dword ptr [rdi + 0x48]
				mov r11d, dword ptr [r15 + 0x48]
			]]},
			EEex_GenLuaCall("ST_Hook_BackstabTargetImmune", {
				["args"] = {
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r10 #ENDL", {rspOffset}} end,
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r11 #ENDL", {rspOffset}} end,
				},
			}),
			{[[
				call_error:
				
				no_error:
						
				mov r11, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
				mov r10, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
				#DESTROY_SHADOW_SPACE
				#MANUAL_HOOK_EXIT(0)
				jmp #L(ST_BackstabTargetImmune_Continue)
			]]},
		})
	)
end

function ST_Hook_BackstabTargetImmune(sourceSpriteOrId, targetSpriteOrId)
	st_CurrentAttack.backstabTargetImmune = true
	local sourceSprite = ST_GetSprite(sourceSpriteOrId)
	local targetSprite = ST_GetSprite(targetSpriteOrId)

	for i = 1, #ST_BackstabTargetImmuneListeners do
		if ST_BackstabTargetImmuneListeners[i](sourceSprite, targetSprite) == true then
			st_CurrentAttack.backstabImmunityBypassed = true
		end
	end
end

ST_BackstabTargetImmuneListeners = {}
function ST_AddBackstabTargetImmuneListener(func)
	table.insert(ST_BackstabTargetImmuneListeners, func)
end

ST_AddBackstabTargetImmuneListener(function(sourceSprite, targetSprite)	-- opcode#263 special == 1 无视背刺免疫，但背刺倍数减半
	local matchedEffects = ST_FindEffectsAll(sourceSprite, {m_effectId = 263, m_special = 1}, true)
	if #matchedEffects > 0 then
		return true
	end
end)

-- Hook D：在原版武器合法性检查 call 后统一裁决 A/B/C 记录的缺失条件。
function ST_RegisterHook_BackstabConditionDecision()
	EEex_HookAfterCallWithLabels(ST_GetEngineAddress(0x140390794), {
		{"hook_integrity_watchdog_ignore_registers", {
			EEex_HookIntegrityWatchdogRegister.RAX, EEex_HookIntegrityWatchdogRegister.RDX, EEex_HookIntegrityWatchdogRegister.R8,
			EEex_HookIntegrityWatchdogRegister.R9, EEex_HookIntegrityWatchdogRegister.R10, EEex_HookIntegrityWatchdogRegister.R11
		}}},
		EEex_FlattenTable({
			{[[
				#MAKE_SHADOW_SPACE(64)
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], r10
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)], r11
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)], rax
				mov r10d, dword ptr [rdi + 0x48]
				mov r11d, dword ptr [r15 + 0x48]
				mov qword ptr ss:[rsp + 56], 0x0
			]]},
			EEex_GenLuaCall("ST_Hook_BackstabConditionDecision", {
				["args"] = {
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r10 #ENDL", {rspOffset}} end,
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r11 #ENDL", {rspOffset}} end,
				},
				["returnType"] = EEex_LuaCallReturnType.Number,
				["labelSuffix"] = "_decision",
			}),
			{[[
				call_error_decision:
				
				no_error_decision:
						
				cmp qword ptr ss:[rsp + 56], 0x1
				je allow_backstab
				cmp qword ptr ss:[rsp + 56], 0x2
				je target_immune
				cmp qword ptr ss:[rsp + 56], 0x4
				je position_invalid

				invisibility_invalid:
				mov r11, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
				mov r10, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
				#DESTROY_SHADOW_SPACE(KEEP_ENTRY)
				#MANUAL_HOOK_EXIT(0)
				jmp #L(ST_BackstabInvisibilityInvalid)

				position_invalid:
				#RESUME_SHADOW_ENTRY
				mov r11, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
				mov r10, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
				#DESTROY_SHADOW_SPACE(KEEP_ENTRY)
				#MANUAL_HOOK_EXIT(0)
				jmp #L(ST_BackstabPositionInvalid)

				target_immune:
				#RESUME_SHADOW_ENTRY
				mov r11, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
				mov r10, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
				#DESTROY_SHADOW_SPACE(KEEP_ENTRY)
				mov rdx, #L(ST_BackstabTargetImmune_String)
				#MANUAL_HOOK_EXIT(0)
				jmp #L(ST_BackstabTargetImmune)
				
				allow_backstab:
				#RESUME_SHADOW_ENTRY
				mov rax, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)]
				mov r11, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
				mov r10, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
				#DESTROY_SHADOW_SPACE
			]]},
		})
	)
end

-- Hook D：所有被 A/B/C 放行的缺失条件都在这里统一裁决。
-- 监听器签名：listener(sourceSprite, targetSprite,
-- invisibilityValid, positionValid, targetImmune) -> number/nil
ST_BackstabConditionListeners = ST_BackstabConditionListeners or {}
function ST_AddBackstabConditionListener(func)
	table.insert(ST_BackstabConditionListeners, func)
end

function ST_Hook_BackstabConditionDecision(sourceSpriteOrId, targetSpriteOrId)
	local sourceSprite = ST_GetSprite(sourceSpriteOrId)
	local targetSprite = ST_GetSprite(targetSpriteOrId)
	
	local invisibilityValid = st_CurrentAttack.backstabInvisibilityValid
	local positionValid = st_CurrentAttack.backstabPositionValid
	local targetImmune = st_CurrentAttack.backstabTargetImmune
	local immunityBypassed = st_CurrentAttack.backstabImmunityBypassed

	local decisionValue = 0

	for i = 1, #ST_BackstabConditionListeners do
		local decision = ST_BackstabConditionListeners[i](
			sourceSprite,
			targetSprite,
			invisibilityValid,
			positionValid,
			targetImmune,
			immunityBypassed
		)
		if type(decision) == "number" then
			decisionValue = decisionValue + decision
		end
	end

	if decisionValue > 0 then
		return 1
	elseif decisionValue < 0 then
		return 3
	end

	if not invisibilityValid then
		return 3
	elseif not positionValid then
		return 4
	elseif targetImmune and not immunityBypassed then
		return 2
	end

	return 1
end

-- 原版武器 bit 22 检查通过后的共同落点；到这里才通知旧监听器背刺成功。
function ST_RegisterHook_BackstabSuccess()
	EEex_HookBeforeRestoreWithLabels(ST_GetEngineAddress(0x1403907A3), 0, 7, 7, {
		{"hook_integrity_watchdog_ignore_registers", {
			EEex_HookIntegrityWatchdogRegister.RAX, EEex_HookIntegrityWatchdogRegister.RDX, EEex_HookIntegrityWatchdogRegister.R8,
			EEex_HookIntegrityWatchdogRegister.R9, EEex_HookIntegrityWatchdogRegister.R10, EEex_HookIntegrityWatchdogRegister.R11
		}}},
		EEex_FlattenTable({
			{[[
				#MAKE_SHADOW_SPACE(64)
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], r10
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)], r11
				mov r10d, dword ptr [rdi + 0x48]
				mov r11d, dword ptr [r15 + 0x48]
			]]},
			EEex_GenLuaCall("ST_Hook_BackstabSuccess", {
				["args"] = {
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r10 #ENDL", {rspOffset}} end,
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r11 #ENDL", {rspOffset}} end,
				},
			}),
			{[[
				call_error:
				
				no_error:
						
				mov r11, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
				mov r10, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
				#DESTROY_SHADOW_SPACE
			]]},
		})
	)
end

function ST_Hook_BackstabSuccess(sourceSpriteOrId, targetSpriteOrId)
	local sourceSprite = ST_GetSprite(sourceSpriteOrId)
	local targetSprite = ST_GetSprite(targetSpriteOrId)

	for i = 1, #ST_BackstabSuccessListeners do
		ST_BackstabSuccessListeners[i](sourceSprite, targetSprite)
	end
end

ST_BackstabSuccessListeners = {}
function ST_AddBackstabSuccessListener(func)
	table.insert(ST_BackstabSuccessListeners, func)
end

ST_AddBackstabSuccessListener(function(sourceSprite, targetSprite)	-- 绕过背刺免疫后，背刺倍数减半
	if st_CurrentAttack.backstabTargetImmune and st_CurrentAttack.backstabImmunityBypassed then
		sourceSprite.m_derivedStats.m_nBackstabDamageMultiplier = math.floor((sourceSprite.m_derivedStats.m_nBackstabDamageMultiplier + 1) / 2)
	end
end)


--[[
+-------------+
| 法术DC Hook |
+-------------+
--]]
function ST_RegisterHook_SaveDCMod_At(address)
	EEex_HookAfterCallWithLabels(address, {
		{"hook_integrity_watchdog_ignore_registers", {
			EEex_HookIntegrityWatchdogRegister.RAX, EEex_HookIntegrityWatchdogRegister.RDX, EEex_HookIntegrityWatchdogRegister.R8,
			EEex_HookIntegrityWatchdogRegister.R9, EEex_HookIntegrityWatchdogRegister.R10, EEex_HookIntegrityWatchdogRegister.R11
		}}},
		EEex_FlattenTable({
			{[[
				#MAKE_SHADOW_SPACE(48)
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], rax
				mov eax, dword ptr [rsi + 0x48]
			]]},
			EEex_GenLuaCall("ST_Hook_SaveDCMod", {
				["args"] = {
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], rax #ENDL", {rspOffset}} end,
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], rbx #ENDL", {rspOffset}} end,
				},
				["returnType"] = EEex_LuaCallReturnType.Number,
			}),
			{[[
				call_error:

				no_error:
				#DESTROY_SHADOW_SPACE
			]]},
		})
	)
end

function ST_RegisterHook_SaveDCMod()
	for _, address in ipairs({
		ST_GetEngineAddress(0x14024ED06), -- 常规施法
		ST_GetEngineAddress(0x1401FB2F2), -- 物品能力
	}) do
		ST_RegisterHook_SaveDCMod_At(address)
	end
end

function ST_Hook_SaveDCMod(spriteId, effectAddress)
	local sprite = EEex_GameObject_Get(spriteId)
	local effect = EEex_PtrToUD(effectAddress, "CGameEffect")
	
    for i = 1, #ST_SaveDCModListeners do
        local listener = ST_SaveDCModListeners[i]
        listener(sprite, effect)
    end
	
	local kitIdToSpecializationId = {
		[0x00000040] = 1, -- Abjurer
		[0x00000080] = 2, -- Conjurer
		[0x00000100] = 3, -- Diviner
		[0x00000200] = 4, -- Enchanter
		[0x00000400] = 5, -- Illusionist
		[0x00000800] = 6, -- Invoker
		[0x00001000] = 7, -- Necromancer
		[0x00002000] = 8, -- Transmuter
		[0x80000000] = 9, -- Generalist
	}
	
	local allKitIds = ST_GetAllKitIds(sprite, true)
	
	local isGeneralist = false
	for i = 1, #allKitIds do
		local specializationId = kitIdToSpecializationId[allKitIds[i]]
		if specializationId then
			return specializationId
		elseif allKitIds[i] == 0x4000 then
			isGeneralist = true
		end
	end
	
	if isGeneralist then
		return 9
	else
		return 0
	end
end

ST_SaveDCModListeners = {}
function ST_AddSaveDCModListener(func)
    table.insert(ST_SaveDCModListeners, func)
end
--[[
+--------------+
| SaveMod Hook |
+--------------+
--]]
function ST_RegisterHook_SaveMod()
	EEex_HookAfterCallWithLabels(ST_GetEngineAddress(0x1401CD64B), {
		{"hook_integrity_watchdog_ignore_registers", {
			EEex_HookIntegrityWatchdogRegister.RAX, EEex_HookIntegrityWatchdogRegister.RDX, EEex_HookIntegrityWatchdogRegister.R8,
			EEex_HookIntegrityWatchdogRegister.R9, EEex_HookIntegrityWatchdogRegister.R10, EEex_HookIntegrityWatchdogRegister.R11
		}}},
		EEex_FlattenTable({
			{[[
				#MAKE_SHADOW_SPACE(48)
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], rax
				mov eax, dword ptr [rsi + 0x48]
			]]},
			EEex_GenLuaCall("ST_Hook_SaveMod", {
				["args"] = {
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], rax #ENDL", {rspOffset}} end,
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], rbx #ENDL", {rspOffset}} end,
				},
				["returnType"] = EEex_LuaCallReturnType.Number,
			}),
			{[[
				call_error:

				no_error:
				#DESTROY_SHADOW_SPACE
			]]},
		})
	)
end

function ST_Hook_SaveMod(spriteId, effectAddress)
	local sprite = EEex_GameObject_Get(spriteId)
	local effect = EEex_PtrToUD(effectAddress, "CGameEffect")
	
    for i = 1, #ST_SaveModListeners do
        local listener = ST_SaveModListeners[i]
        listener(sprite, effect)
    end
	
	local kitIdToSpecializationId = {
		[0x00000040] = 1, -- Abjurer
		[0x00000080] = 2, -- Conjurer
		[0x00000100] = 3, -- Diviner
		[0x00000200] = 4, -- Enchanter
		[0x00000400] = 5, -- Illusionist
		[0x00000800] = 6, -- Invoker
		[0x00001000] = 7, -- Necromancer
		[0x00002000] = 8, -- Transmuter
		[0x80000000] = 9, -- Generalist
	}
	
	local allKitIds = ST_GetAllKitIds(sprite, true)
	
	local isGeneralist = false
	for i = 1, #allKitIds do
		local specializationId = kitIdToSpecializationId[allKitIds[i]]
		if specializationId then
			return specializationId
		elseif allKitIds[i] == 0x4000 then
			isGeneralist = true
		end
	end
	
	if isGeneralist then
		return 9
	else
		return 0
	end
end

ST_SaveModListeners = {}
function ST_AddSaveModListener(func)
    table.insert(ST_SaveModListeners, func)
end

--[[
+--------------------+
| Chargen Class hook |
+--------------------+
--]]
st_CharGenMode = nil	-- 1: character creation; 2: dual class
charGenSprite = nil
charGenClassId = 0

function ST_RegisterHook_CharGenClassDone()
	EEex_HookAfterCallWithLabels(ST_GetEngineAddress(0x1402B8C7A), {
		{"hook_integrity_watchdog_ignore_registers", {
			EEex_HookIntegrityWatchdogRegister.RAX, EEex_HookIntegrityWatchdogRegister.RDX, EEex_HookIntegrityWatchdogRegister.R8,
			EEex_HookIntegrityWatchdogRegister.R9, EEex_HookIntegrityWatchdogRegister.R10, EEex_HookIntegrityWatchdogRegister.R11
		}}},
		EEex_FlattenTable({
			{[[
				#MAKE_SHADOW_SPACE(48)
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], r10
				mov r10d, dword ptr [r14+0x770]
			]]},
			EEex_GenLuaCall("ST_Hook_CharGenClassDone", {
				["args"] = {
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r10 #ENDL", {rspOffset}} end,
				},
				["returnType"] = EEex_LuaCallReturnType.Number,
			}),
			{[[
				call_error:
				no_error:
				mov r10, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
				#DESTROY_SHADOW_SPACE
			]]},
		})
	)
end

function ST_Hook_CharGenClassDone(spriteId)
	local sprite = EEex_GameObject_Get(spriteId)
	if not sprite then
		return
	end

	charGenSprite = sprite
	charGenClassId = sprite.m_typeAI.m_Class
	st_CharGenMode = 1

	for i = 1, #ST_CharGenClassDoneListeners do
		ST_CharGenClassDoneListeners[i](sprite, charGenClassId)
	end
end

ST_CharGenClassDoneListeners = ST_CharGenClassDoneListeners or {}
function ST_AddCharGenClassDoneListener(func)
	table.insert(ST_CharGenClassDoneListeners, func)
end

function ST_GetCurrentCharGenSprite(spriteId)
	if st_CharGenMode == 1 then
		return charGenSprite
	end

	if spriteId then
		return EEex_GameObject_Get(spriteId)
	end

	if currentID == nil then
		return nil
	end

	return EEex_GameObject_Get(currentID)
end

--[[
+--------------------------+
| Proficiency maximum hook |
+--------------------------+
--]]

function ST_RegisterHook_ProficiencyUIMax()
	EEex_HookBeforeRestoreWithLabels(ST_GetEngineAddress(0x1402C75C1), 0, 8, 8, {
		{"hook_integrity_watchdog_ignore_registers", {
			EEex_HookIntegrityWatchdogRegister.RAX, EEex_HookIntegrityWatchdogRegister.RCX, EEex_HookIntegrityWatchdogRegister.RDX,
			EEex_HookIntegrityWatchdogRegister.R8, EEex_HookIntegrityWatchdogRegister.R9, EEex_HookIntegrityWatchdogRegister.R10,
			EEex_HookIntegrityWatchdogRegister.R11,
		}}},
		EEex_FlattenTable({
			{[[
				#MAKE_SHADOW_SPACE(96)
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)],  rax
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)], rcx
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)], rdx
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-32)], r8
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-40)], r9
				mov r8d, dword ptr ss:[rsp+#LAST_FRAME_TOP(0x78)]
			]]},
			EEex_GenLuaCall("ST_Hook_ProficiencyMax", {
				["args"] = {
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], rsi #ENDL", {rspOffset}} end,
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r8 #ENDL", {rspOffset}} end,
				},
				["returnType"] = EEex_LuaCallReturnType.Number,
			}),
			{[[
				call_error:
				no_error:
				mov dword ptr ss:[rsp+#LAST_FRAME_TOP(0x78)], eax
				mov r9,  qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-40)]
				mov r8,  qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-32)]
				mov rdx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)]
				mov rcx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
				mov rax, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
				#DESTROY_SHADOW_SPACE
			]]},
		})
	)
end

function ST_RegisterHook_ProficiencyActualMax()
	EEex_HookBeforeRestoreWithLabels(ST_GetEngineAddress(0x1402BDC31), 0, 8, 8, {
		{"hook_integrity_watchdog_ignore_registers", {
			EEex_HookIntegrityWatchdogRegister.RAX, EEex_HookIntegrityWatchdogRegister.RCX, EEex_HookIntegrityWatchdogRegister.RDX,
			EEex_HookIntegrityWatchdogRegister.R8, EEex_HookIntegrityWatchdogRegister.R9, EEex_HookIntegrityWatchdogRegister.R10,
			EEex_HookIntegrityWatchdogRegister.R11,
		}}},
		EEex_FlattenTable({
			{[[
				#MAKE_SHADOW_SPACE(80)
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)],  rax
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)], rcx
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)], rdx
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-32)], r8
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-40)], r9
				movsxd rax, dword ptr ss:[rbp-0x9]
			]]},
			EEex_GenLuaCall("ST_Hook_ProficiencyMax", {
				["args"] = {
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], rsi #ENDL", {rspOffset}} end,
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], rax #ENDL", {rspOffset}} end,
				},
				["returnType"] = EEex_LuaCallReturnType.Number,
			}),
			{[[
				call_error:
				no_error:
				mov dword ptr ss:[rbp-0x9], eax
				mov r9,  qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-40)]
				mov r8,  qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-32)]
				mov rdx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)]
				mov rcx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
				mov rax, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
				#DESTROY_SHADOW_SPACE
			]]},
		})
	)
end

function ST_Hook_ProficiencyMax(proficiencyId, proficiencyMax)
	local sprite = ST_GetCurrentCharGenSprite()
	local result = proficiencyMax
	if not sprite then
		return result
	end

	for i = 1, #ST_ProficiencyMaxListeners do
		local listenerResult = ST_ProficiencyMaxListeners[i](sprite, proficiencyId, result)
		if listenerResult ~= nil then
			result = listenerResult
		end
	end

	return result
end

ST_ProficiencyMaxListeners = ST_ProficiencyMaxListeners or {}
function ST_AddProficiencyMaxListener(func)
	table.insert(ST_ProficiencyMaxListeners, func)
end

-- 完全锁定技能面板中的熟练度，同时禁止增加和减少
ST_ProficiencyLockListeners = ST_ProficiencyLockListeners or {}
function ST_AddProficiencyLockListener(func)
	table.insert(ST_ProficiencyLockListeners, func)
end

function ST_IsProficiencyLocked(proficiencyIndex)
	if proficiencyIndex == nil or chargen == nil or chargen.proficiency == nil then
		return false
	end

	local proficiency = chargen.proficiency[proficiencyIndex]
	if proficiency == nil then
		return false
	end

	local sprite = ST_GetCurrentCharGenSprite()
	if sprite == nil then
		return false
	end

	for i = 1, #ST_ProficiencyLockListeners do
		if ST_ProficiencyLockListeners[i](sprite, proficiency.id, proficiencyIndex) then
			return true
		end
	end

end

-- UI.MENU 的单击和长按都会先经过这两个全局判断函数。
-- 保存原函数，避免重复加载 M_Stick 时形成递归包装。
ST_OriginalPlusButtonClickable = ST_OriginalPlusButtonClickable or plusButtonClickable
ST_OriginalMinusButtonClickable = ST_OriginalMinusButtonClickable or minusButtonClickable

function plusButtonClickable(proficiencyIndex)
	if ST_IsProficiencyLocked(proficiencyIndex) then
		return false
	end

	return ST_OriginalPlusButtonClickable(proficiencyIndex)
end

function minusButtonClickable(proficiencyIndex)
	if ST_IsProficiencyLocked(proficiencyIndex) then
		return false
	end

	return ST_OriginalMinusButtonClickable(proficiencyIndex)
end

--[[
+--------------------+
| Physical attack result hook |
+--------------------+
--]]
function ST_RegisterHook_AttackResult()
	-- Hook the original `je` directly so EEex rebuilds its relative target.
	EEex_HookBeforeConditionalJumpWithLabels(ST_GetEngineAddress(0x14039E8AF), 0, {
		{"hook_integrity_watchdog_ignore_registers", {
			EEex_HookIntegrityWatchdogRegister.RAX, EEex_HookIntegrityWatchdogRegister.RCX, EEex_HookIntegrityWatchdogRegister.RDX,
			EEex_HookIntegrityWatchdogRegister.R8, EEex_HookIntegrityWatchdogRegister.R9, EEex_HookIntegrityWatchdogRegister.R10,
			EEex_HookIntegrityWatchdogRegister.R11,
		}}},
		EEex_FlattenTable({
			{[[
				#MAKE_SHADOW_SPACE(96)
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)],  rax
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)], rcx
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)], rdx
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-32)], r8
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-40)], r9
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-48)], r10
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-56)], r11
				mov r10d, r14d
			]]},
			EEex_GenLuaCall("ST_Hook_AttackResult", {
				["args"] = {
					function(rspOffset) return {"mov qword ptr ss:[rsp+#$(1)], r10 #ENDL", {rspOffset}} end,
				},
			}),
			{[[
				call_error:

				no_error:
				mov r11, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-56)]
				mov r10, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-48)]
				mov r9,  qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-40)]
				mov r8,  qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-32)]
				mov rdx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)]
				mov rcx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
				mov rax, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
				#DESTROY_SHADOW_SPACE

				; Recreate the flags consumed by the original je.
				test r14d, r14d
			]]},
		})
	)
end

function ST_Hook_AttackResult(hit)
	local sourceSprite = st_CurrentAttack.sourceSprite
	local targetSprite = st_CurrentAttack.targetSprite
	if sourceSprite == nil or targetSprite == nil then
		return
	end

	local didHit = hit ~= 0
	for i = 1, #ST_AttackResultListeners do
		ST_AttackResultListeners[i](sourceSprite, targetSprite, didHit)
	end
end

ST_AttackResultListeners = ST_AttackResultListeners or {}
function ST_AddAttackResultListener(func)
	table.insert(ST_AttackResultListeners, func)
end

--[[
+------------------+
| 执行hook注册函数 |
+------------------+
--]]
EEex_DisableCodeProtection()
ST_RegisterHook_CharGenClassDone()
ST_RegisterHook_ProficiencyUIMax()
ST_RegisterHook_ProficiencyActualMax()
ST_RegisterHook_HideInPlainSight()

ST_RegisterHook_AttackIndex()
ST_RegisterHook_AttackCancel()
ST_RegisterHook_HitRoll()
ST_RegisterHook_HitMod()
ST_RegisterHook_AttackDamMod()
ST_RegisterHook_CriticalHitMod()
ST_RegisterHook_CriticalHit()
ST_RegisterHook_AttackResult()

ST_RegisterHook_ButtonPressed()
ST_RegisterHook_RButtonPressed()

-- ST_RegisterHook_HitStrMod()

ST_RegisterHook_BackstabInvisibilityInvalid()
ST_RegisterHook_BackstabPositionInvalid()
ST_RegisterHook_BackstabTargetImmune()
ST_RegisterHook_BackstabConditionDecision()
ST_RegisterHook_BackstabSuccess()

ST_RegisterHook_SaveDCMod()
ST_RegisterHook_SaveMod()
EEex_EnableCodeProtection()



