#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <left4dhooks>

#define VSCRIPT_RET_ERROR 			-1
#define VSCRIPT_RET_SUCCESS 		0
#define VSCRIPT_RET_NOCHANGE 		1
#define VSCRIPT_RET_CHANGED 		2
#define VSCRIPT_RET_INIT 			3

#define DIRECTORSCRIPT_TYPE		"g_MapScript.LocalScript.DirectorOptions"
// #define DIRECTORSCRIPT_TYPE			"DirectorScript.MapScript.LocalScript.DirectorOptions"
//#define DIRECTORSCRIPT_TYPE		"DirectorScript.DirectorOptions"

#define DEF_LOCK_TEMP				0
#define DEF_LOCK_TEMP_FINAL			1

ConVar g_hDirectorSINum;
ConVar g_hDirectorSIRespawnInterval;
ConVar g_hDirectorSIFastRespawn;
ConVar g_hDirectorFlowTravel;

int g_iCurDirectorFlowTravel;
int g_iCurLockTempo;
int g_iCurShouldAllowSpecialsWithTank;
int g_iCurBuildUpMinInterval;
int g_iCurPreferredSpecialDirection;

bool g_bDirectorInfoPrinted;
bool g_bFinaleStarted;

enum PreferredDirectionType
{
	SPAWN_NO_PREFERENCE = -1,
	SPAWN_ANYWHERE,
	SPAWN_BEHIND_SURVIVORS,
	SPAWN_NEAR_IT_VICTIM,
	SPAWN_SPECIALS_IN_FRONT_OF_SURVIVORS,
	SPAWN_SPECIALS_ANYWHERE,
	SPAWN_FAR_AWAY_FROM_SURVIVORS,
	SPAWN_ABOVE_SURVIVORS,
	SPAWN_IN_FRONT_OF_SURVIVORS,
	SPAWN_VERSUS_FINALE_DISTANCE,
	SPAWN_LARGE_VOLUME,
	SPAWN_NEAR_POSITION,
};

char g_sPreferredDirectionTypeArray[][32] = 
{
	"NO_PREFERENCE",
	"ANYWHERE",
	"BEHIND_SURVIVORS",
	"NEAR_IT_VICTIM",
	"SPECIALS_IN_FRONT_OF_SURVIVORS",
	"SPECIALS_ANYWHERE",
	"FAR_AWAY_FROM_SURVIVORS",
	"ABOVE_SURVIVORS",
	"IN_FRONT_OF_SURVIVORS",
	"VERSUS_FINALE_DISTANCE",
	"LARGE_VOLUME",
	"NEAR_POSITION",
};

public Plugin myinfo =
{
	name = "SI Spawn Set Plugin For Vscript",
	author = "Cirno",
	description = "通过投票修改脚本刷特. 导演参数被改变时发出提示.",
	version = "1.0",
	url = ""
};

