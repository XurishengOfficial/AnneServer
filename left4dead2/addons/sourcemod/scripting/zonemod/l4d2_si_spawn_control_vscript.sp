#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <left4dhooks>

#define VSCRIPT_RET_ERROR 			-1
#define VSCRIPT_RET_SUCCESS 		0
#define VSCRIPT_RET_NOCHANGE 		1
#define VSCRIPT_RET_CHANGED 		2
#define VSCRIPT_RET_INIT 			3

// #define DIRECTORSCRIPT_TYPE		"g_MapScript.LocalScript.DirectorOptions"
#define DIRECTORSCRIPT_TYPE			"DirectorScript.MapScript.LocalScript.DirectorOptions"
// #define DIRECTORSCRIPT_TYPE		"DirectorScript.DirectorOptions"

#define DEF_LOCK_TEMP					0
#define DEF_LOCK_TEMP_FINAL				1
#define DEF_BUILD_UP_MIN_INTERRVAL		15
#define DEF_PREFERRED_SPECIAL_DIRECTION	-1 /* SPAWN_NO_PREFERENCE */


ConVar g_hDirectorSINum;
ConVar g_hDirectorSIRespawnInterval;
ConVar g_hDirectorSIFastRespawn;
ConVar g_hDirectorFlowTravel;

Handle g_hCheckTimer = null;

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

bool g_bDirectorInfoPrinted;
int g_iCurDirectorFlowTravel;
int g_iCurLockTempo;
int g_iCurBuildUpMinInterval;
int g_iCurPreferredSpecialDirection;

public Plugin myinfo =
{
	name = "SI Spawn Set Plugin For Vscript",
	author = "Cirno",
	description = "通过投票修改脚本刷特. 导演参数被改变时发出提示.",
	version = "1.0",
	url = ""
};

void CheckSetDefDirectorOptions()
{
	int tmp;
	g_iCurDirectorFlowTravel = g_hDirectorFlowTravel.IntValue;
	if (VSCRIPT_RET_ERROR == GetIntMapScriptParam("RelaxMaxFlowTravel", tmp))
		SetMapScriptParam("RelaxMaxFlowTravel", g_iCurDirectorFlowTravel);

	if (VSCRIPT_RET_ERROR == GetIntMapScriptParam("LockTempo", tmp))
		SetMapScriptParam("LockTempo", DEF_LOCK_TEMP);	/* in finale should be locked */

	if (VSCRIPT_RET_ERROR == GetIntMapScriptParam("BuildUpMinInterval", tmp))	
		SetMapScriptParam("BuildUpMinInterval", DEF_BUILD_UP_MIN_INTERRVAL);

	if (VSCRIPT_RET_ERROR == GetIntMapScriptParam("PreferredSpecialDirection", tmp))
		SetMapScriptParam("PreferredSpecialDirection", DEF_PREFERRED_SPECIAL_DIRECTION);
}

