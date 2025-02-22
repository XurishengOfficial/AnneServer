/*
*	Gift Rewards
*	Copyright (C) 2022 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION 		"1.8"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Gift Rewards
*	Author	:	SilverShot
*	Descrp	:	Gives random rewards when picking up gifts.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=320067
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.8 (09-Dec-2022)
	- Fixed refilling ammo giving to wrong client due to Valve code inside "givecurrentammo" command. Thanks to "GL_INS" for reporting.
	- Now optionally uses "Left 4 DHooks" to refill the weapon clip.

1.7 (08-Mar-2022)
	- Fixed cvar "l4d2_gift_rewards_count" not resetting the death count. Thanks to "mikaelangelis" for reporting.

1.6 (04-Jul-2021)
	- Added cvar "l4d2_gift_rewards_count" to control how many SI must die before allowing the chance of dropping a Gift.

1.5 (03-Jul-2021)
	- Added cvar "l4d2_gift_rewards_drop" to control the chance of dropping gifts when Special Infected die.
	- By default the plugin uses the games chance from "z_holiday_gift_drop_chance" cvar.
	- No longer patches the game to drop gifts in all game modes. (Code left for demonstration purposes).

1.4 (16-Jun-2021)
	- L4D2: Compatibility update for "2.2.1.3" update. Thanks to "N.U.S.C." for reporting.
	- GameData .txt file and plugin updated.

1.3a (24-Sep-2020)
	- Compatibility update for L4D2's "The Last Stand" update.
	- GameData .txt file updated.

1.3 (10-May-2020)
	- Added better error log message when gamedata file is missing.
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.
	- Various changes to tidy up code.

1.2 (10-Apr-2020)
	- Patched out Holiday requirement and Versus mode restriction.
	- GameData and plugin updated.

1.1 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.

1.0 (02-Dec-2019)
	- Initial release.

========================================================================================
	Thanks:

	This plugin was made using source code from the following plugins.
	If I have used your code and not credited you, please let me know.

*	"Zuko & McFlurry" for "[L4D2] Weapon/Zombie Spawner" - Modified SetTeleportEndPoint function.
	https://forums.alliedmods.net/showthread.php?t=109659

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define GAMEDATA			"l4d2_gift_rewards"
// #define SOUND_DROP			"ui/gift_drop.wav" // Not required, here for reference.

#define L4D2_WEPUPGFLAG_LASER           (1 << 2) // laser sight


ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarChance1, g_hCvarChance2, g_hCvarChance3, g_hCvarCount, g_hGameDrop, g_hCvarDrop, g_hCvarSize, g_hCvarSpeed;// g_hCvarSizeStart
int g_iCvarChance1, g_iCvarChance2, g_iCvarChance3, g_iTotalChance, g_iCvarCount, g_iDeathCount;
bool g_bCvarAllow, g_bMapStarted;
bool g_bLeft4DHooks, g_bWeaponHandling;
float g_fGameDrop, g_fCvarDrop, g_fCvarSize, g_fCvarSpeed, g_fRewarded[MAXPLAYERS + 1];// g_fCvarSizeStart
Handle g_hSDK_CreateGift;

/* Patch Method - replaced with manually spawning
ArrayList g_ByteSaved;
Address g_Address;
*/



// From Left4DHooks
enum L4D2IntWeaponAttributes
{
	L4D2IWA_Damage,
	L4D2IWA_Bullets,
	L4D2IWA_ClipSize,
	L4D2IWA_Bucket,
	L4D2IWA_Tier, // L4D2 only
	MAX_SIZE_L4D2IntWeaponAttributes
};

native int L4D2_GetIntWeaponAttribute(const char[] weaponName, L4D2IntWeaponAttributes attr);



