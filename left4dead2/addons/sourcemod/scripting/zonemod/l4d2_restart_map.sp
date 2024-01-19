#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

public Plugin myinfo =
{
	name = "Restart Current Map by Sourcemod",
	author = "Azuki(Cirno)",
	description = "",
	version = "1.0",
	url = ""
};

public void OnPluginStart()
{
	RegAdminCmd("sm_restartmap", Cmd_RestartCurMap, ADMFLAG_ROOT);
}

public Action Cmd_RestartCurMap(int client, int args)
{
	CreateTimer(3.0, Timer_RestartCurMap);
}

public Action Timer_RestartCurMap(Handle timer)
{
	char szCurMapName[64];
	GetCurrentMap(szCurMapName, sizeof(szCurMapName));
	ServerCommand("changelevel %s", szCurMapName);
}
