#if defined _tf2_cloakapi_included_
  #endinput
#endif

#define _tf2_cloakapi_included_

// --------------

enum TF2CloakAPI_HookType
{
	OnActivateInvisibilityWatch,
	OnCleanupInvisibilityWatch,
	OnUpdateCloakMeter
};

/**
 * Hooks a player so they receive info about the forwards.
 * 
 * @param iClient          Codename to use for your authentication type.
 * @param hookType         Check TF2CloakAPI_HookType
 */
native void TF2CloakAPI_Hook(int iClient, TF2CloakAPI_HookType hookType, TF2CloakAPICB callback);

/**
 * Unhooks a player so they stop receiving info about the forwards.
 * The functions get automatically unhooked if the player disconnects.
 * 
 * @param iClient          Codename to use for your authentication type.
 * @param hookType         Check TF2CloakAPI_HookType
 */
native void TF2CloakAPI_Unhook(int iClient, TF2CloakAPI_HookType hookType, TF2CloakAPICB callback);

typeset TF2CloakAPICB
{
	// OnUpdateCloakMeter
	function Action(int iClient, float flCloakMeter);

	// OnCleanupInvisibilityWatch
	function Action(int iClient, int iCloak, bool bIsEventDeath);

	// OnActivateInvisibilityWatch
	function Action(int iClient, int iCloak, float flCloakMeter, bool& bReturnValue);
};

/**
 * Called when a player's watch gets activated ( either enabled or disabled ). You don't have to check for validity.
 * 
 * @param iClient          Self-explanatory
 * @param iCloak           Client's watch entity index.
 * @param flCloakMeter     The value of the client's cloak meter.
 * @param bReturnValue     Bool by reference. You can decide to change it. Check the source code to see what it affects.
 * 
 * @return                 Plugin_Continue = Nothing happens to the original function. You can use it to detect the watch's
 *                                           activation and do your own stuff.
 * 
 *                         Plugin_Changed  = Same as Plugin_Continue but it lets you change the return value.
 *
 *                         Plugin_Handled  = Skips the original function. Use this when you want to give your own
 *                                           custom cloak effect andyou don't want the player to cloak.
 *                                           This does some basic stuff like calling CTFWeaponInvis::SetCloakRates().
 *                         Plugin_Stop     = Same as above, but it doesn't call CTFWeaponInvis::SetCloakRates().
 * 
 */
 /* OnActivateInvisibilityWatch ( CTFWeaponInvis::ActivateInvisibilityWatch ) */


/** 
 * This function gets called when the player has changed loadouts or has done something else
 * that causes us to clean up any side effects of our watch. The original function doesn't get called
 * when the player dies / respawns.
 * 
 * @param iClient          Self-explanatory
 * @param iCloak           Client's watch entity index.
 * @param bIsEventDeath    If it got called because the player died. Made it optional since the detoured function
 *                         doesn't get called when a player dies but I am manually doing it.
 * 
 * @return                 Plugin_Continue = Nothing happens to the original function.
 * 
 *                         Plugin_Changed  = Nothing happens to the original function.
 *
 *                         Plugin_Handled & Plugin_Stop = Skips the original function. Use it to clean up YOUR custom effects.
 * 
 */
 /* OnCleanupInvisibilityWatch ( CTFWeaponInvis::CleanupInvisibilityWatch ) */

/**
 * This function gets called every tick to manage the player's cloak regen & drain.
 * 
 * @param iClient          Self-explanatory
 * @param flCloakMeter     The value of the client's cloak meter.
 * 
 * @return                 Plugin_Continue = Nothing happens to the original function.
 * 
 *                         Plugin_Changed  = Nothing happens to the original function.
 *
 *                         Plugin_Handled & Plugin_Stop = Skips the original function. Use it to manage your own regen / drain.
 * 
 */
 /* OnUpdateCloakMeter ( CTFPlayerShared::UpdateCloakMeter ) */

// -------------- 

public SharedPlugin __pl_tf2_cloakapi = 
{
	name = "tf2_cloakapi",
	file = "tf2_cloakapi.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_tf2_cloakapi_SetNTVOptional() {
	MarkNativeAsOptional("TF2CloakAPI_Hook");
	MarkNativeAsOptional("TF2CloakAPI_Unhook");
}
#endif