// From WeaponHandling
enum L4D2WeaponType 
{
	L4D2WeaponType_Unknown = 0,
	L4D2WeaponType_Pistol,
	L4D2WeaponType_Magnum,
	L4D2WeaponType_Rifle,
	L4D2WeaponType_RifleAk47,
	L4D2WeaponType_RifleDesert,
	L4D2WeaponType_RifleM60,
	L4D2WeaponType_RifleSg552,
	L4D2WeaponType_HuntingRifle,
	L4D2WeaponType_SniperAwp,
	L4D2WeaponType_SniperMilitary,
	L4D2WeaponType_SniperScout,
	L4D2WeaponType_SMG,
	L4D2WeaponType_SMGSilenced,
	L4D2WeaponType_SMGMp5,
	L4D2WeaponType_Autoshotgun,
	L4D2WeaponType_AutoshotgunSpas,
	L4D2WeaponType_Pumpshotgun,
	L4D2WeaponType_PumpshotgunChrome,
	L4D2WeaponType_Molotov,
	L4D2WeaponType_Pipebomb,
	L4D2WeaponType_FirstAid,
	L4D2WeaponType_Pills,
	L4D2WeaponType_Gascan,
	L4D2WeaponType_Oxygentank,
	L4D2WeaponType_Propanetank,
	L4D2WeaponType_Vomitjar,
	L4D2WeaponType_Adrenaline,
	L4D2WeaponType_Chainsaw,
	L4D2WeaponType_Defibrilator,
	L4D2WeaponType_GrenadeLauncher,
	L4D2WeaponType_Melee,
	L4D2WeaponType_UpgradeFire,
	L4D2WeaponType_UpgradeExplosive,
	L4D2WeaponType_BoomerClaw,
	L4D2WeaponType_ChargerClaw,
	L4D2WeaponType_HunterClaw,
	L4D2WeaponType_JockeyClaw,
	L4D2WeaponType_SmokerClaw,
	L4D2WeaponType_SpitterClaw,
	L4D2WeaponType_TankClaw
}



// ====================================================================================================
//					PLUGIN
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2] Gift Rewards",
	author = "SilverShot",
	description = "Gives random rewards when picking up gifts.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=320067"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	MarkNativeAsOptional("L4D2_GetIntWeaponAttribute");

	return APLRes_Success;
}

public void OnLibraryAdded(const char[] name)
{
	if( strcmp(name, "WeaponHandling") == 0 )
		g_bWeaponHandling = true;
	if( strcmp(name, "left4dhooks") == 0 )
		g_bLeft4DHooks = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if( strcmp(name, "WeaponHandling") == 0 )
		g_bWeaponHandling = false;
	if( strcmp(name, "left4dhooks") == 0 )
		g_bLeft4DHooks = false;
}

