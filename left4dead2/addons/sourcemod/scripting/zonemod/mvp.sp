#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

int sikills[MAXPLAYERS + 1];
int cikills[MAXPLAYERS + 1];
int siheads[MAXPLAYERS + 1];
int ciheads[MAXPLAYERS + 1];
int teamff[MAXPLAYERS + 1];
int teamrf[MAXPLAYERS + 1];
int sidmg[MAXPLAYERS + 1];
int sidmgall;
int sikillsall;
int cikillsall;
int teamffall;
int teamrfall;

ConVar g_hAds_Allow;
ConVar g_hAds_Time;
Handle g_hTimer = null;

public Plugin myinfo =
{
	name = "击杀排行统计",
	description = "击杀排行统计",
	author = "白色幽灵 WhiteGT",
	version = "0.6",
	url = "null"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_mvp", Command_kill, "Show Mvp");

	g_hAds_Allow = CreateConVar("sm_mvp_on", "1", "是否开启排行轮播(0-禁用,1-开启)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hAds_Time = CreateConVar("sm_mvp_time", "150.0", "轮播时间间隔", FCVAR_NOTIFY, true, 10.0, true, 360.0);

	//AutoExecConfig(true,"l4d_mvp");

	g_hAds_Allow.AddChangeHook(ConVarChanged_Allow);
	g_hAds_Time.AddChangeHook(ConVarChanged_Cvars);

	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("infected_death", Event_InfectedDeath);
	HookEvent("player_disconnect", Event_PlayerDisconnect);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_MapTransition, EventHookMode_PostNoCopy);
	
	if(g_hAds_Allow.BoolValue)
		g_hTimer = CreateTimer(g_hAds_Time.FloatValue, Timer_DisplayKill);
}

public void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	delete g_hTimer;
	if(g_hAds_Allow.BoolValue)
		g_hTimer = CreateTimer(g_hAds_Time.FloatValue, Timer_DisplayKill);
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	if(g_hAds_Allow.BoolValue)
	{
		delete g_hTimer;
		g_hTimer = CreateTimer(g_hAds_Time.FloatValue, Timer_DisplayKill);
	}
}

public void OnMapEnd()
{
	delete g_hTimer;
}

public void OnPluginEnd()
{
	delete g_hTimer;
}

public Action Command_kill(int client, int args)
{
	if(client == 0 || !IsClientInGame(client))
		return Plugin_Handled;

	displaykillinfected();
	return Plugin_Handled;
}

public Action Timer_DisplayKill(Handle timer)
{
	g_hTimer = null;
	displaykillinfected();
	if(g_hAds_Allow.BoolValue)
		g_hTimer = CreateTimer(g_hAds_Time.FloatValue, Timer_DisplayKill);
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
/*	
	sidmgall -= sidmg[client];
	sikillsall -= sikills[client];
	cikillsall -= cikills[client];
	teamffall -= teamff[client];
	teamrfall -= teamrf[client];
*/
	sikills[client] = 0;
	cikills[client] = 0;
	siheads[client] = 0;
	ciheads[client] = 0;
	teamff[client] = 0;
	teamrf[client] = 0;
	sidmg[client] = 0;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	Clear_KillData();
	delete g_hTimer;
	if(g_hAds_Allow.BoolValue)
		g_hTimer = CreateTimer(g_hAds_Time.FloatValue, Timer_DisplayKill);
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	delete g_hTimer;
	displaykillinfected();
}

public Action Event_MapTransition(Event event, const char[] name, bool dontBroadcast)
{
	delete g_hTimer;
	displaykillinfected();
}

public Action Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast)
{
	int killer = GetClientOfUserId(event.GetInt("attacker"));
	bool headshot = event.GetBool("headshot");

	if(killer == 0 || GetClientTeam(killer) != 2)
		return;

	cikills[killer] += 1;
	cikillsall += 1;

	if(headshot)
		ciheads[killer]++;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int killer = GetClientOfUserId(event.GetInt("attacker"));
	int victim = GetClientOfUserId(event.GetInt("userid"));
	bool headshot = event.GetBool("headshot");

	if(killer == 0 || victim == 0 || GetClientTeam(killer) != 2 || GetClientTeam(victim) != 3)
		return;

	int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");

	if(0 < zombieClass < 7)
	{
		sikills[killer]++;
		sikillsall++;
	}

	if(zombieClass == 8)
		sikills[killer]++;

	if(headshot)
		siheads[killer]++;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int killer = GetClientOfUserId(event.GetInt("attacker"));
	
	int dmg = event.GetInt("dmg_health");
	int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");

	if(victim == 0 || killer == 0 || victim == killer || GetClientTeam(killer) != 2)
		return;


	if(GetClientTeam(victim) == 3 && 0 < zombieClass < 7)
	{
		sidmg[killer] += dmg;
		sidmgall += dmg;
	}

	if(GetClientTeam(victim) == 2)
	{
		teamff[killer] += dmg;
		teamffall += dmg;
		
		teamrf[victim] += dmg;
		teamrfall += dmg;
	}
}

