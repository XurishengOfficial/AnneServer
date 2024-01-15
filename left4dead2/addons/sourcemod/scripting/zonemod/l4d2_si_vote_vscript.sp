#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <left4dhooks>
ConVar g_hDirectorSINum;
ConVar g_hDirectorSIRespawnInterval;

public Plugin myinfo =
{
	name = "SI Spawn Set Plugin For Vscript",
	author = "Sir.P / Cirno",
	description = "通过投票修改脚本刷特",
	version = "1.0",
	url = ""
};

public void OnPluginStart()
{
	g_hDirectorSINum = CreateConVar("l4d2_director_specials_num", "28", "特感数量", _, true, 8.0, true, 28.0);
	g_hDirectorSIRespawnInterval = CreateConVar("l4d2_director_specials_respawn_interval", "15", "刷新间隔", _, true, 0.0);

	HookConVarChange(g_hDirectorSINum, reload_script);
	HookConVarChange(g_hDirectorSIRespawnInterval, reload_script);
}

public reload_script(Handle convar, char[] oldValue, char[] newValue)
{
	ConVar gamemode = FindConVar("mp_gamemode");
	char modestr[64];
	gamemode.GetString(modestr, 64);
	char file[64];
	Format(file, 64, "%s.nut", modestr);
	CheatCommand("script_reload_code", file);
	PrintToServer("Script %s.nut Reloaded", modestr);
	CPrintToChatAll("{olive}❀ {default}当前特感最高同屏{blue}%d{default}特, 刷新间隔{blue}%d{default}s", g_hDirectorSINum.IntValue, g_hDirectorSIRespawnInterval.IntValue);
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client)) return;
		CPrintToChatAll("{olive}❀ {default}当前特感最高同屏{blue}%d{default}特, 刷新间隔{blue}%d{default}s", g_hDirectorSINum.IntValue, g_hDirectorSIRespawnInterval.IntValue);
}

public void CheatCommand(char[] strCommand, char[] strParam1)
{
	int flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
	ServerCommand("%s %s", strCommand, strParam1);
	//SetCommandFlags(strCommand, flags);
	CreateTimer(0.5, RestoreCheatFlag);
}

public Action RestoreCheatFlag(Handle timer)
{
	int flags = GetCommandFlags("script_reload_code");
	SetCommandFlags("script_reload_code", flags | FCVAR_CHEAT);
	return Plugin_Stop;
}