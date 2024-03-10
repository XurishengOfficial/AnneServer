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
	g_hDirectorSINum = CreateConVar("l4d_infectedbots_max_specials", "28", "特感数量", FCVAR_NONE, true, 0.0, true, 31.0);
	g_hDirectorSIRespawnInterval = CreateConVar("l4d_infectedbots_spawn_time_max", "15", "刷新间隔", FCVAR_NONE, true, 0.0);
	RegAdminCmd("sm_si_num", Cmd_ChangeSINum, ADMFLAG_GENERIC, "Admin change the script SI num");
	RegAdminCmd("sm_si_time", Cmd_ChangeSITime, ADMFLAG_GENERIC, "Admin change the script SI spawn time");
	// RegAdminCmd("sm_si_time", Cmd_ChangeSITime, ADMFLAG_GENERIC, "Change the script SI spawn time");

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
	CPrintToChatAll("{yellow}SIControlScript{default}: {blue}当前特感最高同屏{yellow} %d {blue}特，复活时间 {yellow} %d {blue}秒{default}.", g_hDirectorSINum.IntValue, g_hDirectorSIRespawnInterval.IntValue);
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

public Action Cmd_ChangeSINum(int client, int args)
{
	if (args < 1)
	{
		CPrintToChatAll("{yellow}SIControlScript{default}: {blue}sm_si_num <特感数量>");
		return Plugin_Handled;	
	}
	
	char sSINum[8];
	int iSINum = -1;
	
	GetCmdArg(1, sSINum, sizeof(sSINum));
	
	// Make sure the arg is unsigned int
	if (!IsUnsignedInteger(sSINum))
	{
		CReplyToCommand(client, "{yellow}SIControlScript{default}: {blue}<特感数量> {olive}invalid{default}.");
		return Plugin_Handled;
	}

	iSINum = StringToInt(sSINum);
	ServerCommand("l4d_infectedbots_max_specials %d", iSINum);
	return Plugin_Handled;
}

public Action Cmd_ChangeSITime(int client, int args)
{
	if (args < 1)
	{
		CPrintToChatAll("{yellow}SIControlScript{default}: {blue}sm_si_num <特感复活时间>");
		return Plugin_Handled;	
	}
	
	char sSITime[8];
	int iSITime = -1;
	
	GetCmdArg(1, sSITime, sizeof(sSITime));
	
	// Make sure the arg is unsigned int
	if (!IsUnsignedInteger(sSITime))
	{
		CReplyToCommand(client, "{yellow}SIControlScript{default}: {blue}<特感复活时间> {olive}invalid{default}.");
		return Plugin_Handled;
	}

	iSITime = StringToInt(sSITime);
	ServerCommand("l4d_infectedbots_spawn_time_max %d", iSITime);
	return Plugin_Handled;
}

bool IsUnsignedInteger(const char[] buffer)
{	
	int len = strlen(buffer);
	for (int i = 0; i < len; i++)
	{
		if (!IsCharNumeric(buffer[i]))
			return false;
	}
	return true;
}