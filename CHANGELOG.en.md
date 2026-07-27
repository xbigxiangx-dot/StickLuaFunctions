# StickLuaFunctions Changelog

## v0.8.2

### Engineering and Compatibility

- Added Simplified Chinese and English language options to the WeiDU installer.

## v0.8.1

### Added

- Listener `ST_AddHideInPlainSightListener`: Hooks the hide-in-plain-sight check. The input parameter is `sprite`; returning `true` allows the character to hide in plain sight.
- Function `ST_GetAllKitIds(sprite, includeGeneralist)`: Returns the character's original and additional kit IDs as a table. Generalist mages are excluded by default and included when `includeGeneralist == true`.
- Listener `ST_AddSaveModListener`: Hooks saving throw modifier calculations. The input parameters are `sprite, effect`.

### Changed

- Hook `ST_RegisterHook_HideInPlainSight`: Improved the hide-in-plain-sight implementation and added recognition of Shadowdancer when assigned as an additional kit by StickMultiKit.

## v0.8.0

### Added

- Function `ST_MatchIds(sprite, idsIndex, idsValue)`: Matches a target by IDS type, including mask checks for `ALIGN.IDS` and checks against additional kit IDs.
- Function `ST_MatchKitId(sprite, kitId)`: Checks whether a character has the specified kit ID, including additional kit IDs.
- Function `ST_SetExKitId(sprite, exKitIndex, kitId)`: Writes an additional kit ID to the character-local variables `ST_ExKit#_High` and `ST_ExKit#_Low`, where `#` is `exKitIndex`.
- Function `ST_GetExKitId(sprite, exKitIndex)`: Reads an additional kit ID from the corresponding character-local variables.

### Engineering and Compatibility

- 2DA variables now use the `_2DA` suffix.

## v0.7.0

### Added

- Function `ST_GetSprite(spriteOrId)`: Resolves either a `spriteId` or `sprite` to a `sprite`, allowing selected hook functions to accept both input types.
- Function `ST_GetResRef(m_resRef)`: Reads a resref string.
- Function `ST_ApplyWeaponHitEffects(sourceSprite, targetSprite, weaponRes, abilityIndex)`: Applies on-hit effects from a weapon ability.
- Function `ST_ApplyCriticalEffects(sourceSprite, targetSprite, hitOrMiss, weaponType)`: Applies EFF effects from critical-hit or critical-miss entries.
- Listener `ST_AddAttackDamModListener`: Hooks physical attack damage modifiers. The inputs are `sourceSprite, targetSprite, damModified`; the return value can override `damModified`.
- Listener `ST_AddMeleeAttackListener`: Hooks the point after a physical attack hits. The inputs are `sourceSprite, targetSprite, bBlocked`.
- Listener `ST_AddSaveDCModListener`: Hooks saving throw DC calculations for spell and item abilities. The inputs are `sprite, effect`.
- Function `ST_RunMeleeAttackListeners(sourceSprite, targetSprite, bBlocked)`: Runs listeners registered through `ST_AddMeleeAttackListener`, allowing real and simulated attacks to share the same listener path.

### Changed

- Listener `ST_AddHitRollListener`: Added reroll handling. A positive return value rerolls with advantage; a negative return value rerolls with disadvantage.
- Global state `st_currentAttack`: Stores the current attacker, target, final attack roll (0–19), and `sourceTag`.
- Renamed `ST_HitRollModListener` to `ST_HitModListener` to better describe its purpose.
- Function `ST_GetCurrentWeapon(sprite, getCurrentAttack)`: When `getCurrentAttack == true`, the second return value is now `fightingStyle` and the third is `isLeftAttack`.
- Function `ST_GetCurrentWeapon(sprite, getCurrentAttack)`: When `getCurrentAttack == false`, added `isLeftAttack` as the fourth return value.
- Function `ST_FindEffectsAll(sprite, filter, firstOnly)`: When `firstOnly == true`, searches equipped, timed, and persistent effects in that order and stops after the first match.
- Function `ST_MockAttack`: Expanded to simulate melee and ranged physical attacks; added hit-roll, hit-modifier, and damage-modifier hooks; separated critical hits from critical misses; added IDS hit and damage modifiers; and resets `st_currentAttack.sourceTag` after the simulated attack.
- Renamed `ST_AddBackstabListeners` to `ST_AddBackstabListener`. The backstab hook now includes the success path, and its inputs are `sourceSprite, targetSprite, isBackstabSuccessful`. On the failure path, returning `true` forces the attack into the successful-backstab path.

## v0.6.2-Alpha

### Fixed

- Function `ST_MockAttack`: Fixed weapon on-hit effects not being applied.
- Function `ST_MockAttack`: Fixed an incorrect message.

## v0.6.1-Alpha

### Fixed

- Listener `ST_AddHitRollListener`: Fixed a case where `targetSprite` could be read incorrectly.

## v0.6.0-Alpha

### Added

- Function `ST_HasState(sprite, state)`.

### Changed

- Function `ST_MockAttack`: Added hit modifiers for melee attacks against distant targets and ranged attacks against nearby targets.
- Function `ST_MockAttack`: Added hit modifiers for invisible status.
- Function `ST_MockAttack`: Added support for critical-miss modifiers.

## v0.5.0-Alpha

### Added

- Listener `ST_AddBackstabListeners`: Hooks backstab scenarios. The inputs are `sourceSprite, isBackstabSuccessful`; this version contains only the failure path.

### Changed

- Function `ST_GetCurrentWeapon(sprite, getCurrentAttack)`: `getCurrentAttack` now defaults to `false` when omitted.
- Function `ST_FindEffects(effectList, filter, firstOnly)`: `firstOnly` now defaults to `false`; when `true`, the function returns immediately after finding the first matching effect.

## v0.4.1-Alpha

### Changed

- Function `ST_MockAttack`: Can now run without `weaponRes`.
- Function `ST_MockAttack`: Added support for weapons with multiple abilities.

### Fixed

- Function `ST_MockAttack`: Fixed a calculation error caused by AC type.

## v0.4.0-Alpha

### Added

- Listener `ST_AddButtonPressedListener`: Hooks button clicks. The input parameter is `buttonIndex`.

## v0.3.0-Alpha

### Added

- Function `ST_ChangeMemorizedSpellNum(sprite, spellName, numToChange, spellType, spellLevel)`.

### Changed

- Renamed `ST_SpellNumMaxReset` to `ST_SetMemorizedSpellNumMax`; its inputs are now `sprite, spellName, numToSetMax, spellType, spellLevel`.
- Renamed `ST_SpellNumReset` to `ST_SetMemorizedSpellNum`; its inputs are now `sprite, spellName, numToSet, spellType, spellLevel`.
- Renamed `ST_SpellResReset` to `ST_ChangeMemorizedSpellNum`; its inputs are now `sprite, spellName, spellNameNew, spellType, spellLevel`.

### Compatibility

- All features that call the functions above must be updated to use the new names and parameters.

## v0.2.0-Alpha

### Added

- Listener `ST_AddHitRollListener`: Hooks attack-roll generation. The inputs are `sourceSprite, targetSprite, hitRoll`.

### Changed

- Function `ST_GetCurrentWeapon`: Uses the `fightingStyle` return value to describe all weapon styles consistently.

## v0.1.0-Alpha

### Added

- Hook `ST_Hook_HideInPlainSight`: Allows hiding in plain sight when the `special` value of opcode 275 is 1.
- Function `ST_GetCurrentWeapon`: Added the `isSingleWeapon` return value.
