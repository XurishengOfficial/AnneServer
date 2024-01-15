#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.5.1"

// static int g_iCfgExeced = 0;
int g_iHREnable, g_iHRLimit, g_iHRValue;

ConVar g_hHREnable, g_hHRLimit, g_hHRValue;
ConVar g_hHROld = null;
char sOldValue[64];
char sChangedConVarName[64];

public Plugin myinfo =
{
	name = "加血奖励插件",
	author = "",
	description = "health return",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	
	HookEvent("player_death", Event_KillInfected);
	HookEvent("player_hurt", Event_HurtInfected);
	
	g_hHREnable	= CreateConVar("l4d2_health_return_enable", "2", "Enable health return when survivor kill or hurt infected. 0-disable 1-kill 2-hurt", FCVAR_NOTIFY|FCVAR_ARCHIVE);
	g_hHRValue	= CreateConVar("l4d2_health_return_value", "3", "Return value(enable = 1) or return ratio(enable = 2). ", FCVAR_NOTIFY);
	g_hHRLimit	= CreateConVar("l4d2_survivor_health_max", "200", "Max survivor health", FCVAR_NOTIFY);
	
	// g_hHREnable.AddChangeHook(HealthConVarChanged);
	// g_hHRValue.AddChangeHook(HealthConVarChanged);
	// g_hHRLimit.AddChangeHook(HealthConVarChanged);

	HookConVarChange(g_hHREnable, HealthConVarChanged);
	HookConVarChange(g_hHRValue, HealthConVarChanged);
	HookConVarChange(g_hHRLimit, HealthConVarChanged);
	
	AutoExecConfig(true, "l4d2_health_return");//生成指定文件名的CFG.
	// g_iCfgExeced = 0;

}

//地图开始.
public void OnMapStart()
{
	l4d2_HealthChange();
}

public void HealthConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	l4d2_HealthChange();
	// Format(sOldValue, sizeof(sOldValue), oldValue);
	// GetConVarName(convar, sChangedConVarName, sizeof(sChangedConVarName));
	// LogMessage("convar = %s, Old = %s, New = %s\n", sChangedConVarName, oldValue, newValue);
	// LogMessage("===== Set convar %s to old value %s =====", sChangedConVarName, sOldValue);
}

void l4d2_HealthChange()
{
	g_iHREnable =	GetConVarInt(g_hHREnable);
	g_iHRLimit = 	GetConVarInt(g_hHRLimit);
	g_iHRValue = 	GetConVarInt(g_hHRValue);

	if (g_iHRLimit < 100)
	{
		g_iHRLimit = 100;
	}
	
	// g_iHREnable = 1, g_iHRLimit = 200, g_iHRValue = 3
}

// public void OnConfigsExecuted()
// {
// 	ConVar hChangedConvar = FindConVar(sChangedConVarName);
// 	if (hChangedConvar)
// 	{
// 		SetConVarString(hChangedConvar, sOldValue);
// 		LogMessage("===== Set convar %s to old value %s =====", sChangedConVarName, sOldValue);

// 	}
// 	else
// 	{
// 		LogMessage("===== Unable to find convar by name: %s =====", sChangedConVarName);
// 	}
// }

bool ValidSurvivorAndInfected(int survivor, int infected)
{
	if(!(IsValidClient(survivor) && GetClientTeam(survivor) == 2 && IsValidClient(infected) && GetClientTeam(infected) == 3))
		return false;
	
	// Alive and not Incapacitated Survivor
	if (!IsPlayerAlive(survivor) || GetEntProp(survivor, Prop_Send, "m_isIncapacitated") != 0)
		return false;

	return true;
}

void SetSurvivorHealth(int survivor, int dmg)
{
	int survivorhealth = GetClientHealth(survivor);
	int tmphealth = L4D_GetPlayerTempHealth(survivor);
	int cmpHealth1 = 0;
	int cmpHealth2 = 0;

	if (tmphealth == -1)
	{
		tmphealth = 0;
	}

	if (g_iHREnable == 1)
	{
		cmpHealth1 = survivorhealth + tmphealth + g_iHRValue;
		cmpHealth2 = survivorhealth + g_iHRValue;
	}
	else if (g_iHREnable == 2)
	{
		int iHRResult = RoundToCeil(float(dmg * g_iHRValue) / 100.0);
		cmpHealth1 = survivorhealth + tmphealth + iHRResult;
		cmpHealth2 = survivorhealth + iHRResult;
	}
	else
	{
		return;
	}

	// PrintToChatAll("cmpHealth1 = %d, cmpHealth2 = %d, survivorhealth = %d, tmphealth = %d, g_iHRValue = %d",
	// 	cmpHealth1, cmpHealth2, survivorhealth, tmphealth, g_iHRValue
	// );


	if (cmpHealth1 > g_iHRLimit)
	{
		float overhealth, fakehealth;
		overhealth = float(cmpHealth1 - g_iHRLimit);
		if (tmphealth < overhealth)
		{
			fakehealth = 0.0;
		}
		else
		{
			fakehealth = float(tmphealth) - overhealth;
		}
		SetEntPropFloat(survivor, Prop_Send, "m_healthBufferTime", GetGameTime());
		SetEntPropFloat(survivor, Prop_Send, "m_healthBuffer", fakehealth);
	}
		
	if (cmpHealth2 < g_iHRLimit)
	{
		SetEntProp(survivor, Prop_Send, "m_iHealth", cmpHealth2, 1);
	}
	else
	{
		SetEntProp(survivor, Prop_Send, "m_iHealth", g_iHRLimit, 1);
	}
}

public void Event_KillInfected(Event event, const char[] name, bool dontBroadcast)
{
	// g_iCfgExeced++;
	// PrintToChatAll("g_iCfgExeced: %d\n", g_iCfgExeced);
	int infected = GetClientOfUserId(event.GetInt("userid"));
	int survivor = GetClientOfUserId(event.GetInt("attacker"));
	
	// Plugin Enable or HRValue > 0
	// g_iHREnable = 1, g_iHRLimit = 200, g_iHRValue = 3
	if (g_iHREnable != 1 || g_iHRValue <= 0)
		return;
	
	if (!ValidSurvivorAndInfected(survivor, infected))
		return;

	SetSurvivorHealth(survivor, 0);
	
}

public void Event_HurtInfected(Event event, const char[] name, bool dontBroadcast)
{
	int infected = GetClientOfUserId(event.GetInt("userid"));
	int survivor = GetClientOfUserId(event.GetInt("attacker"));

	if (g_iHREnable != 2 || g_iHRValue <= 0)
		return;
	
	if (!ValidSurvivorAndInfected(survivor, infected))
		return;

	int dmg = event.GetInt("dmg_health");
	SetSurvivorHealth(survivor, dmg);
}

int L4D_GetPlayerTempHealth(int client)
{
    static Handle painPillsDecayCvar = null;
    if (painPillsDecayCvar == null)
    {
        painPillsDecayCvar = FindConVar("pain_pills_decay_rate");
        if (painPillsDecayCvar == null)
        {
            return -1;
        }
    }

    int tempHealth = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(painPillsDecayCvar))) - 1;
    return tempHealth < 0 ? 0 : tempHealth;
}

bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}