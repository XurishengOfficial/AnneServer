/*
	SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2008 ITB CompuPhase.
	Source is Copyright (C) Valve Corporation.
	All trademarks are property of their respective owners.

	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.

	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program. If not, see <http://www.gnu.org/licenses/>.
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <left4dhooks>
#include <l4d2util_constants>
#include <dhooks>

#define TEAM_INFECTED 		3

ConVar g_hCvarAutoReViveEnable = null;
ConVar g_hCvarAutoReViveType = null;
bool g_bCvarAutoReViveEnable = false;
bool g_bCvarAutoReViveType = false;

// static char g_OriginHostName[128];
// static char g_HostNameBuffer[128];
// static ConVar g_hHostName;

public Plugin myinfo =
{
	name = "Auto Revive",
	author = "Azuki daisuki~",
	description = "Auto revive when survivor Trapped.",
	version = "1.0",
	url = "https://steamcommunity.com/profiles/76561198175657167/"
};

void GetCvars()
{
	g_bCvarAutoReViveEnable = g_hCvarAutoReViveEnable.BoolValue;
	g_bCvarAutoReViveType = g_hCvarAutoReViveType.BoolValue;
}

public void ConVarChanged_Enable(ConVar hConvar, const char[] sOldValue, const char[] sNewValue)
{
	GetCvars();
	
	if (g_bCvarAutoReViveEnable)
	{
		PrintToChatAll("[SM] 已开启自动解控");
	}
	else
	{
		PrintToChatAll("[SM] 已关闭自动解控");
	}
}

public void ConVarChanged_Type(ConVar hConvar, const char[] sOldValue, const char[] sNewValue)
{
	GetCvars();

	if (g_bCvarAutoReViveType)
	{
		PrintToChatAll("[SM] 处死特感模式为: ALL");
	}
	else
	{
		PrintToChatAll("[SM] 处死特感模式为: Single");
	}
}

public void OnPluginStart()
{
	// g_hCvarDmgThreshold = CreateConVar("sm_auto_revive_dmgthreshold", "1", "Amount of damage done (at once) before SI suicides.", _, true, 1.0);
	g_hCvarAutoReViveEnable = CreateConVar("auto_revive_enable", "0", "是否开启自动解控", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	// 0: 处死单只特感; 1: 处死所有特感
	g_hCvarAutoReViveType = CreateConVar("auto_revive_type", "0", "解控时仅处死控制玩家的特感", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	GetCvars();

	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
	HookEvent("jockey_ride", Event_JockeyRide, EventHookMode_Post);
	// HookEvent("hunter_punched", Event_HunterPunch, EventHookMode_Post);
	// HookEvent("lunge_shove", Event_LungeShove, EventHookMode_Post);
	HookEvent("lunge_pounce", Event_LungePounce, EventHookMode_Post);
	HookEvent("charger_charge_end", Event_ChargerChargeEnd, EventHookMode_Post);
	HookEvent("charger_carry_start", Event_ChargeCarryStart, EventHookMode_Post);
	HookEvent("tongue_grab", Event_TongueGrab, EventHookMode_Post);
	// HookEvent("choke_start", Event_ChokeStart, EventHookMode_Post);
	// HookEvent("drag_begin", Event_DragBegin, EventHookMode_Post);
	// HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);	

	g_hCvarAutoReViveEnable.AddChangeHook(ConVarChanged_Enable);
	g_hCvarAutoReViveType.AddChangeHook(ConVarChanged_Type);
	AutoExecConfig(true, "l4d2_auto_revive");
    RegConsoleCmd("sm_sp", ShowPosition, "Prints the current origin.");
	
}

public Action ShowPosition(int client, int args)
{
    float vec[3];
	GetClientAbsOrigin(client, vec);
	PrintToChat(client, "%.2f %.2f %.2f", vec[0], vec[1], vec[2]);
    return Plugin_Handled;
}

public Action KillInfected(Handle timer, int index)
{
	// 1: 处死所有 0: 处死单个
	if (g_bCvarAutoReViveType)
	{
		for (int i = 1; i < MaxClients + 1; i ++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED)
			{
				ForcePlayerSuicide(i);
			}
		}
	}
	else
	{
		if(IsClientInGame(index) && GetClientTeam(index) == TEAM_INFECTED)
		{
			ForcePlayerSuicide(index);
		}
	}
	return Plugin_Continue;
}

// public Action CheckTrappedForHunter(Handle timer, int survior)
// {
// 	// 1: 处死所有 0: 处死单个
// 	int hunter = -1;
// 	hunter = GetEntPropEnt(survior, Prop_Send, "m_pounceAttacker");
// 	if (IsClientAndInGame(hunter))
// 	{
// 		PrintToChatAll("[AutoRevive] Detect trapped by hunter...killing");
// 		ForcePlayerSuicide(hunter);
// 	}
// 	return Plugin_Continue;
// }

public Action KillOneInfected(Handle timer, int index)
{
	if(IsClientInGame(index) && GetClientTeam(index) == TEAM_INFECTED)
	{
		ForcePlayerSuicide(index);
	}
}

public void Event_JockeyRide(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bCvarAutoReViveEnable) return;
	int jockey = GetClientOfUserId(event.GetInt("userid"));
	int survivor = GetClientOfUserId(event.GetInt("victim"));
	
	if (IsClientAndInGame(jockey) && IsClientAndInGame(survivor))
	{
		CreateTimer(0.5, KillInfected, jockey);
		// SetEntityHealth(survivor, 100);
	}
}

// public void Event_LungeShove(Event event, const char[] name, bool dontBroadcast)
// {
// 	if (!g_bCvarAutoReViveEnable) return;
// 	int hunter = GetClientOfUserId(event.GetInt("userid"));
// 	int survivor = GetClientOfUserId(event.GetInt("victim"));
	
// 	if (IsClientAndInGame(hunter) && IsClientAndInGame(survivor))
// 	{
// 		CreateTimer(0.5, KillInfected, hunter);
// 		// CreateTimer(2.0, CheckTrappedForHunter, survivor);
// 		// SetEntityHealth(survivor, 100);
// 	}
// }

public void Event_LungePounce(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bCvarAutoReViveEnable) return;
	int hunter = GetClientOfUserId(event.GetInt("userid"));
	int survivor = GetClientOfUserId(event.GetInt("victim"));
	
	if (IsClientAndInGame(hunter) && IsClientAndInGame(survivor))
	{
		// PrintToChatAll("[AutoRevive] Detect Pounced by hunter...killing");
		CreateTimer(0.5, KillInfected, hunter);
	}
}

public void Event_ChargerChargeEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bCvarAutoReViveEnable) return;
	int charger = GetClientOfUserId(event.GetInt("userid"));
	
	if (IsClientAndInGame(charger))
	{
		ForcePlayerSuicide(charger);
	}
}

public void Event_ChargeCarryStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bCvarAutoReViveEnable) return;
	int charger = GetClientOfUserId(event.GetInt("userid"));
	int survivor = GetClientOfUserId(event.GetInt("victim"));
	
	if (IsClientAndInGame(charger) && IsClientAndInGame(survivor))
	{
		CreateTimer(0.5, KillInfected, charger);
		// SetEntityHealth(survivor, 100);
	}
}

public void Event_TongueGrab(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bCvarAutoReViveEnable) return;
	int smoker = GetClientOfUserId(event.GetInt("userid"));
	int survivor = GetClientOfUserId(event.GetInt("victim"));
	
	if (IsClientAndInGame(smoker) && IsClientAndInGame(survivor))
	{
		// SetEntityHealth(survivor, 100);
		CreateTimer(2.0, KillOneInfected, smoker);
	}
}

public void Event_PlayerHurt(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_bCvarAutoReViveEnable){
		return;
	}

	int iVictim = GetClientOfUserId(hEvent.GetInt("userid"));
	if (!IsClientAndInGame(iVictim) || GetClientTeam(iVictim) != L4D2Team_Survivor) {
		return;
	}

	SetEntityHealth(iVictim, 200);
}

bool IsClientAndInGame(int iClient)
{
	return (iClient > 0 && IsClientInGame(iClient));
}