public void OnPluginStart()
{
	// ====================================================================================================
	// GAMEDATA
	// ====================================================================================================
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	/* Patch Method - replaced with manually spawning
	int iOffset = GameConfGetOffset(hGameData, "Patch_Offset");
	if( iOffset == -1 ) SetFailState("Failed to load \"Patch_Offset\" offset.");

	int iByteMatch = GameConfGetOffset(hGameData, "Patch_Byte");
	if( iByteMatch == -1 ) SetFailState("Failed to load \"Patch_Byte\" byte.");

	int iByteCount = GameConfGetOffset(hGameData, "Patch_Count");
	if( iByteCount == -1 ) SetFailState("Failed to load \"Patch_Count\" count.");

	g_Address = GameConfGetAddress(hGameData, "CTerrorPlayer::Event_Killed");
	if( !g_Address ) SetFailState("Failed to load \"CTerrorPlayer::Event_Killed\" address.");

	g_Address += view_as<Address>(iOffset);
	g_ByteSaved = new ArrayList();

	for( int i = 0; i < iByteCount; i++ )
	{
		g_ByteSaved.Push(LoadFromAddress(g_Address + view_as<Address>(i), NumberType_Int8));
	}

	if( g_ByteSaved.Get(0) != iByteMatch ) SetFailState("Failed to load, byte mis-match @ %d (0x%02X != 0x%02X)", iOffset, g_ByteSaved.Get(0), iByteMatch);
	*/



	// ====================================================================================================
	// SDKCALLS
	// ====================================================================================================
	StartPrepSDKCall(SDKCall_Static);
	if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CHolidayGift::Create") == false )
		SetFailState("Could not load the \"CHolidayGift::Create\" gamedata signature.");

	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_CreateGift = EndPrepSDKCall();
	if( g_hSDK_CreateGift == null )
		SetFailState("Could not prep the \"CHolidayGift::Create\" function.");

	delete hGameData;



	// ====================================================================================================
	// CVARS
	// ====================================================================================================
	g_hCvarAllow = CreateConVar(		"l4d2_gift_rewards_allow",			"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarChance1 = CreateConVar(		"l4d2_gift_rewards_chance_guns",	"100",			"Chance to give some gun.", CVAR_FLAGS );
	g_hCvarChance2 = CreateConVar(		"l4d2_gift_rewards_chance_heal",	"0",			"Chance to give medical items.", CVAR_FLAGS );
	g_hCvarChance3 = CreateConVar(		"l4d2_gift_rewards_chance_items",	"100",			"Chance to give items.", CVAR_FLAGS );
	g_hCvarCount = CreateConVar(		"l4d2_gift_rewards_count",			"0",			"0=No restriction. This number of Special Infected must die before allowing the drop chance of spawning a Gift.", CVAR_FLAGS );
	g_hCvarDrop = CreateConVar(			"l4d2_gift_rewards_drop",			"0.03",			"-1.0=Use games z_holiday_gift_drop_chance cvar value. 0.0=Off. 1.0=Maximum chance. The chance to randomly drop gifts on Special Infected death.", CVAR_FLAGS, true, 0.0, true, 1.0 );
	g_hCvarSize = CreateConVar(			"l4d2_gift_rewards_size",			"0.0",			"0.0=Off. Reduces the size of gifts over this many seconds.", CVAR_FLAGS );
	// g_hCvarSizeStart = CreateConVar(	"l4d2_gift_rewards_size_start",		"2.0",			"1.0=Default. Starting size of the gift.", CVAR_FLAGS ); // Unused, glow appears wrong, here for reference if someone wants to test.
	// g_hCvarSpeed = CreateConVar(		"l4d2_gift_rewards_speed",			"0.0",			"Duration the increased speed affects a player.", CVAR_FLAGS );
	g_hCvarModes = CreateConVar(		"l4d2_gift_rewards_modes",			"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar(		"l4d2_gift_rewards_modes_off",		"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(		"l4d2_gift_rewards_modes_tog",		"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	CreateConVar(						"l4d2_gift_rewards_version",		PLUGIN_VERSION,	"Gift Rewards plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,				"l4d2_gift_rewards");

	g_hGameDrop = FindConVar("z_holiday_gift_drop_chance");
	g_hGameDrop.AddChangeHook(ConVarChanged_Cvars);

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarChance1.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarChance2.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarChance3.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarCount.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDrop.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSize.AddChangeHook(ConVarChanged_Cvars);
	// g_hCvarSizeStart.AddChangeHook(ConVarChanged_Cvars);
	// g_hCvarSpeed.AddChangeHook(ConVarChanged_Cvars);



	// ====================================================================================================
	// COMMANDS
	// ====================================================================================================
	RegAdminCmd("sm_gift",		CmdGift,		ADMFLAG_ROOT);
	RegAdminCmd("sm_gifter",	CmdReward,		ADMFLAG_ROOT);
}

/* Patch Method - replaced with manually spawning
public void OnPluginEnd()
{
	PatchAddress(false);
}
*/

public void OnMapEnd()
{
	g_bMapStarted = false;
	ResetPlugin();
}

void ResetPlugin()
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		g_fRewarded[i] = 0.0;
	}

	g_iDeathCount = 0;
}

public void OnMapStart()
{
	g_bMapStarted = true;
	// PrecacheSound(SOUND_DROP);
}