void displaykillinfected()
{
	int client;
	int players;
	int players_clients[16];
	int sikl;
	int cikl;
	int sihd;
	int cihd;
	int tmff;
	int tmrf;
	int sidg;

	for(client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && (GetClientTeam(client) == 2 || ((GetClientTeam(client) == 1 || GetClientTeam(client) == 3) && !IsFakeClient(client))))
			players_clients[players++] = client;
	}

	PrintToChatAll("\x04[ \x03MVP\x04 ] \x05击杀排名统计：\n");

	SortCustom1D(players_clients, players, SortByDamageDesc);
	for(int i; i < 8; i++)   //最多显示几行，建议不要太大
	{
		client = players_clients[i];
		sikl = sikills[client];
		cikl = cikills[client];
		sihd = siheads[client];
		tmff = teamff[client];
		tmrf = teamrf[client];
		if(client > 0)
			PrintToChatAll("\x04[\x03统计\x04] [\x05特感\x04: \x03%d \x04] [\x05丧尸: \x03%d \x04] [\x05友伤: \x03%d \x04] [\x05被黑:\x03%d \x04] [\x05昵称\x04: \x03%N\x04 ]\n", sikl, cikl, tmff, tmrf, client);
	}

	SortCustom1D(players_clients, players, SortBysiDesc);
	client = players_clients[0];
	sidg = sidmg[client];
	sikl = sikills[client];
	if(sikl > 500)      //特感击杀数，大于此值，就会显示
		PrintToChatAll("\x04[\x03MVP\x04] \x05特感杀手: \x03%N \x04[ \x05伤害: \x03%d \x04(\x03%.0f%%\x04) ] [ \x05击杀: \x03%d \x04(\x03%.0f%%\x04) ]\n", client, sidg, float(sidg) / float(sidmgall) * 100, sikl, float(sikl) / float(sikillsall) * 100);

	SortCustom1D(players_clients, players, SortByciDesc);
	client = players_clients[0];
	cikl = cikills[client];
	cihd = ciheads[client];
	if(cikl > 1000)    //丧尸击杀数，大于此值，就会显示
		PrintToChatAll("\x04[\x03MVP\x04] \x05清尸狂人: \x03%N \x04[ \x05击杀: \x03%d \x04(\x03%.0f%%\x04) ] [ \x05爆头: \x03%d \x04(\x03%.0f%%\x04) ]\n", client, cikl, float(cikl) / float(cikillsall) * 100, cihd, float(cihd) / float(cikl) * 100);

	SortCustom1D(players_clients, players, SortByFFDesc);
	client = players_clients[0];
	tmff = teamff[client];
	if(tmff > 1000)   //黑枪伤害总值，大于此值，就会显示
		PrintToChatAll("\x04[\x03MVP\x04] \x05黑枪之王: \x03%N \x04[ \x05友伤: \x03%d \x04(\x03%.0f%%\x04) ]\n", client, tmff, float(tmff) / float(teamffall) * 100);
		
	SortCustom1D(players_clients, players, SortByRFDesc);
	client = players_clients[0];
	tmrf = teamrf[client];
	if(tmrf > 1000)   //挨黑伤害总值，大于此值，就会显示
		PrintToChatAll("\x04[\x03MVP\x04] \x05挨枪之王: \x03%N \x04[ \x05被黑: \x03%d \x04(\x03%.0f%%\x04) ]\n", client, tmrf, float(tmrf) / float(teamrfall) * 100);
}

public int SortByDamageDesc(int elem1, int elem2, int[] array, Handle hndl)
{
	if(sikills[elem2] < sikills[elem1])
		return -1;
	else if(sikills[elem1] < sikills[elem2])
		return 1;

	if(elem1 > elem2)
		return -1;
	else if(elem2 > elem1)
		return 1;

	return 0;
}

public int SortBysiDesc(int sik1, int sik2, int[] array, Handle hndl)
{
	if(sidmg[sik2] < sidmg[sik1])
		return -1;
	else if(sidmg[sik1] < sidmg[sik2])
		return 1;

	if(sik1 > sik2)
		return -1;
	else if(sik2 > sik1)
		return 1;

	return 0;
}

public int SortByciDesc(int cik1, int cik2, int[] array, Handle hndl)
{
	if(cikills[cik2] < cikills[cik1])
		return -1;
	else if(cikills[cik1] < cikills[cik2])
		return 1;

	if(cik1 > cik2)
		return -1;
	else if(cik2 > cik1)
		return 1;

	return 0;
}

public int SortByFFDesc(int tff1, int tff2, int[] array, Handle hndl)
{
	if(teamff[tff2] < teamff[tff1])
		return -1;
	else if(teamff[tff1] < teamff[tff2])
		return 1;

	if(tff1 > tff2)
		return -1;
	else if(tff2 > tff1)
		return 1;

	return 0;
}

public int SortByRFDesc(int trf1, int trf2, int[] array, Handle hndl)
{
	if(teamrf[trf2] < teamrf[trf1])
		return -1;
	else if(teamrf[trf1] < teamrf[trf2])
		return 1;

	if(trf1 > trf2)
		return -1;
	else if(trf2 > trf1)
		return 1;

	return 0;
}

void Clear_KillData()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		sikills[i] = 0;
		cikills[i] = 0;
		siheads[i] = 0;
		ciheads[i] = 0;
		teamff[i] = 0;
		teamrf[i] = 0;
		sidmg[i] = 0;
	}

	sidmgall = 0;
	sikillsall = 0;
	cikillsall = 0;
	teamffall = 0;
	teamrfall = 0;
}