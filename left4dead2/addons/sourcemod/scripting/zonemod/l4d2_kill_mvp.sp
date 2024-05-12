#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <multicolors>  

#define VERSION "2.4"

#define	SMOKER	1
#define	BOOMER	2
#define	HUNTER	3
#define	SPITTER	4
#define	JOCKEY	5
#define	CHARGER 6
#define	TANK	8

#define	CLEAR_ATTACKER	0
#define	CLEAR_VICTIM	1

#define	MAX_ENTITY	2049

enum struct killData
{
	int player;
	int damage;
	float WitchDmg;
	int SI;
	int SIHS;
	int CI;
	int FF;
}

ConVar
	z_witch_health,
	g_cvDmgWithTank,
	g_cvDmgWithWitch,
	g_cvDmgWithCI,
	g_cvTankDmgNotify,
	g_cvWitchDmgNotify,
	// g_cvRepeatNotifyOn;
	g_cvRepeatNotifyTime;

bool
	g_bDmgWithTank,
	g_bDmgWithWitch,
	g_bDmgWithCI,
	g_bTankDmgNotify,
	g_bWitchDmgNotify,
	g_bTankAlive[MAXPLAYERS+1];

int
	g_iTotalDmg[MAXPLAYERS+1],
	g_iKillSI[MAXPLAYERS+1],
	g_iKillSIHeadshot[MAXPLAYERS+1],
	g_iKillCI[MAXPLAYERS+1],
	g_iFriendlyFire[MAXPLAYERS+1],
	g_iTankDmg[MAXPLAYERS+1][MAXPLAYERS+1],	//[victim][attacker]
	g_iSortField,
	g_iHp[MAXPLAYERS+1],
	g_iTempHp[MAXPLAYERS+1];

float
	g_fWitchHealth[MAX_ENTITY],
	g_fWitchDmg[MAX_ENTITY][MAXPLAYERS+1];

Handle g_hTimer = null;

public Plugin myinfo =
{
	name = "L4D2 Kill mvp",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_kill_mvp_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	z_witch_health = FindConVar("z_witch_health");

	g_cvDmgWithTank =		CreateConVar("l4d2_kill_mvp_add_tank_damage",				"0", 	"Total damage includes Tank damage.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvDmgWithWitch =		CreateConVar("l4d2_kill_mvp_add_witch_damage",				"0", 	"Total damage includes Witch damage.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvDmgWithCI =			CreateConVar("l4d2_kill_mvp_add_ci_damage",					"1", 	"Total damage includes common infected damage.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvTankDmgNotify =		CreateConVar("l4d2_kill_mvp_tank_death_damage_announce",	"1", 	"Notify Tank damage when Tank dies.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvWitchDmgNotify =	CreateConVar("l4d2_kill_mvp_witch_death_damage_announce",	"0", 	"Notify Witch damage when Witch dies.", FCVAR_NONE, true, 0.0, true, 1.0);
	// g_cvRepeatNotifyOn =	CreateConVar("l4d2_kill_mvp_repeat_announce",				"1", 	"Notify rank repeatlly.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvRepeatNotifyTime = 	CreateConVar("l4d2_kill_mvp_time", 							"90.0", "轮播时间间隔", FCVAR_NOTIFY, true, 10.0, true, 360.0);

	OnConVarChanged(null, "", "");

	g_cvDmgWithTank.AddChangeHook(OnConVarChanged);
	g_cvDmgWithWitch.AddChangeHook(OnConVarChanged);
	g_cvDmgWithCI.AddChangeHook(OnConVarChanged);
	g_cvTankDmgNotify.AddChangeHook(OnConVarChanged);
	g_cvWitchDmgNotify.AddChangeHook(OnConVarChanged);
	g_cvRepeatNotifyTime.AddChangeHook(ConVarChanged_Time);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	// HookEvent("player_hurt", Event_PlayerHurt);

	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_incapacitated_start", Event_PlayerIncapStart, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	
	HookEvent("witch_spawn", Event_WitchSpawn);
	HookEvent("witch_killed", Event_WitchKilled, EventHookMode_Pre);

	HookEvent("infected_hurt", Event_InfectedHurt);
	HookEvent("infected_death", Event_InfectedDeath);

	HookEvent("player_bot_replace", Event_BotReplacedPlayer);
	HookEvent("bot_player_replace", Event_PlayerReplacedBot);

	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);

	RegConsoleCmd("sm_mvp", Cmd_ShowTotalDamageRank);
	RegAdminCmd("sm_clear_mvp", Cmd_ClearMvp, ADMFLAG_ROOT);
	RegAdminCmd("sm_clear_ff", Cmd_ClearFF, ADMFLAG_ROOT);

	AutoExecConfig(true, "l4d2_kill_mvp");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			OnClientPutInServer(i);
	}
	g_hTimer = CreateTimer(g_cvRepeatNotifyTime.FloatValue, Timer_ShowTotalDamageRank, _, TIMER_REPEAT);
}

