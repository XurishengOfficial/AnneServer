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

ConVar g_hCvarUnlimitedAmmoEnable = null;

bool g_bUnlimitedAmmoEnable = false;

// static char g_OriginHostName[128];
// static char g_HostNameBuffer[128];
// static ConVar g_hHostName;

public Plugin myinfo =
{
	name = "L4D2 Unlimitd Ammo",
	author = "Azuki daisuki~",
	description = "When survivor reload, will set remaining ammo 999",
	version = "1.0",
	url = "https://steamcommunity.com/profiles/76561198175657167/"
};

void GetCvars()
{
	g_bUnlimitedAmmoEnable = g_hCvarUnlimitedAmmoEnable.BoolValue;
}

public void ConVarChanged(ConVar hConvar, const char[] sOldValue, const char[] sNewValue)
{
	GetCvars();
	
	if (g_bUnlimitedAmmoEnable)
	{
		PrintToChatAll("[SM] 已开启无限备弹");
	}
	else
	{
		PrintToChatAll("[SM] 已关闭无限备弹");
	}
}

public void OnPluginStart()
{
	g_hCvarUnlimitedAmmoEnable = CreateConVar("l4d2_unlimited_ammo_enable", "1", "是否开启无限备弹", _, true, 0.0, true, 1.0);
	GetCvars();
	g_hCvarUnlimitedAmmoEnable.AddChangeHook(ConVarChanged);
	HookEvent("weapon_reload", Event_WeaponReload, EventHookMode_Post);
}

public void Event_WeaponReload(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bUnlimitedAmmoEnable) return;
	int survivor = GetClientOfUserId(event.GetInt("userid"));
	
	if (IsClientAndInGame(survivor))
	{
		int weapon = GetPlayerWeaponSlot(survivor, 0);
		if (IsValidEntity(weapon))
		{
			int iAmmoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
			GivePlayerAmmo(survivor, 999, iAmmoType, false);
		}
	}
}

bool IsClientAndInGame(int iClient)
{
	return (iClient > 0 && IsClientInGame(iClient));
}