// ====================================================================================================
//					PATCH
// ====================================================================================================
/* Patch Method - replaced with manually spawning
void PatchAddress(int patch)
{
	static bool patched;

	if( !patched && patch )
	{
		patched = true;

		int len = g_ByteSaved.Length;

		for( int i = 0; i < len; i++ )
		{
			// Both not working on Linux
			if( len == 1 ) // Linux
				StoreToAddress(g_Address + view_as<Address>(i), 0x88, NumberType_Int8); // 0x85 JNZ (jump short if non zero) to 0x88 JS (jump near if sign) - always jump - NEW
				// StoreToAddress(g_Address + view_as<Address>(i), 0x78, NumberType_Int8); // 0x85 JNZ (jump short if non zero) to 0x78 JS (jump short if sign) - always jump - OLD
			else
				StoreToAddress(g_Address + view_as<Address>(i), 0x90, NumberType_Int8);
		}
	}
	else if( patched && !patch )
	{
		patched = false;

		int len = g_ByteSaved.Length;

		for( int i = 0; i < len; i++ )
		{
			StoreToAddress(g_Address + view_as<Address>(i), g_ByteSaved.Get(i), NumberType_Int8);
		}
	}
}
*/



// ====================================================================================================
//					COMMANDS
// ====================================================================================================
Action CmdReward(int client, int args)
{
	if( !g_bCvarAllow )
	{
		ReplyToCommand(client, "[Gift] Gifts plugin has been turned off.");
		return Plugin_Handled;
	}

	GiveAward(client); return Plugin_Handled;
}

Action CmdGift(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Gift] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}

	if( g_hSDK_CreateGift == null )
	{
		ReplyToCommand(client, "[Gift] Missing gamedata. Cannot use this command.");
		return Plugin_Handled;
	}

	if( !g_bCvarAllow )
	{
		ReplyToCommand(client, "[Gift] Gifts plugin has been turned off.");
		return Plugin_Handled;
	}

	float vPos[3];
	if( !SetTeleportEndPoint(client, vPos, NULL_VECTOR) )
	{
		PrintToChat(client, "[Gift] Cannot place gift, please try again.");
		return Plugin_Handled;
	}

	SDKCall(g_hSDK_CreateGift, vPos, view_as<float>({0.0, 0.0, 0.0}), view_as<float>({0.0, 0.0, 0.0}), view_as<float>({0.0, 0.0, 0.0}), 0);
	return Plugin_Handled;
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnConfigsExecuted()
{
	IsAllowed();
}

void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	// g_fCvarSizeStart = g_hCvarSizeStart.FloatValue;
	g_fGameDrop = g_hGameDrop.FloatValue;
	g_iCvarCount = g_hCvarCount.IntValue;
	g_fCvarDrop = g_hCvarDrop.FloatValue;
	g_fCvarSize = g_hCvarSize.FloatValue;
	// g_fCvarSpeed = g_hCvarSpeed.FloatValue;

	g_iTotalChance = 0;
	g_iCvarChance1 = GetChance(g_hCvarChance1);
	g_iCvarChance2 = GetChance(g_hCvarChance2);
	g_iCvarChance3 = GetChance(g_hCvarChance3);

	if( g_fCvarDrop == -1.0 ) g_fCvarDrop = g_fGameDrop;
}