void ConVarChanged_Time(Handle convar, const char[] oldValue, const char[] newValue)
{
	delete g_hTimer;
	g_hTimer = CreateTimer(g_cvRepeatNotifyTime.FloatValue, Timer_ShowTotalDamageRank, _, TIMER_REPEAT);
}

public Action Timer_ShowTotalDamageRank(Handle timer)
{
	ShowTotalDamageRank();
	return Plugin_Continue;
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bDmgWithTank = g_cvDmgWithTank.BoolValue;
	g_bDmgWithWitch = g_cvDmgWithWitch.BoolValue;
	g_bDmgWithCI = g_cvDmgWithCI.BoolValue;
	g_bTankDmgNotify = g_cvTankDmgNotify.BoolValue;
	g_bWitchDmgNotify = g_cvWitchDmgNotify.BoolValue;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 0; i <= MaxClients; i++)
	{
		g_iTotalDmg[i] = 0;
		g_iKillSI[i] = 0;
		g_iKillSIHeadshot[i] = 0;
		g_iKillCI[i] = 0;
		// g_iFriendlyFire[i] = 0;

		ClearTankDamage(i, CLEAR_VICTIM);
		g_bTankAlive[i] = false;
	}

	for (int i = 0; i < MAX_ENTITY; i++)
	{
		ClearWitchDamage(i, CLEAR_VICTIM);
		g_fWitchHealth[i] = 0.0;
	}
}

void ClearTankDamage(int index, int type)
{
	if (!g_bTankDmgNotify)
		return;

	// Clear all players to this Tank's damage.
	if (type == CLEAR_VICTIM)
	{
		for (int i = 0; i <= MaxClients; i++)
			g_iTankDmg[index][i] = 0;
	}

	// Clear this player's damage to all Tanks.
	else if (type == CLEAR_ATTACKER)
	{
		for (int i = 0; i <= MaxClients; i++)
			g_iTankDmg[i][index] = 0;
	}
}

void ClearWitchDamage(int index, int type)
{
	if (!g_bWitchDmgNotify)
		return;

	// Clear all players to this Witch's damage.
	if (type == CLEAR_VICTIM)
	{
		for (int i = 0; i <= MaxClients; i++)
			g_fWitchDmg[index][i] = 0.0;
	}

	// Clear this player's damage to all Witchs.
	else if (type == CLEAR_ATTACKER)
	{
		for (int i = 0; i < MAX_ENTITY; i++)
			g_fWitchDmg[i][index] = 0.0;
	}
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ShowTotalDamageRank();
}

Action Cmd_ShowTotalDamageRank(int client, int args)
{
	ShowTotalDamageRank();
	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	g_iTotalDmg[client] = 0;
	g_iKillSI[client] = 0;
	g_iKillSIHeadshot[client] = 0;
	g_iKillCI[client] = 0;
	// g_iFriendlyFire[client] = 0;
	
	ClearTankDamage(client, CLEAR_ATTACKER);
	ClearWitchDamage(client, CLEAR_ATTACKER);

	/* SDKHook_OnTakeDamageAlive不会统计一枪黑倒的友伤 */
	SDKUnhook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);

	SDKUnhook(client, SDKHook_TraceAttack, TraceAttackFF);
	SDKHook(client, SDKHook_TraceAttack, TraceAttackFF);
}