public void OnPluginStart()
{
	
	g_hDirectorSINum = CreateConVar("l4d_infectedbots_max_specials", "28", "特感数量", FCVAR_NONE, true, 0.0, true, 31.0);
	g_hDirectorSIRespawnInterval = CreateConVar("l4d_infectedbots_spawn_time_max", "15", "刷新间隔", FCVAR_NONE, true, 0.0);
	g_hDirectorSIFastRespawn = CreateConVar("l4d_infectedbots_fast_spawn", "0", "快速补位", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hDirectorFlowTravel = CreateConVar("l4d_infectedbots_relax_max_flow_travel", "0", "默认推进距离", FCVAR_NONE);
	// g_hDirectorFlowTravel = FindConVar("director_relax_max_flow_travel");

	RegAdminCmd("sm_si_num", Cmd_ChangeSINum, ADMFLAG_GENERIC, "Admin change the director option cm_MaxSpecials");
	RegAdminCmd("sm_si_time", Cmd_ChangeSITime, ADMFLAG_GENERIC, "Admin change the director option cm_SpecialRespawnInterval");
	RegAdminCmd("sm_si_fastrespawn", Cmd_ChangeSIFastSpawn, ADMFLAG_GENERIC, "Admin enable/disable script SI fast spawn");
	RegAdminCmd("sm_si_flowtravel", Cmd_ChangeFlowTravel, ADMFLAG_GENERIC, "Admin change the director option RelaxMaxFlowTravel. The upper bound of map script");
	// RegAdminCmd("sm_si_allowwithtank", Cmd_ChangeShouldAllowSpecialsWithTank, ADMFLAG_GENERIC, "Admin change the director option ShouldAllowSpecialsWithTank. ");

	// g_iCurDirectorFlowTravel = g_hDirectorFlowTravel.IntValue;

	HookConVarChange(g_hDirectorSINum, reload_script);
	HookConVarChange(g_hDirectorSIRespawnInterval, reload_script);
	HookConVarChange(g_hDirectorSIFastRespawn, reload_script);
	// HookConVarChange(g_hDirectorFlowTravel, OnConvarRelaxMaxFlowTravelChanged);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea, EventHookMode_PostNoCopy);

	HookEntityOutput("trigger_finale", "FinaleStart", OnFinaleStart);

	CreateTimer(1.0, CheckDirectorOptions, _, TIMER_REPEAT);
}

void OnFinaleStart(const char[] output, int caller, int activator, float delay)
{
	g_bFinaleStarted = true;
}

public void CPrintDirectorInfo()
{
	CPrintToChatAll("{yellow}SIControlScript{default}: {blue}当前特感最高同屏{yellow} %d {blue}特，复活时间{yellow} %d {blue}秒，地图推进距离{yellow} %d {blue}码, 特感快速补位{yellow}%s", 
		g_hDirectorSINum.IntValue, 
		g_hDirectorSIRespawnInterval.IntValue,
		g_iCurDirectorFlowTravel,
		g_hDirectorSIFastRespawn.IntValue ? "开启" : "关闭"
	);
}

public void CPrintDirectorInfo2()
{
	CPrintToChatAll("{olive}★{blue}当前阶段 {yellow}%s{blue}, Build up {yellow}%d{blue}秒, 刷新位置 {yellow}%s{blue}, 特感坦克同时存在 {yellow}%s", 
		g_iCurLockTempo ? "锁定" : "不锁定",
		g_iCurBuildUpMinInterval,
		g_sPreferredDirectionTypeArray[g_iCurPreferredSpecialDirection + 1],
		g_iCurShouldAllowSpecialsWithTank ? "True" : "False"
	);
}

/* or L4D2_GetScriptValueInt("RelaxMaxFlowTravel", 114514) */
/* 114514 is default value when search fail... */
public int GetIntMapScriptParam(const char [] sParamName, int &iOutput)
{
	char code[256];
	char sRetValue[8];
	FormatEx(code, sizeof(code), "%s.%s", DIRECTORSCRIPT_TYPE, sParamName);
	if (L4D2_GetVScriptOutput(code, sRetValue, sizeof(sRetValue)))
	{
		// PrintToChatAll("%s = %s", sParamName, sRetValue);

		/* hardcore use for LockTempo qwq */
		if (!strncmp(sRetValue, "true", 4)) 
			iOutput = 1;
		else if (!strncmp(sRetValue, "false", 5)) 
			iOutput = 0;
		else 
			iOutput = StringToInt(sRetValue);
		return VSCRIPT_RET_SUCCESS;
	}
	return VSCRIPT_RET_ERROR;
}

public int SetMapScriptParam(const char [] sParamName, int iParamValue)
{
	char code[256];
	FormatEx(code, sizeof(code), "%s.%s <- %d", DIRECTORSCRIPT_TYPE, sParamName, iParamValue);
	if (L4D2_ExecVScriptCode(code))
	{
		return VSCRIPT_RET_SUCCESS;
	}
	return VSCRIPT_RET_ERROR;
}

/* DirectorOptions Hook by a 1s timer */
public int CheckSetMapScriptParamChange(const char [] sParamName, int &iOldParamValue, int iDefParamValue)
{
	// directorOptions table exist
	int iNewParamValue;
	if (VSCRIPT_RET_SUCCESS == GetIntMapScriptParam(sParamName, iNewParamValue))
	{
		if (iOldParamValue == iNewParamValue) return VSCRIPT_RET_NOCHANGE;

		iOldParamValue = iNewParamValue;
		return VSCRIPT_RET_CHANGED;
	}

	// do not exist? create it!
	if (VSCRIPT_RET_SUCCESS == SetMapScriptParam(sParamName, iDefParamValue))
	{
		iOldParamValue = iDefParamValue;
		return VSCRIPT_RET_INIT;
	}

	return VSCRIPT_RET_ERROR;
}

public int DelMapScriptParam(const char [] sParamName)
{
	char code[256];
	FormatEx(code, sizeof(code), "%s.%s <- 0;delete %s.%s", DIRECTORSCRIPT_TYPE, sParamName, DIRECTORSCRIPT_TYPE, sParamName);
	if (L4D2_ExecVScriptCode(code))
		return VSCRIPT_RET_SUCCESS;
	
	return VSCRIPT_RET_ERROR;
}

public void Event_RoundStart(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	g_bDirectorInfoPrinted = false;
	g_bFinaleStarted = false;
	g_iCurLockTempo = 0;
}

public void Event_PlayerLeftSafeArea(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_bDirectorInfoPrinted)
	{
		CPrintDirectorInfo();
		CPrintDirectorInfo2();
		g_bDirectorInfoPrinted = true;
	}
}

