#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <left4dhooks>

#define VSCRIPT_RET_ERROR 		-1
#define VSCRIPT_RET_SUCCESS 	0
#define VSCRIPT_RET_NOCHANGE 	-2

ConVar g_hDirectorSINum;
ConVar g_hDirectorSIRespawnInterval;
ConVar g_hDirectorSIFastRespawn;
ConVar g_hDirectorFlowTravel;

int g_iCurDirectorFlowTravel;
bool g_bDirectorInfoPrinted;
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
	g_hDirectorSIFastRespawn = CreateConVar("l4d_infectedbots_fast_spawn", "0", "快速补位", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hDirectorFlowTravel = FindConVar("director_relax_max_flow_travel");

	RegAdminCmd("sm_si_num", Cmd_ChangeSINum, ADMFLAG_GENERIC, "Admin change the director option cm_MaxSpecials");
	RegAdminCmd("sm_si_time", Cmd_ChangeSITime, ADMFLAG_GENERIC, "Admin change the director option cm_SpecialRespawnInterval");
	RegAdminCmd("sm_si_fastrespawn", Cmd_ChangeSIFastSpawn, ADMFLAG_GENERIC, "Admin enable/disable script SI fast spawn");
	RegAdminCmd("sm_si_flowtravel", Cmd_ChangeFlowTravel, ADMFLAG_GENERIC, "Admin change the director option RelaxMaxFlowTravel.May overwritten by map script.");
	// RegAdminCmd("sm_si_time", Cmd_ChangeSITime, ADMFLAG_GENERIC, "Change the script SI spawn time");

	g_iCurDirectorFlowTravel = g_hDirectorFlowTravel.IntValue;

	HookConVarChange(g_hDirectorSINum, reload_script);
	HookConVarChange(g_hDirectorSIRespawnInterval, reload_script);
	HookConVarChange(g_hDirectorSIFastRespawn, reload_script);
	HookConVarChange(g_hDirectorFlowTravel, reload_script);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_left_start_area", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);


	CreateTimer(1.0, CheckDirectorOptions, _, TIMER_REPEAT);
}

public void CPrintDirectorInfo()
{
	CPrintToChatAll("{yellow}SIControlScript{default}: {blue}当前特感最高同屏{yellow} %d {blue}特，复活时间{yellow} %d {blue}秒，地图推进距离{yellow} %d {blue}码, 特感快速补位{yellow}%s", 
		g_hDirectorSINum.IntValue, 
		g_hDirectorSIRespawnInterval.IntValue,
		GetMapScriptRelaxMaxFlowTravel(),
		g_hDirectorSIFastRespawn.IntValue ? "开启" : "关闭"
	);
}

/* 地图的FlowTravel和默认的FlowTravel(director_relax_max_flow_travel)是覆盖关系, 后赋值的生效 */

public int GetMapScriptRelaxMaxFlowTravel()
{
	char code[256];
	char sMapMaxFlow[8];
	FormatEx(code, sizeof(code), "DirectorScript.MapScript.LocalScript.DirectorOptions.RelaxMaxFlowTravel");
	if (L4D2_GetVScriptOutput(code, sMapMaxFlow, sizeof(sMapMaxFlow)))
	{
		return StringToInt(sMapMaxFlow);
	}
	return VSCRIPT_RET_ERROR;
}

public int SetMapScriptRelaxMaxFlowTravel(int iFlow)
{
	char code[256];
	FormatEx(code, sizeof(code), "DirectorScript.MapScript.LocalScript.DirectorOptions.RelaxMaxFlowTravel <- %d", iFlow);
	if (L4D2_ExecVScriptCode(code))
	{
		return VSCRIPT_RET_SUCCESS;
	}
	return VSCRIPT_RET_ERROR;
}

public void Event_RoundStart(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	g_bDirectorInfoPrinted = false;
}

public void Event_PlayerLeftStartArea(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_bDirectorInfoPrinted)
	{
		CPrintDirectorInfo();
		g_bDirectorInfoPrinted = true;
	}
}