int GetChance(ConVar cvar)
{
	int rtn = cvar.IntValue;
	if( rtn )
	{
		g_iTotalChance += rtn;
		rtn = g_iTotalChance;
	}
	return rtn;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		// PatchAddress(true); // Patch Method - replaced with manually spawning

		HookEvent("christmas_gift_grab",	Event_Gift);
		HookEvent("player_death",			Event_Death);
		HookEvent("round_end",				Event_Round, EventHookMode_PostNoCopy);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		// PatchAddress(false); // Patch Method - replaced with manually spawning

		UnhookEvent("christmas_gift_grab",	Event_Gift);
		UnhookEvent("player_death",			Event_Death);
		UnhookEvent("round_end",			Event_Round, EventHookMode_PostNoCopy);
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
{
	if( g_hCvarMPGameMode == null )
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;
	if( iCvarModesTog != 0 )
	{
		if( g_bMapStarted == false )
			return false;

		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		if( IsValidEntity(entity) )
		{
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
			ActivateEntity(entity);
			AcceptEntityInput(entity, "PostSpawnActivate");
			if( IsValidEntity(entity) ) // Because sometimes "PostSpawnActivate" seems to kill the ent.
				RemoveEdict(entity); // Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
		}

		if( g_iCurrentMode == 0 )
			return false;

		if( !(iCvarModesTog & g_iCurrentMode) )
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 4;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iCurrentMode = 8;
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
public void OnEntityCreated(int entity, const char[] classname)
{
	// if( g_bCvarAllow && (g_fCvarSize || g_fCvarSizeStart) && strcmp(classname, "holiday_gift") == 0 )
	if( g_bCvarAllow && g_fCvarSize && strcmp(classname, "holiday_gift") == 0 )
	{
		// if( g_fCvarSizeStart )
			// SetEntPropFloat(entity, Prop_Send, "m_flModelScale", g_fCvarSizeStart);

		// if( g_fCvarSize )
		CreateTimer(0.1, TimerSize, EntIndexToEntRef(entity), TIMER_REPEAT);
	}
}

Action TimerSize(Handle timer, any entity)
{
	if( EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
	{
		float scale = GetEntPropFloat(entity, Prop_Send, "m_flModelScale") - (1.0 / g_fCvarSize / 10);
		if( scale > 0.1 )
			SetEntPropFloat(entity, Prop_Send, "m_flModelScale", scale);
		else
			return Plugin_Stop;

		return Plugin_Continue;
	}
	return Plugin_Stop;
}

void Event_Round(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin();
}

void Event_Death(Event event, const char[] name, bool dontBroadcast)
{
	if( g_fCvarDrop )
	{
		int client = GetClientOfUserId(event.GetInt("userid"));

		if( client && GetClientTeam(client) == 3 )
		{
			g_iDeathCount++;

			if( g_iCvarCount == 0 || g_iDeathCount >= g_iCvarCount )
			{
				if( GetRandomFloat(0.0, 1.0) <= g_fCvarDrop )
				{
					g_iDeathCount = 0;

					float vPos[3];
					GetClientAbsOrigin(client, vPos);

					SDKCall(g_hSDK_CreateGift, vPos, view_as<float>({0.0, 0.0, 0.0}), view_as<float>({0.0, 0.0, 0.0}), view_as<float>({0.0, 0.0, 0.0}), 0);
				}
			}
		}
	}
}

void Event_Gift(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client) && GetClientTeam(client) == 2)
	{
		GiveAward(client);
	}
}

void GiveAward(int client)
{
	int random = GetRandomInt(1, g_iTotalChance);
	// PrintToServer("Reward random %d/%d (%d %d %d)", random, g_iTotalChance, g_iCvarChance1, g_iCvarChance2, g_iCvarChance3);
	// PrintToChatAll("[GiveAward] random: %d, c1: %d, c2: %d, c3: %d", random, g_iCvarChance1, g_iCvarChance2, g_iCvarChance3);

	if(			g_iCvarChance1 && random <= g_iCvarChance1 )		random = 1;
	else if(	g_iCvarChance2 && random <= g_iCvarChance2 )		random = 2;
	else if(	g_iCvarChance3 && random <= g_iCvarChance3 )		random = 3;
	else random = 0;
	// PrintToChatAll("Reward chosen %d", random);

	if( random )
	{
		switch( random )
		{
			case 1:		GiveGuns(client);
			case 2:		GiveMedicalItems(client);
			case 3:		GiveItems(client);
		}

		// PrintToChatAll("\x04[\x05Gift\x04] \x01Rewarded \x05%s \x01to \x04%N", random == 1 ? "Ammo" : random == 2 ? "Health" : "Speed", client);
	}
}

void GiveGuns(int client)
{
	char playerName[64];
	GetClientName(client, playerName, sizeof(playerName));

	int r = GetRandomInt(0, 7);
	switch( r )
	{
		case 0, 1, 2:		
		{
			GivePlayerItem(client, "weapon_rifle_ak47");
			PrintToChatAll("\x04[\x05Gift\x04] \x05%s \x01获得 \x04AK47", playerName);
		}
		case 6:
		{
			GivePlayerItem(client, "weapon_sniper_awp");
			PrintToChatAll("\x04[\x05Gift\x04] \x05%s \x01获得 \x04AWP", playerName);
		}		
		case 7:
		{
			GivePlayerItem(client, "weapon_sniper_scout");
			PrintToChatAll("\x04[\x05Gift\x04] \x05%s \x01获得 \x04SCOUT", playerName);
		}		
		case 3, 4, 5:
		{
			GivePlayerItem(client, "weapon_sniper_military");
			PrintToChatAll("\x04[\x05Gift\x04] \x05%s \x01获得 \x04军用狙击枪", playerName);
		}			
	}
}

void GiveMedicalItems(int client)
{
	// char playerName[64];
	// GetClientName(client, playerName, sizeof(playerName));
}

void GiveItems(int client)
{
	char playerName[64];
	GetClientName(client, playerName, sizeof(playerName));

	int r = GetRandomInt(0, 3);
	// PrintToChatAll("[GiveItems] random: %d", r);
	switch( r )
	{
		case 0:		
		{
			GivePlayerItem(client, "weapon_pipe_bomb");
			PrintToChatAll("\x04[\x05Gift\x04] \x05%s \x01获得 \x04土质炸弹", playerName);
		}
		case 1:
		{
			GivePlayerItem(client, "weapon_vomitjar");
			PrintToChatAll("\x04[\x05Gift\x04] \x05%s \x01获得 \x04胆汁罐", playerName);
		}		
		case 2:
		{
			UpgradeLaserSight(client);
			PrintToChatAll("\x04[\x05Gift\x04] \x05%s \x01获得 \x04激光升级", playerName);
		}	
		case 3:
		{
			GivePlayerItem(client, "weapon_defibrillator");
			PrintToChatAll("\x04[\x05Gift\x04] \x05%s \x01获得 \x04电击器", playerName);
		}	
	}
}

// ====================================================================================================
//					POSITION
// ====================================================================================================
bool SetTeleportEndPoint(int client, float vPos[3], float vAng[3])
{
	GetClientEyePosition(client, vPos);
	GetClientEyeAngles(client, vAng);

	Handle trace = TR_TraceRayFilterEx(vPos, vAng, MASK_SHOT, RayType_Infinite, _TraceFilter);

	if( TR_DidHit(trace) )
	{
		float vNorm[3];
		TR_GetEndPosition(vPos, trace);
		TR_GetPlaneNormal(trace, vNorm);
		float angle = vAng[1];
		GetVectorAngles(vNorm, vAng);

		if( vNorm[2] == 1.0 )
		{
			vAng[0] = 0.0;
			vAng[1] += angle;
		}
		else
		{
			vAng[0] = 0.0;
			vAng[1] += angle - 90.0;
		}
	}
	else
	{
		delete trace;
		return false;
	}

	delete trace;
	return true;
}

bool _TraceFilter(int entity, int contentsMask)
{
	return entity > MaxClients || !entity;
}

bool IsValidClient(int iClient)
{
    if (iClient <= 0) return false;
    if (iClient > MaxClients) return false;
    if(!IsClientInGame(iClient))return false;
 	return true;
}

void UpgradeLaserSight(int client)
{
	if (!IsValidClient(client)) 
		return;
	
	int iWeapon = GetPlayerWeaponSlot(client, 0); // Get primary weapon
	if(iWeapon > 0 && IsValidEdict(iWeapon) && IsValidEntity(iWeapon))
	{
		char netclass[128];
		GetEntityNetClass(iWeapon, netclass, sizeof(netclass));
		if(FindSendPropInfo(netclass, "m_upgradeBitVec") < 1)
		{
			return; // This weapon does not support iUpgrades
		}

		int iUpgrades = GetEntProp(iWeapon, Prop_Send, "m_upgradeBitVec"); // Get iUpgrades of primary weapon
		if(iUpgrades & L4D2_WEPUPGFLAG_LASER)
		{
			return; // Primary weapon already have laser sight, return
		}
		
		SetEntProp(iWeapon, Prop_Send, "m_upgradeBitVec", iUpgrades | L4D2_WEPUPGFLAG_LASER);
	}
}