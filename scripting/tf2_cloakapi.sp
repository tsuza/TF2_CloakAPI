#include <sourcemod>

#include <sdktools>
#include <sdkhooks>
#include <dhooks>

#include <tf2>
#include <tf2_stocks>

#include <stocksoup/memory>

#pragma semicolon 1;
#pragma newdecls required;

#define PLUGIN_NAME         "[TF2] Claok API"
#define PLUGIN_AUTHOR       "Zabaniya001"
#define PLUGIN_DESCRIPTION  "An API with various hooks for spy's watch for developers to use."
#define PLUGIN_VERSION      "1.0.0"
#define PLUGIN_URL          "https://github.com/Zabaniya001/TF2_CloakAPI"

#define TF2MAXPLAYERS 36

public Plugin myinfo =
{
	name        =   PLUGIN_NAME,
	author      =   PLUGIN_AUTHOR,
	description =   PLUGIN_DESCRIPTION,
	version     =   PLUGIN_VERSION,
	url         =   PLUGIN_URL
}

// ||─────────────────────────────────────────────────────────────────────────||
// ||                             GLOBAL VARIABLES                            ||
// ||─────────────────────────────────────────────────────────────────────────||

enum TF2CloakAPI_HookType
{
	OnActivateInvisibilityWatch,
	OnCleanupInvisibilityWatch,
	OnUpdateCloakMeter
};

#define MAX_HOOKS view_as<int>(TF2CloakAPI_HookType) + 1

enum struct ForwardStorageInfo_t
{
	PrivateForward m_hForward[MAX_HOOKS];

	ArrayList m_hPluginList[MAX_HOOKS];

	bool InitializeForward(TF2CloakAPI_HookType hookType)
	{
		switch(hookType)
		{
			case OnActivateInvisibilityWatch:
			{
				this.m_hForward[hookType] = new PrivateForward(ET_Hook, Param_Cell, Param_Cell, Param_Float, Param_Cell);
			}
			case OnCleanupInvisibilityWatch:
			{
				this.m_hForward[hookType] = new PrivateForward(ET_Hook, Param_Cell, Param_Cell);
			}
			case OnUpdateCloakMeter:
			{
				this.m_hForward[hookType] = new PrivateForward(ET_Hook, Param_Cell, Param_Float);
			}
			default:
			{
				return false;
			}
		}

		return true;
	}

	void AddFunctionToList(Handle hPlugin, Function hFunction, TF2CloakAPI_HookType hookType)
	{
		this.m_hForward[hookType].AddFunction(hPlugin, hFunction);

		// If it's null initialize it.
		if(!this.m_hPluginList[hookType])
		{
			this.m_hPluginList[hookType] = new ArrayList();

			this.m_hPluginList[hookType].Push(hPlugin);

			return;
		}

		int iIndex = this.m_hPluginList[hookType].FindValue(hPlugin);

		// Making sure we don't make unnecessary duplicates.
		if(iIndex != -1)
			return;

		this.m_hPluginList[hookType].Push(hPlugin);

		return;
	}

	void RemoveFunctionFromList(Handle hPlugin, Function hFunction, TF2CloakAPI_HookType hookType)
	{
		if(this.m_hForward[hookType])
		{
			this.m_hForward[hookType].RemoveFunction(hPlugin, hFunction);

			// If there aren't any forwards delete it.
			if(!GetForwardFunctionCount(this.m_hForward[hookType]))
				delete this.m_hForward[hookType];
		}

		if(!this.m_hPluginList[hookType])
			return;

		int iIndex = this.m_hPluginList[hookType].FindValue(hPlugin);

		// Making sure the plugin handle exists in the list.
		if(iIndex != -1)
			this.m_hPluginList[hookType].Erase(iIndex);

		// If there are no plugins in the list ( so no forwads ) delete the ArrayList.
		if(!this.m_hPluginList[hookType].Length)
			delete this.m_hPluginList[hookType];

		return;
	}