public void OnClientDisconnect(int client)
{
	// g_iFriendlyFire[client] = 0;
}

stock int L4D_GetPlayerTempHealth(int client)
{
	if (!IsValidSur(client)) return 0;
	
	static Handle painPillsDecayCvar = INVALID_HANDLE;
	if (painPillsDecayCvar == INVALID_HANDLE)
	{
		painPillsDecayCvar = FindConVar("pain_pills_decay_rate");
		if (painPillsDecayCvar == INVALID_HANDLE)
		{
			return -1;
		}
	}
	int tempHealth = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(painPillsDecayCvar))) - 1;
	return tempHealth < 0 ? 0 : tempHealth;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && IsClientInGame(client) && GetClientTeam(client) == 3 && GetZombieClass(client) == TANK)
	{
		ClearTankDamage(client, CLEAR_VICTIM);
		g_bTankAlive[client] = true;
	}
}

Action OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (damage <= 0.0)
		return Plugin_Continue;

	if (IsValidSur(attacker) && IsPlayerAlive(attacker))
	{
		if (IsValidSI(victim) && IsPlayerAlive(victim))
		{
			static int iVictimHealth;
			iVictimHealth = GetEntProp(victim, Prop_Data, "m_iHealth");

			switch (GetZombieClass(victim))
			{
				case SMOKER, BOOMER, HUNTER, SPITTER, JOCKEY, CHARGER:
				{
					if (damage >= float(iVictimHealth))
						g_iTotalDmg[attacker] += iVictimHealth;
					else
						g_iTotalDmg[attacker] += RoundToFloor(damage);
				}
				case TANK:
				{
					static int iLastAttacker[MAXPLAYERS+1];
					static int iVictimHealthPost[MAXPLAYERS+1];

					if (!g_bTankAlive[victim])
						return Plugin_Continue;

					if (!GetEntProp(victim, Prop_Send, "m_isIncapacitated"))
					{
						iLastAttacker[victim] = attacker;
						iVictimHealthPost[victim] = iVictimHealth - RoundToFloor(damage);
						
						if (g_bDmgWithTank)
							g_iTotalDmg[attacker] += RoundToFloor(damage);

						if (g_bTankDmgNotify)
							g_iTankDmg[victim][attacker] += RoundToFloor(damage);
					}
					else
					{
						g_bTankAlive[victim] = false;

						if (g_bDmgWithTank)
							g_iTotalDmg[iLastAttacker[victim]] += iVictimHealthPost[victim];


						if (g_bTankDmgNotify)
							g_iTankDmg[victim][iLastAttacker[victim]] += iVictimHealthPost[victim];
					}
				}
			}
		}
		else if (IsValidSur(victim) && IsPlayerAlive(victim))
		{
			if (attacker != victim)
			{
				int actualDmg = RoundToFloor(damage) > g_iHp[victim] + g_iTempHp[victim] ? g_iHp[victim] + g_iTempHp[victim] : RoundToFloor(damage);
				g_iFriendlyFire[attacker] += actualDmg;
			}
		}
	}
	return Plugin_Continue;
}

// Bot replaced a player.
// The player lost control of Tank. add damage to the new Tank bot.
void Event_BotReplacedPlayer(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	int bot = GetClientOfUserId(event.GetInt("bot"));

	if (bot > 0 && IsClientInGame(bot) && GetClientTeam(bot) == 3 && GetZombieClass(bot) == TANK)
	{
		for (int i = 1; i <= MaxClients; i++)
			g_iTankDmg[bot][i] += g_iTankDmg[player][i];

		ClearTankDamage(player, CLEAR_VICTIM);
	}
}