/* 有没有更好的办法? 一次性执行多个参数获取? */
public Action CheckDirectorOptions(Handle timer)
{
	int iShouldPrint = 0;
	
	int iDefRelaxMaxFlowTravel = 3000;
	// int iDefLockTempo = L4D_IsMissionFinalMap();
	// int iDefLockTempo = false;
	int iDefBuildUpMinInterval = 15;
	int iDefPreferredSpecialDirection = -1;
	int iDefShouldAllowSpecialsWithTank = 0;

	int bRelaxMaxFlowTravelChanged = 0;
	int bLockTempoChanged = 0;
	int bBuildUpMinIntervalChanged = 0;
	int bPreferredSpecialDirectionChanged = 0;
	int bShouldAllowSpecialsWithTankChanged = 0;

	/* Will return INIT every round start! */
	if ( VSCRIPT_RET_CHANGED <= CheckSetMapScriptParamChange("RelaxMaxFlowTravel", g_iCurDirectorFlowTravel, iDefRelaxMaxFlowTravel)) 
	{		
		bRelaxMaxFlowTravelChanged = 1;
	}

	/* 自己设置的优先级更高 */
	if (g_hDirectorFlowTravel.IntValue > 0 && g_iCurDirectorFlowTravel != g_hDirectorFlowTravel.IntValue)
	{
		SetMapScriptParam("RelaxMaxFlowTravel", g_hDirectorFlowTravel.IntValue);
		g_iCurDirectorFlowTravel = g_hDirectorFlowTravel.IntValue;
		bRelaxMaxFlowTravelChanged = 1;
	}

	if (!L4D_IsMissionFinalMap())
	{
		if ( VSCRIPT_RET_CHANGED <= CheckSetMapScriptParamChange("LockTempo", g_iCurLockTempo, 0))
		{
			bLockTempoChanged = 1;
		}
	}
	else if (g_bFinaleStarted)
	{
		if ( VSCRIPT_RET_CHANGED <= CheckSetMapScriptParamChange("LockTempo", g_iCurLockTempo, 1))
		{
			bLockTempoChanged = 1;
		}
	}

	if ( VSCRIPT_RET_CHANGED <= CheckSetMapScriptParamChange("BuildUpMinInterval", g_iCurBuildUpMinInterval, iDefBuildUpMinInterval))
	{
		bBuildUpMinIntervalChanged = 1;
	}

	// PreferredSpecialDirection = 1
	if ( VSCRIPT_RET_CHANGED <= CheckSetMapScriptParamChange("PreferredSpecialDirection", g_iCurPreferredSpecialDirection, iDefPreferredSpecialDirection))
	{
		bPreferredSpecialDirectionChanged = 1;
	}

	if ( VSCRIPT_RET_CHANGED <= CheckSetMapScriptParamChange("ShouldAllowSpecialsWithTank", g_iCurShouldAllowSpecialsWithTank, iDefShouldAllowSpecialsWithTank))
	{
		bShouldAllowSpecialsWithTankChanged = 1;
	}
	
	iShouldPrint = bRelaxMaxFlowTravelChanged | bLockTempoChanged | bBuildUpMinIntervalChanged | bPreferredSpecialDirectionChanged | bShouldAllowSpecialsWithTankChanged;
	if (iShouldPrint)
	{
		CPrintToChatAll("{olive}★{blue}推进距离设置为%s%d{blue}码, 阶段%s%s{blue}, Build up%s%d{blue}秒, 刷新位置%s%s{blue}, 特感坦克同时存在%s%s", 
			bRelaxMaxFlowTravelChanged ? "{yellow}" : "",
			g_iCurDirectorFlowTravel,
			
			bLockTempoChanged ? "{yellow}" : "",
			g_iCurLockTempo ? "锁定" : "不锁定",
			
			bBuildUpMinIntervalChanged ? "{yellow}" : "",
			g_iCurBuildUpMinInterval,
				
			bPreferredSpecialDirectionChanged ? "{yellow}" : "",
			g_sPreferredDirectionTypeArray[g_iCurPreferredSpecialDirection + 1],
			
			bShouldAllowSpecialsWithTankChanged ? "{yellow}" : "",
			g_iCurShouldAllowSpecialsWithTank ? "True" : "False"
		);
		PrintHintTextToAll("★ 推进距离%d码, 阶段%s ★", g_iCurDirectorFlowTravel, (g_iCurLockTempo ? "锁定" : "不锁定"));
	}
	return Plugin_Continue;
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
	ServerCommand("l4d_infectedbots_relax_max_flow_travel %d", iSIFlowTravel);
	return Plugin_Handled;
}

// public Action Cmd_ChangeShouldAllowSpecialsWithTank(int client, int args)
// {

// }

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