	void RemoveAllFunctionsFromForward(TF2CloakAPI_HookType hookType)
	{
		if(!this.m_hForward[hookType])
			return;

		for(int iForwardIndex = 0; iForwardIndex < this.m_hPluginList[hookType].Length; iForwardIndex++)
		{
			this.m_hForward[hookType].RemoveAllFunctions(this.m_hPluginList[hookType].Get(iForwardIndex));
		}

		delete this.m_hPluginList[hookType];
		delete this.m_hForward[hookType];

		return;
	}
}

ForwardStorageInfo_t g_PrivateForwardStorageList[TF2MAXPLAYERS];

// SDKCalls
Handle g_SDKCallGetBaseEntity;
Handle g_SDKCallSetCloakRates;

// Offsets
Address g_offset_CTFPlayerShared_pOuter;

// ||──────────────────────────────────────────────────────────────────────────||
// ||                               SOURCEMOD API                              ||
// ||──────────────────────────────────────────────────────────────────────────||

public void OnPluginStart() 
{
	//------------
	// General
	//------------

	// Events
	HookEvent("player_death", Event_PlayerDeath);

	// GameData file
	GameData hGameData = new GameData("tf2.cloak_gamedata");

	if(!hGameData)
		SetFailState("Failed to get gamedata: tf2.cloak_gamedata");

	//------------
	// SDKCalls
	//------------

	// CBaseEntity::GetBaseEntity()
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBaseEntity::GetBaseEntity()");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_SDKCallGetBaseEntity = EndPrepSDKCall();

	if(!g_SDKCallGetBaseEntity)
		SetFailState("Failed to setup SDKCall for CBaseEntity::GetBaseEntity()");

	// CTFWeaponInvis::SetCloakRates()
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFWeaponInvis::SetCloakRates()");
	g_SDKCallSetCloakRates = EndPrepSDKCall();

	if(!g_SDKCallSetCloakRates)
		SetFailState("Failed to setup SDKCall for CTFWeaponInvis::SetCloakRates()");

	//------------
	// DHooks
	//------------

	// CTFWeaponInvis::ActivateInvisibilityWatch()
	DynamicDetour dtActivateInvisibilityWatchPre = DynamicDetour.FromConf(hGameData, "CTFWeaponInvis::ActivateInvisibilityWatch()");

	if(!dtActivateInvisibilityWatchPre)
		SetFailState("Failed to setup detour for CTFWeaponInvis::ActivateInvisibilityWatch()");

	// CTFWeaponInvis::CleanupInvisibilityWatch()
	DynamicDetour dtCleanupInvisibilityWatchPre = DynamicDetour.FromConf(hGameData, "CTFWeaponInvis::CleanupInvisibilityWatch()");

	if(!dtCleanupInvisibilityWatchPre)
		SetFailState("Failed to setup detour for CTFWeaponInvis::CleanupInvisibilityWatch()");

	// CTFPlayerShared::UpdateCloakMeter()
	DynamicDetour dtUpdateCloakMeterPre = DynamicDetour.FromConf(hGameData, "CTFPlayerShared::UpdateCloakMeter()");

	if(!dtUpdateCloakMeterPre)
		SetFailState("Failed to setup detour for CTFPlayerShared::UpdateCloakMeter()");

	g_offset_CTFPlayerShared_pOuter = view_as<Address>(hGameData.GetOffset("CTFPlayerShared::m_pOuter"));

	dtActivateInvisibilityWatchPre.Enable(Hook_Pre, OnActivateInvisibilityWatchPre);
	dtCleanupInvisibilityWatchPre.Enable(Hook_Pre,  OnCleanupInvisibilityWatchPre);
	dtUpdateCloakMeterPre.Enable(Hook_Pre,          OnUpdateCloakMeterPre);

	delete hGameData;

	return;
}

public void OnClientDisconnect(int iClient)
{
	for(int iNumHookType = 0; iNumHookType < MAX_HOOKS; iNumHookType++)
	{
		g_PrivateForwardStorageList[iClient].RemoveAllFunctionsFromForward(view_as<TF2CloakAPI_HookType>(iNumHookType));
	}

	return;
}

// ||──────────────────────────────────────────────────────────────────────────||
// ||                                EVENTS                                    ||
// ||──────────────────────────────────────────────────────────────────────────||