// Player replaced a bot.
// The player has take over a Tank bot. add damage to the new Tank player.
void Event_PlayerReplacedBot(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	int bot = GetClientOfUserId(event.GetInt("bot"));

	if (player > 0 && IsClientInGame(player) && GetClientTeam(player) == 3 && GetZombieClass(player) == TANK)
	{
		for (int i = 1; i <= MaxClients; i++)
			g_iTankDmg[player][i] += g_iTankDmg[bot][i];

		ClearTankDamage(bot, CLEAR_VICTIM);
	}
}

bool checkrealplayerinSV(int client)
{
	for (int i = 1; i < MaxClients + 1; i++)
		if( IsClientConnected(i) && !IsFakeClient(i) && i != client)
			return true;
	return false;
}

public void Event_PlayerDisconnect(Event hEvent, const char[] name, bool dontBroadcast)
{
	/* 清空放外面掉线重置 放里面服务器没人重置 */
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if( !client || (IsClientConnected(client) && !IsClientInGame(client))) return;
	if( client && !IsFakeClient(client) && !checkrealplayerinSV(client))
	{
		for (int i = 1; i <= MAXPLAYERS; ++i)
		{
			/* 玩家反复重连后不清楚client_index是否会重置 */
			g_iFriendlyFire[i] = 0;
		}
	}
}

Action TraceAttackFF(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamagetype, int &iAmmotype, int iHitbox, int iHitgroup)
{
	if (IsValidSur(iVictim) && IsValidSur(iAttacker))
	{
		int tempHp = L4D_GetPlayerTempHealth(iVictim);
		int hp = GetClientHealth(iVictim);
		// PrintToChatAll("%d, %d ,%d", hp, tempHp, RoundToFloor(fDamage));
		g_iHp[iVictim] = hp;
		g_iTempHp[iVictim] = tempHp;
	}
	return Plugin_Continue;
}

void Event_PlayerIncapStart(Handle event, const char [] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (!(IsValidSur(victim) && IsValidSur(attacker)) || attacker == victim) return;
	
	char attackerName[64], victimName[64];
	GetClientName(attacker, attackerName, sizeof(attackerName) - 1);
	GetClientName(victim, victimName, sizeof(victimName) - 1);

	g_iFriendlyFire[attacker] += (g_iHp[victim] + g_iTempHp[victim]);
	
	// CPrintToChatAll("{blue}?{olive} %s {blue}对{olive} %s {blue}造成了{yellow} %i {blue}点伤害并击倒了对方", attackerName, victimName, g_iHp[victim] + g_iTempHp[victim]);
	return;
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int victim = GetClientOfUserId(event.GetInt("userid"));
	bool isHeadshot = event.GetBool("headshot");

	g_bTankAlive[victim] = false;

	if (IsValidSI(victim))
	{
		if (IsValidSur(attacker) && IsPlayerAlive(attacker))
		{
			g_iKillSI[attacker]++;
			if (isHeadshot)
				g_iKillSIHeadshot[attacker]++;
		}

		if (GetZombieClass(victim) != TANK)
			return;

		ShowTankDamageRank(victim);
		ClearTankDamage(victim, CLEAR_VICTIM);
	}
	
	else if (IsValidSur(victim) && IsValidSur(attacker))
	{
		if (attacker != victim)
		{
			char attackerName[64], victimName[64];
			GetClientName(attacker, attackerName, sizeof(attackerName) - 1);
			GetClientName(victim, victimName, sizeof(victimName) - 1);

			// will fire hurt before?
			// g_iFriendlyFire[attacker] += (g_iHp[victim] + g_iTempHp[victim]);
			
			// CPrintToChatAll("{blue}?{olive} %s {blue}对{olive} %s {blue}造成了{yellow} %i {blue}点伤害并击杀了对方", attackerName, victimName, g_iHp[victim] + g_iTempHp[victim]);
		}
		return;
	}
}