public Action CheckDirectorOptions(Handle timer)
{
	// char code[256];
	// char sMapMaxFlow[8];

	// 一些用于记录VScript的注释
	// FormatEx(code, sizeof(code), "Director.GetMapName()");
	// FormatEx(code, sizeof(code), "ret <- Director.GetMapName(); <RETURN>ret</RETURN>");
	// FormatEx(code, sizeof(code), "DirectorScript.MapScript.LocalScript.DirectorOptions.RelaxMaxFlowTravel");

	// DirectorScript.MapScript.LocalScript.DirectorOptions.RelaxMaxFlowTravel
	// FormatEx(code, sizeof(code), "ret <- Director.GetMapNumber(); <RETURN>ret</RETURN>");
	// FormatEx(code, sizeof(code), "local player = null; while(player = Entities.FindByClassname(player, \"player\")) { if(player.IsSurvivor()) { <RETURN>player.GetName()</RETURN> } }");
	
	int iMapMaxFlow = -1;
	if (VSCRIPT_RET_ERROR != (iMapMaxFlow = GetMapScriptRelaxMaxFlowTravel()))
	{
		if (iMapMaxFlow != g_iCurDirectorFlowTravel)
		{
			g_iCurDirectorFlowTravel = iMapMaxFlow;
			CPrintToChatAll("{yellow}SIControlScript{default}: {blue}当前地图推进距离设置为 {yellow} %d {blue}码.", g_iCurDirectorFlowTravel);
		}
	}
	else
	{
		/* 更换地图后/首次运行时, 若地图未设置则会重新变回默认. DirectorOptions Table中不会有RelaxMaxFlowTravel键值对 => 写入!!! */
		g_iCurDirectorFlowTravel = g_hDirectorFlowTravel.IntValue;

		if (VSCRIPT_RET_SUCCESS == SetMapScriptRelaxMaxFlowTravel(g_iCurDirectorFlowTravel))
		{
			/* 这个Print玩家应该看不到 */
			CPrintToChatAll("{yellow}SIControlScript{default}: {blue}当前地图默认推进距离设置为 {yellow} %d {blue}码.", g_iCurDirectorFlowTravel);
		}
	}
	return Plugin_Continue;
}

public reload_script(Handle convar, char[] oldValue, char[] newValue)
{
	/* 更新部分参数 */
	g_iCurDirectorFlowTravel = g_hDirectorFlowTravel.IntValue;

	ConVar gamemode = FindConVar("mp_gamemode");
	char modestr[64];
	gamemode.GetString(modestr, 64);
	char file[64];
	Format(file, 64, "%s.nut", modestr);
	CheatCommand("script_reload_code", file);
	PrintToServer("Script %s.nut Reloaded", modestr);
	CPrintDirectorInfo();
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
		CPrintDirectorInfo();
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
		CPrintDirectorInfo();
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

public Action Cmd_ChangeSIFastSpawn(int client, int args)
{
	if (args < 1)
	{
		CPrintToChatAll("{yellow}SIControlScript{default}: {blue}sm_si_fastrespawn < 0 / 1 >");
		CPrintDirectorInfo();
		return Plugin_Handled;	
	}
	
	char sSIFastSpawnEnable[8];
	int iSIFastSpawnEnable = 0;
	
	GetCmdArg(1, sSIFastSpawnEnable, sizeof(sSIFastSpawnEnable));
	
	// Make sure the arg is unsigned int
	if (!IsUnsignedInteger(sSIFastSpawnEnable))
	{
		CReplyToCommand(client, "{yellow}SIControlScript{default}: {blue}<特感快速补位> {olive}invalid{default}.");
		return Plugin_Handled;
	}

	iSIFastSpawnEnable = StringToInt(sSIFastSpawnEnable);
	ServerCommand("l4d_infectedbots_fast_spawn %d", iSIFastSpawnEnable);
	return Plugin_Handled;
}

public Action Cmd_ChangeFlowTravel(int client, int args)
{
	if (args < 1)
	{
		CPrintToChatAll("{yellow}SIControlScript{default}: {blue}sm_si_flowtravel <推进码数>");
		CPrintDirectorInfo();
		return Plugin_Handled;	
	}
	
	char sSIFlowTravel[8];
	int iSIFlowTravel = 3000;
	
	GetCmdArg(1, sSIFlowTravel, sizeof(sSIFlowTravel));
	
	// Make sure the arg is unsigned int
	if (!IsUnsignedInteger(sSIFlowTravel))
	{
		CReplyToCommand(client, "{yellow}SIControlScript{default}: {blue}<推进距离> {olive}invalid{default}.");
		return Plugin_Handled;
	}

	iSIFlowTravel = StringToInt(sSIFlowTravel);
	ServerCommand("sm_cvar director_relax_max_flow_travel %d", iSIFlowTravel);
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