public void Event_PlayerDeath(Event hEvent, const char[] sEventName, bool bDontBroadcast) 
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));

	if(!iClient)
		return;

	if(!g_PrivateForwardStorageList[iClient].m_hForward[OnCleanupInvisibilityWatch])
		return;

	if(TF2_GetPlayerClass(iClient) != TFClass_Spy)
		return;

	int iCloak = GetPlayerWeaponSlot(iClient, 4);

	if(iCloak <= 0 || !IsValidEntity(iCloak))
		return;

	// The compiler keeps throwing a warning if you do view_as<int>(...) it inside Call_StartForward.
	int iHookType = view_as<int>(OnCleanupInvisibilityWatch);

	Action action;

	Call_StartForward(g_PrivateForwardStorageList[iClient].m_hForward[iHookType]);
	Call_PushCell(iClient);
	Call_PushCell(iCloak);
	Call_PushCell(true);
	Call_Finish(action);

	return;
}

//--------------------------------------------------------------------
// Purpose: This function gets called when a watch gets activated.
//          We can skip the original function to manage our own
//          effect.
//--------------------------------------------------------------------

// CTFWeaponInvis::ActivateInvisibilityWatch()
public MRESReturn OnActivateInvisibilityWatchPre(int iCloak, DHookReturn hReturn)
{
	int iClient = GetEntPropEnt(iCloak, Prop_Send, "m_hOwnerEntity");

	if(iClient <= 0)
		return MRES_Ignored;

	if(!g_PrivateForwardStorageList[iClient].m_hForward[OnActivateInvisibilityWatch])
		return MRES_Ignored;

	float flClockMeter = GetEntPropFloat(iClient, Prop_Send, "m_flCloakMeter");

	bool bReturnValueTemp;

	// The compiler keeps throwing a warning if you do view_as<int>(...) it inside Call_StartForward.
	int iHookType = view_as<int>(OnActivateInvisibilityWatch);

	Action action;

	Call_StartForward(g_PrivateForwardStorageList[iClient].m_hForward[iHookType]);
	Call_PushCell(iClient);
	Call_PushCell(iCloak);
	Call_PushFloat(flClockMeter);
	Call_PushCell(bReturnValueTemp);
	Call_Finish(action);

	switch(action)
	{
		case Plugin_Continue:
		{
			return MRES_Ignored;
		}
		case Plugin_Changed:
		{
			hReturn.Value = bReturnValueTemp;

			return MRES_ChangedOverride;
		}
		case Plugin_Handled:
		{
			//SetEntPropFloat(iClient, Prop_Send, "m_flStealthNextChangeTime", GetGameTime() + (bReturnValueTemp ? 0.5 : 0.1));

			hReturn.Value = bReturnValueTemp;

			// Since we're skipping the original function, we're manually calling CTFWeaponInvis::SetCloakRates()
			// to set the recharge & drain rate of the watch.
			SDKCall(g_SDKCallSetCloakRates, iCloak);

			return MRES_Supercede;
		}
		case Plugin_Stop:
		{
			hReturn.Value = bReturnValueTemp;

			return MRES_Supercede;
		}
	}

	return MRES_Ignored;
}

//--------------------------------------------------------------------
// Purpose: This function gets called on tick to manage the player's 
//          cloak meter ( both drain & regen ). 
//          We can skip it if we want to manage it ourselves.
//--------------------------------------------------------------------

// CTFPlayerShared::UpdateCloakMeter()
public MRESReturn OnUpdateCloakMeterPre(Address pShared) 
{
	int iClient = GetClientFromPlayerShared(pShared);

	if(iClient <= 0)
		return MRES_Ignored;

	if(!g_PrivateForwardStorageList[iClient].m_hForward[OnUpdateCloakMeter])
		return MRES_Ignored;

	float flCloakMeter = GetEntPropFloat(iClient, Prop_Send, "m_flCloakMeter");

	// The compiler keeps throwing a warning if you do view_as<int>(...) it inside Call_StartForward.
	int iHookType = view_as<int>(OnUpdateCloakMeter);

	Action action;

	Call_StartForward(g_PrivateForwardStorageList[iClient].m_hForward[iHookType]);
	Call_PushCell(iClient);
	Call_PushFloat(flCloakMeter);
	Call_Finish(action);

	switch(action)
	{
		case Plugin_Handled, Plugin_Stop:
		{
			return MRES_Supercede;
		}
	}

	return MRES_Ignored;
}