void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int witch = event.GetInt("witchid");
	if (IsValidEntityEx(witch))
	{
		ClearWitchDamage(witch, CLEAR_VICTIM);
		g_fWitchHealth[witch] = z_witch_health.FloatValue;

		SDKUnhook(witch, SDKHook_OnTakeDamageAlive, OnWitchTakeDamageAlive);
		SDKHook(witch, SDKHook_OnTakeDamageAlive, OnWitchTakeDamageAlive);
	}
}

Action OnWitchTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (damage <= 0.0 || g_fWitchHealth[victim] <= 0.0 || !IsValidEntityEx(victim))
		return Plugin_Continue;

	if (damage >= g_fWitchHealth[victim])
	{
		if (IsValidSur(attacker) && IsPlayerAlive(attacker))
		{
			if (g_bDmgWithWitch)
				g_iTotalDmg[attacker] += RoundToNearest(g_fWitchHealth[victim]);

			if (g_bWitchDmgNotify)
				g_fWitchDmg[victim][attacker] += g_fWitchHealth[victim];
		}
		
		g_fWitchHealth[victim] = 0.0;
	}
	else
	{
		g_fWitchHealth[victim] -= damage;

		if (IsValidSur(attacker) && IsPlayerAlive(attacker))
		{
			if (g_bDmgWithWitch)
				g_iTotalDmg[attacker] += RoundToNearest(damage);

			if (g_bWitchDmgNotify)
				g_fWitchDmg[victim][attacker] += damage;
		}
		
	}
	return Plugin_Continue;
}

void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
	int witch = event.GetInt("witchid");
	g_fWitchHealth[witch] = 0.0;

	ShowWitchDamageRank(witch);
	ClearWitchDamage(witch, CLEAR_VICTIM);
}

void Event_InfectedHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bDmgWithCI)
		return;

	static int attacker, damage, victim;
	static char sClassName[6];
		
	attacker = GetClientOfUserId(event.GetInt("attacker"));
	damage  = event.GetInt("amount");
	victim = event.GetInt("entityid");

	if (!IsValidEntityEx(victim))
		return;

	if (!GetEdictClassname(victim, sClassName, sizeof(sClassName)) || !strcmp(sClassName, "witch", false))
		return;

	if (IsValidSur(attacker) && IsPlayerAlive(attacker))
		g_iTotalDmg[attacker] += damage;
}

void Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (IsValidSur(attacker) && IsPlayerAlive(attacker))
		g_iKillCI[attacker]++;
}

void ShowTankDamageRank(int tank)
{
	if (!g_bTankDmgNotify)
		return;

	killData[] data = new killData[MaxClients];
	int iCount, iTotalDmg;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_iTankDmg[tank][i] > 0 && IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			data[iCount].player = i;
			data[iCount].damage = g_iTankDmg[tank][i];

			iTotalDmg += g_iTankDmg[tank][i];
			iCount++;
		}
	}

	if (iCount > 0)
	{
		g_iSortField = killData::damage;
		SortCustom2D(data, iCount, SortByDescending);

		if (!IsFakeClient(tank))
			CPrintToChatAll("{blue}[Tank {olive}(%N) {blue}Damage]{default}:", tank);
		else
			CPrintToChatAll("{blue}[Tank Damage]{default}:");

		for (int i; i < iCount; i++)
			CPrintToChatAll("{blue}[{yellow}%i{blue}] ({yellow}%i{default}%%{blue})  {olive}%N", data[i].damage, RoundToNearest(float(data[i].damage)/iTotalDmg*100), data[i].player);
	}
}

void ShowWitchDamageRank(int witch)
{
	if (!g_bWitchDmgNotify)
		return;

	killData[] data = new killData[MaxClients];
	int iCount;
	float fTotalDmg;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_fWitchDmg[witch][i] > 0.0 && IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			data[iCount].player = i;
			data[iCount].WitchDmg = g_fWitchDmg[witch][i];

			fTotalDmg += g_fWitchDmg[witch][i];
			iCount++;
		}
	}

	if (iCount > 0)
	{
		g_iSortField = killData::WitchDmg;
		SortCustom2D(data, iCount, SortByDescending);

		CPrintToChatAll("{blue}[Witch Damage]{default}:");

		for (int i; i < iCount; i++)
			CPrintToChatAll("{blue}[{yellow}%i{blue}] ({yellow}%i{default}%%{blue})  {olive}%N", RoundToNearest(data[i].WitchDmg), RoundToNearest(data[i].WitchDmg/fTotalDmg*100), data[i].player);
	}
}

