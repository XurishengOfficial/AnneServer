#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <colors>

#define PLUGIN_VERSION	"1.0"

#define TEAM_SPECTATOR		1
#define TEAM_SURVIVORS 		2
#define TEAM_INFECTED 		3

#define ZOMBIECLASS_SMOKER	1
#define ZOMBIECLASS_BOOMER	2
#define ZOMBIECLASS_HUNTER	3
#define ZOMBIECLASS_SPITTER	4
#define ZOMBIECLASS_JOCKEY	5
#define ZOMBIECLASS_CHARGER	6
#define ZOMBIECLASS_TANK	8

#define QUERY_CD 			3.0

#define IsAliveSurvivor(%1)	(%1 && IsClientInGame(%1) && GetClientTeam(%1) == TEAM_SURVIVORS && IsPlayerAlive(%1))//&& !IsFakeClient(%1) 

int g_iShouldQuery = 1;

public Plugin myinfo = 
{
	name 			= "l4d2_query_si",
	author 			= "Azuki/Cirno",
	description 	= "E+W查询当前特感配置",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}

public void OnPluginStart()
{
	
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (buttons & (IN_FORWARD | IN_USE) == (IN_FORWARD | IN_USE)) 
	{
		if(!IsAliveSurvivor(client))
			return Plugin_Continue;

		if (!g_iShouldQuery)
			return Plugin_Continue;

		int smokerNum = 0;
		int chargerNum = 0;
		int jockyNum = 0;
		int hunterNum = 0;
		int spitterNum = 0;
		int boomerNum = 0;
		int tankNum = 0;
		int siNum = 0;

		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_INFECTED || !IsPlayerAlive(i))
				continue;
			
			siNum++;
			int siType = GetEntProp(i, Prop_Send, "m_zombieClass");
			switch (siType)
			{
				case ZOMBIECLASS_TANK:
				{
					tankNum++;
				}
				case ZOMBIECLASS_SMOKER:
				{
					smokerNum++;
				}
				case ZOMBIECLASS_BOOMER:
				{
					boomerNum++;
				}
				case ZOMBIECLASS_HUNTER:
				{
					hunterNum++;
				}
				case ZOMBIECLASS_SPITTER:
				{
					spitterNum++;
				}
				case ZOMBIECLASS_JOCKEY:
				{
					jockyNum++;
				}
				case ZOMBIECLASS_CHARGER:
				{
					chargerNum++;
				}
			}
		}
		char queryResult[256];
		if (siNum)
		{
			Format(queryResult, sizeof(queryResult), "{olive}★{default} 剩余特感[ {blue}%d {default}]", siNum);
			if (tankNum)
				Format(queryResult, sizeof(queryResult), "%s [{blue}Tank: {default}%d]", queryResult, tankNum);
			if (smokerNum)
				Format(queryResult, sizeof(queryResult), "%s [{blue}Smoker: {default}%d]", queryResult, smokerNum);
			if (boomerNum)
				Format(queryResult, sizeof(queryResult), "%s [{blue}Boomer: {default}%d]", queryResult, boomerNum);
			if (hunterNum)
				Format(queryResult, sizeof(queryResult), "%s [{blue}Hunter: {default}%d]", queryResult, hunterNum);
			if (spitterNum)
				Format(queryResult, sizeof(queryResult), "%s [{blue}Spitter: {default}%d]", queryResult, spitterNum);
			if (jockyNum)
				Format(queryResult, sizeof(queryResult), "%s [{blue}Jocky: {default}%d]", queryResult, jockyNum);
			if (chargerNum)
				Format(queryResult, sizeof(queryResult), "%s [{blue}Charger: {default}%d]", queryResult, chargerNum);
		}
		else
		{
			Format(queryResult, sizeof(queryResult), "{olive}★{default} 无特感存活.");
		}
		CPrintToChatAll(queryResult);
		g_iShouldQuery = 0;

		CreateTimer(QUERY_CD, Timer_EnableQuerySI, client);
	}
	return Plugin_Continue;
}

public Action Timer_EnableQuerySI(Handle timer, any client)
{
	g_iShouldQuery = 1;
	return Plugin_Stop;
}