public void OnPluginStart()
{
	
	g_hDirectorSINum = CreateConVar("l4d_infectedbots_max_specials", "28", "特感数量", FCVAR_NONE, true, 0.0, true, 31.0);
	g_hDirectorSIRespawnInterval = CreateConVar("l4d_infectedbots_spawn_time_max", "15", "刷新间隔", FCVAR_NONE, true, 0.0);
	g_hDirectorSIFastRespawn = CreateConVar("l4d_infectedbots_fast_spawn", "0", "快速补位", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hDirectorFlowTravel = FindConVar("director_relax_max_flow_travel");

	RegAdminCmd("sm_si_num", Cmd_ChangeSINum, ADMFLAG_GENERIC, "Admin change the director option cm_MaxSpecials");
	RegAdminCmd("sm_si_time", Cmd_ChangeSITime, ADMFLAG_GENERIC, "Admin change the director option cm_SpecialRespawnInterval");
	RegAdminCmd("sm_si_fastrespawn", Cmd_ChangeSIFastSpawn, ADMFLAG_GENERIC, "Admin enable/disable script SI fast spawn");
	RegAdminCmd("sm_si_flowtravel", Cmd_ChangeFlowTravel, ADMFLAG_GENERIC, "Admin change the director option RelaxMaxFlowTravel. The upper bound of map script");

	g_iCurDirectorFlowTravel = g_hDirectorFlowTravel.IntValue;

	HookConVarChange(g_hDirectorSINum, reload_script);
	HookConVarChange(g_hDirectorSIRespawnInterval, reload_script);
	HookConVarChange(g_hDirectorSIFastRespawn, reload_script);
	HookConVarChange(g_hDirectorFlowTravel, OnConvarRelaxMaxFlowTravelChanged);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea, EventHookMode_PostNoCopy);
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
	CPrintToChatAll("{olive}★{blue}当前章节阶段{yellow}%s{blue}, Build up至少{yellow}%d{blue}秒, 刷新位置{yellow}%s", 
		g_iCurLockTempo ? "锁定" : "不锁定",
		g_iCurBuildUpMinInterval,
		g_sPreferredDirectionTypeArray[g_iCurPreferredSpecialDirection + 1]
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

		/* hardcode use for LockTempo qwq */
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
public int CheckMapScriptParamChange(const char [] sParamName, int &iOldParamValue)
{
	// directorOptions table exist
	int iNewParamValue;
	if (VSCRIPT_RET_SUCCESS == GetIntMapScriptParam(sParamName, iNewParamValue))
	{
		if (iOldParamValue == iNewParamValue) return VSCRIPT_RET_NOCHANGE;

		iOldParamValue = iNewParamValue;
		return VSCRIPT_RET_CHANGED;
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
}

public void Event_PlayerLeftSafeArea(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	CheckSetDefDirectorOptions();

	if (g_hCheckTimer != null)
		KillTimer(g_hCheckTimer);
	g_hCheckTimer = CreateTimer(3.0, CheckDirectorOptions, _, TIMER_REPEAT);

	if (!g_bDirectorInfoPrinted)
	{
		CPrintDirectorInfo();
		g_bDirectorInfoPrinted = true;
	}
}

/* 有没有更好的办法? 一次性执行多个参数获取? */
public Action CheckDirectorOptions(Handle timer)
{
	int iShouldPrint = 0;

	if ( VSCRIPT_RET_CHANGED == CheckMapScriptParamChange("RelaxMaxFlowTravel", g_iCurDirectorFlowTravel))
	{
		/* 推进码数取最小 */
		if (g_iCurDirectorFlowTravel > g_hDirectorFlowTravel.IntValue)
		{
			g_iCurDirectorFlowTravel = g_hDirectorFlowTravel.IntValue;
			SetMapScriptParam("RelaxMaxFlowTravel", g_iCurDirectorFlowTravel);
		}
		iShouldPrint = 1;
	}

	if ( VSCRIPT_RET_CHANGED == CheckMapScriptParamChange("LockTempo", g_iCurLockTempo))
	{
		iShouldPrint = 1;
	}

	if ( VSCRIPT_RET_CHANGED == CheckMapScriptParamChange("BuildUpMinInterval", g_iCurBuildUpMinInterval))
	{
		iShouldPrint = 1;
	}

	// PreferredSpecialDirection = 1
	if ( VSCRIPT_RET_CHANGED == CheckMapScriptParamChange("PreferredSpecialDirection", g_iCurPreferredSpecialDirection))
	{
		iShouldPrint = 1;
	}
	
	if (iShouldPrint)
	{
		CPrintToChatAll("{olive}★{blue}当前地图默认推进距离设置为{yellow}%d{blue}码, 阶段{yellow}%s{blue}, Build up至少{yellow}%d{blue}秒, 刷新位置{yellow}%s", 
			g_iCurDirectorFlowTravel,
			g_iCurLockTempo ? "锁定" : "不锁定",
			g_iCurBuildUpMinInterval,
			g_sPreferredDirectionTypeArray[g_iCurPreferredSpecialDirection + 1]
		);
	}
	return Plugin_Continue;
}

public OnConvarRelaxMaxFlowTravelChanged(Handle convar, char[] oldValue, char[] newValue)
{
	g_iCurDirectorFlowTravel = g_hDirectorFlowTravel.IntValue;
	SetMapScriptParam("RelaxMaxFlowTravel", g_iCurDirectorFlowTravel);
	CPrintDirectorInfo();
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