void ShowTotalDamageRank()
{
	killData[] data = new killData[MaxClients];
	int iCount, iTotalDmg, iTotalFF;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			data[iCount].player = i;
			data[iCount].damage = g_iTotalDmg[i];
			data[iCount].SI = g_iKillSI[i];
			data[iCount].SIHS = g_iKillSIHeadshot[i];
			data[iCount].CI = g_iKillCI[i];
			data[iCount].FF = g_iFriendlyFire[i];

			iTotalDmg += g_iTotalDmg[i];
			iTotalFF += g_iFriendlyFire[i];
			iCount++;
		}
	}
	
	if (iCount > 0)
	{
		g_iSortField = killData::damage;
		SortCustom2D(data, iCount, SortByDescending);

		CPrintToChatAll("{blue}[击杀排名]{default}:");

		for (int i; i < iCount; i++)
			CPrintToChatAll("{blue}伤害{default}:  {yellow}%-6i  {blue}特感{default}:  {yellow}%-3i  {blue}爆头{default}:  {yellow}%-3i  {blue}丧尸{default}:  {yellow}%-4i  {blue}友伤{default}:  {yellow}%-5i  {blue}|{default}  {olive}%N", data[i].damage, data[i].SI, data[i].SIHS, data[i].CI, data[i].FF, data[i].player);

		if (iTotalDmg > 0)
			CPrintToChatAll("{blue}[通天带]{default}: {olive}%N   {blue}总伤害{default}:  {yellow}%i  {default}({yellow}%i{default}%%)", data[0].player, data[0].damage, RoundToNearest(float(data[0].damage)/iTotalDmg*100));
		
		if (iTotalFF > 0)
		{
			g_iSortField = killData::FF;
			SortCustom2D(data, iCount, SortByDescending);
			CPrintToChatAll("{blue}[幽默糕手]{default}: {olive}%N   {blue}黑枪值{default}:  {yellow}%i  {default}({yellow}%i{default}%%)", data[0].player, data[0].FF, RoundToNearest(float(data[0].FF)/iTotalFF*100));
		}
	}
}

int SortByDescending(int[] x, int[] y, const int[][] array, Handle hndl)
{
	if (x[g_iSortField] > y[g_iSortField])
		return -1;
	if (x[g_iSortField] < y[g_iSortField])
		return 1;
	return 0;
}

bool IsValidEntityEx(int entity)
{
	if (entity > MaxClients)
	{
		return IsValidEntity(entity);
	}
	return false;
}

bool IsValidSI(int client)
{
	if (client > 0 && client <= MaxClients)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 3)
		{
			return true;
		}
	}
	return false;
}

bool IsValidSur(int client)
{
	if (client > 0 && client <= MaxClients)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			return true;
		}
	}
	return false;
}

int GetZombieClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

Action Cmd_ClearMvp(int client, int args)
{
	Event_RoundStart(null, "", true);
	return Plugin_Handled;
}

Action Cmd_ClearFF(int client, int args)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iFriendlyFire[i] = 0;
	}
	return Plugin_Handled;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("L4D2_GetKillData", Native_GetKillData);
	return APLRes_Success;
}

int Native_GetKillData(Handle plugin, int numParams)
{
	killData data;
	int player = GetNativeCell(1);
	
	data.player = player;
	data.damage = g_iTotalDmg[player];
	data.SI = g_iKillSI[player];
	data.SIHS = g_iKillSIHeadshot[player];
	data.CI = g_iKillCI[player];
	data.FF = g_iFriendlyFire[player];

	SetNativeArray(2, data, sizeof(data));
	return 0;
}