//--------------------------------------------------------------------
// Purpose: This function gets called when the player has changed 
//          loadouts or has done something else that causes us 
//          to clean up any side effects of our watch.
//--------------------------------------------------------------------

// CTFWeaponInvis::CleanupInvisibilityWatch()
public MRESReturn OnCleanupInvisibilityWatchPre(int iCloak)
{
	int iClient = GetEntPropEnt(iCloak, Prop_Send, "m_hOwnerEntity");

	if(iClient <= 0)
		return MRES_Ignored;

	if(!g_PrivateForwardStorageList[iClient].m_hForward[OnCleanupInvisibilityWatch])
		return MRES_Ignored;

	// The compiler keeps throwing a warning if you do view_as<int>(...) it inside Call_StartForward.
	int iHookType = view_as<int>(OnCleanupInvisibilityWatch);

	Action action;

	Call_StartForward(g_PrivateForwardStorageList[iClient].m_hForward[iHookType]);
	Call_PushCell(iClient);
	Call_PushCell(iCloak);
	Call_PushCell(false);
	Call_Finish(action);

	switch(action)
	{
		case Plugin_Handled, Plugin_Stop:
		{
			return MRES_Supercede;
		}
	}

	return MRES_Ignored;
}

// ||──────────────────────────────────────────────────────────────────────────||
// ||                               NATIVES                                    ||
// ||──────────────────────────────────────────────────────────────────────────||

public APLRes AskPluginLoad2(Handle hMySelf, bool blate, char[] sError, int iErr_max) 
{
	RegPluginLibrary("tf2_cloakapi");

	// Natives
	CreateNative("TF2CloakAPI_Hook",   Native_TF2CloakAPI_Hook);
	CreateNative("TF2CloakAPI_Unhook", Native_TF2CloakAPI_Unhook);

	return APLRes_Success;
}

public int Native_TF2CloakAPI_Hook(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	TF2CloakAPI_HookType hookType = view_as<TF2CloakAPI_HookType>(GetNativeCell(2));

	if(!g_PrivateForwardStorageList[iClient].m_hForward[hookType])
	{
		if(!g_PrivateForwardStorageList[iClient].InitializeForward(hookType))
		{
			ThrowNativeError(0, "[TF2CloakAPI] %s", "Invalid Hook Type. Make sure you're utilizing the types stated in the include file");

			return 0;
		}
	}

	g_PrivateForwardStorageList[iClient].AddFunctionToList(hPlugin, GetNativeFunction(3), hookType);

	return 0;
}

public int Native_TF2CloakAPI_Unhook(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	TF2CloakAPI_HookType hookType = view_as<TF2CloakAPI_HookType>(GetNativeCell(2));

	switch(hookType)
	{
		case OnActivateInvisibilityWatch, OnCleanupInvisibilityWatch, OnUpdateCloakMeter:
		{
			// Don't judge me :p
		}
		default:
		{
			ThrowNativeError(0, "[TF2CloakAPI] %s", "Invalid Hook Type. Make sure you're utilizing the types stated in the include file");

			return 0;
		}
	}

	g_PrivateForwardStorageList[iClient].RemoveFunctionFromList(hPlugin, GetNativeFunction(3), hookType);

	return 0;
}

// ||──────────────────────────────────────────────────────────────────────────||
// ||                                   STOCKS                                 ||
// ||──────────────────────────────────────────────────────────────────────────||

static stock bool IsValidClient(int iClient)
{
    if(iClient <= 0 || iClient > MaxClients)
        return false;

    if(!IsClientInGame(iClient))
        return false;
    
    return true;
}

static stock int GetClientFromPlayerShared(Address pPlayerShared) 
{
	Address pOuter = DereferencePointer(pPlayerShared + g_offset_CTFPlayerShared_pOuter);

	return GetEntityFromAddress(pOuter);
}

static stock int GetEntityFromAddress(Address pEntity) 
{
	return SDKCall(g_SDKCallGetBaseEntity, pEntity);
}