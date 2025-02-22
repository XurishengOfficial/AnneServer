#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <builtinvotes>
#include <multicolors>
#undef REQUIRE_PLUGIN
#include <confogl>
#include <colors>

#define TEAM_SPECTATE		1
#define MATCHMODES_PATH		"configs/votemode.txt"

#define FIRSTMENUITEM_NUM_MAX 33

Handle
	g_hVote = null;

KeyValues
	g_hModesKV = null;

ConVar g_hGameMode;

ConVar g_hHostName = null;
ConVar g_hTrainingMode = null;
ConVar g_hSpecialsNum = null;
ConVar g_hSpecialsSpawnTime = null;
// ConVar h_AggresiveSpecialsEnable = null;
// ConVar h_SpecialsShouldAssaultEnable = null;

char g_HostNameOrigin[128];

char
	g_s1stMenuItemPick[64],
	g_sExecCmd[64];

int g_i1stMenuItemNum = 0;
int g_i2ndMenuItemNum = 0;

int g_i1stMenuItemPick = -1;
int g_i2ndMenuItemPick = -1;

int g_aMenuItemPick[FIRSTMENUITEM_NUM_MAX];

int g_iLoadInitialConfig = 0;

public Plugin myinfo =
{
	name = "Vote Modified by Azuki",
	author = "vintik, Sir, Azuki(Cirno)",
	description = "!votemode - Change Server Configurable Settings",
	version = "1.2",
	url = "https://github.com/L4D-Community/L4D2-Competitive-Framework"
};

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErrMax)
{
	EngineVersion iEngine = GetEngineVersion();
	if (iEngine != Engine_Left4Dead2) {
		strcopy(sError, iErrMax, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	char sBuffer[PLATFORM_MAX_PATH ];
	g_hModesKV = new KeyValues("VoteMode");
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), MATCHMODES_PATH);

	if (!g_hModesKV.ImportFromFile(sBuffer)) {
		SetFailState("Couldn't load configs/votemode.txt!");
	}

	g_hGameMode = FindConVar("mp_gamemode");
	g_hGameMode.AddChangeHook(OnGameModeChanged);
	g_hHostName = FindConVar("hostname");

	RegConsoleCmd("sm_votemode", VoteRequest);

	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("mission_lost", Event_MissionLost, EventHookMode_PostNoCopy);
	
	GetConVarString(g_hHostName, g_HostNameOrigin, sizeof(g_HostNameOrigin));
	CreateTimer(1.0, Timer_SetHostName, _, TIMER_REPEAT);
}

void LoadGameModeConfig()
{
	char sGameMode[64];
	g_hGameMode.GetString(sGameMode, sizeof(sGameMode));
	ServerCommand("exec vote/Gamemode/%s.cfg", sGameMode);
}

void OnGameModeChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	LoadGameModeConfig();
	for (int i = 1; i < FIRSTMENUITEM_NUM_MAX; ++i)
	{
		g_aMenuItemPick[i] = 0;
	}
	ServerCommand("sm_restartmap");
}

void Event_MissionLost(Event event, const char[] name, bool dontBroadcast) {
	CPrintToChatAll("{blue}[{olive}!{blue}] 可通过命令{yellow}!votemode{blue}自定义特感数量复活时间等参数.");
}

public void OnConfigsExecuted()
{
	if (!g_iLoadInitialConfig)
	{
		g_iLoadInitialConfig = 1;
		LoadGameModeConfig();
		// 用于Server首次启动时执行对应mode cfg 首个玩家加入后会自动换图
		// ServerCommand("sm_restartmap");
		return;
	}
	for (int i = 1; i < FIRSTMENUITEM_NUM_MAX; ++i)
	{
		if (g_aMenuItemPick[i] > 0)
			LogMessage("Last Picked: %d, %d\n", i, g_aMenuItemPick[i]);
	}

	/*
		"VoteMode"
		{
			"特感数量"
			{
				"8特模式"
				{
					"cmd" "exec vote/SI_num/8.cfg"
				}
			}
		}
	*/

	// reset to root node VoteMode
	g_hModesKV.Rewind();

	// GotoFirstSubKey 进入下个Section 可反复调用
	// 进入 <特感数量>
	if (!g_hModesKV.GotoFirstSubKey()) return;
	for (int i = 1; i <= g_i1stMenuItemNum; ++i)
	{
		int j = g_aMenuItemPick[i];
		if (j > 0)
		{
			// 遍历二级Section
			// Current key is a regular key, or an empty section.
			// 如果Goto失败会停留在原地 <特感数量> 不需要go back
			if (!g_hModesKV.GotoFirstSubKey()) continue;

			// 成功则进入到 <8特模式>
			char s2ndItemName[64], sCmd[64], iRepeatable;
			while(--j && g_hModesKV.GotoNextKey(false))
			{
				// move. if j = 1, last 2nd pick idx is (j - 1 = 0), stay here.
			}
			
			g_hModesKV.GetSectionName(s2ndItemName, sizeof(s2ndItemName));
			g_hModesKV.GetString("cmd", sCmd, sizeof(sCmd));
			/* 默认菜单选择的均需要重复 */
			iRepeatable = g_hModesKV.GetNum("repeatable", 1);

			LogMessage("===== Last Picked: %s, cmd = %s, repeatable = %d", s2ndItemName, sCmd, iRepeatable);

			// GotoNextKey遍历不会在traverse stack上保存, 此时go back到上一级Section <特感数量>
			g_hModesKV.GoBack();
			// g_aMenuItemPick[i] = 0;
			if (iRepeatable)
				ServerCommand(sCmd);
		}
		g_hModesKV.GotoNextKey(false);
	}
}

public Action Timer_SetHostName(Handle timer)
{
	char hostName[128];
	char sGameMode[64];
	g_hGameMode.GetString(sGameMode, sizeof(sGameMode));
	if (StrEqual(sGameMode, "coop"))
	{
		Format(hostName, sizeof(hostName), "%s [战役]", g_HostNameOrigin);
		return Plugin_Continue;
	}

	if (StrEqual(sGameMode, "realism"))
	{
		Format(hostName, sizeof(hostName), "%s [写实]", g_HostNameOrigin);
		return Plugin_Continue;
	}

	if (StrEqual(sGameMode, "community1"))
	{
		Format(hostName, sizeof(hostName), "%s [速递]", g_HostNameOrigin);
	}

	if (StrEqual(sGameMode, "community5"))
	{
		Format(hostName, sizeof(hostName), "%s [死门]", g_HostNameOrigin);
	}

	if (StrEqual(sGameMode, "mutation4"))
	{
		Format(hostName, sizeof(hostName), "%s [绝境]", g_HostNameOrigin);
	}

	// 防止因为插件加载顺序获取不到
	if (!g_hSpecialsNum)
		g_hSpecialsNum = FindConVar("l4d_infectedbots_max_specials");
	
	if (!g_hSpecialsSpawnTime)
		g_hSpecialsSpawnTime = FindConVar("l4d_infectedbots_spawn_time_max");

	if (g_hSpecialsNum && g_hSpecialsSpawnTime)
		Format(hostName, sizeof(hostName), "%s [%d特%d秒]", hostName, GetConVarInt(g_hSpecialsNum), GetConVarInt(g_hSpecialsSpawnTime));

	if (!g_hTrainingMode)
		g_hTrainingMode = FindConVar("auto_revive_enable");
	
	if (g_hTrainingMode && g_hTrainingMode.BoolValue)
		Format(hostName, sizeof(hostName), "%s[训练模式]", hostName);

	g_hHostName.SetString(hostName);
	return Plugin_Continue;
}

public Action VoteRequest(int iClient, int iArgs)
{
	if (iClient == 0) {
		return Plugin_Handled;
	}

	VoteModeMenu(iClient);
	return Plugin_Handled;
}

void VoteModeMenu(int iClient)
{
	Menu hMenu = new Menu(VoteModeMenuHandler);
	hMenu.SetTitle("=== * 模式设置 * ===");
	g_i1stMenuItemNum = 0;

	g_i1stMenuItemPick = -1;
	g_i2ndMenuItemPick = -1;
	// PrintToChatAll("[VoteModeMenu] Reset to -1");

	char sBuffer[64];
	g_hModesKV.Rewind();

	if (g_hModesKV.GotoFirstSubKey() && ++g_i1stMenuItemNum) {
		do {
			g_hModesKV.GetSectionName(sBuffer, sizeof(sBuffer));	// 获取当前位置section的内容
			hMenu.AddItem(sBuffer, sBuffer);
		} while (g_hModesKV.GotoNextKey(false) && ++g_i1stMenuItemNum);	// 遍历该层级下所有子项
	}

	hMenu.Display(iClient, 30);
	// PrintToChatAll("First Menu has %d items\n", g_i1stMenuItemNum);
}

public int VoteModeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
		// PrintToChatAll("VoteModeMenuHandler MenuAction_End");

	} 
	else if (action == MenuAction_Cancel) {
		// PrintToChatAll("VoteModeMenuHandler MenuAction_Cancel");
	} 
	else if (action == MenuAction_Select) {
		char sFirstMenuTitile[64], sExecCmd[64], s2ndPickItem[64];
		// 在次数reset防止仅打开主菜单就清空子菜单计数, 导致onconfigsexec错误
		g_i2ndMenuItemNum = 0;

		menu.GetItem(param2, g_s1stMenuItemPick, sizeof(g_s1stMenuItemPick));

		// 记录主菜单选项
		g_i1stMenuItemPick = param2;
		g_hModesKV.Rewind();

		if (g_hModesKV.JumpToKey(g_s1stMenuItemPick) && g_hModesKV.GotoFirstSubKey() && ++g_i2ndMenuItemNum) {
			Menu hMenu = new Menu(ConfigsMenuHandler);

			FormatEx(sFirstMenuTitile, sizeof(sFirstMenuTitile), "== ** %s ** ==", g_s1stMenuItemPick);	// ZoneMod Configs
			hMenu.SetTitle(sFirstMenuTitile);

			do {
				g_hModesKV.GetSectionName(s2ndPickItem, sizeof(s2ndPickItem));
				g_hModesKV.GetString("cmd", sExecCmd, sizeof(sExecCmd));

				hMenu.AddItem(sExecCmd, s2ndPickItem);
			} while (g_hModesKV.GotoNextKey() && ++g_i2ndMenuItemNum);

			hMenu.Display(param1, 20);
			// PrintToChatAll("Second Menu has %d items\n", g_i2ndMenuItemNum);

		} else {
			CPrintToChat(param1, "{blue}[{default}VoteMode{blue}] {default}未能找到选项对应的CFG文件.");
			VoteModeMenu(param1);
		}
	}

	return 0;
}

public int ConfigsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
		// PrintToChatAll("ConfigsMenuHandler MenuAction_End");

	} 
	else if (action == MenuAction_Cancel) {
		// PrintToChatAll("ConfigsMenuHandler MenuAction_Cancel");
	} 
	else if (action == MenuAction_Select) {
		char s2ndItemPick[64];
		menu.GetItem(param2, g_sExecCmd, sizeof(g_sExecCmd), _, s2ndItemPick, sizeof(s2ndItemPick));
		// 记录次级菜单选项
		g_i2ndMenuItemPick = param2;

		// PrintToChatAll("Pick: %s-%s, exec cmd = %s\n", s2ndItemPick, g_sExecCmd);
		Format(g_s1stMenuItemPick, sizeof(g_s1stMenuItemPick), "%s: %s", g_s1stMenuItemPick, s2ndItemPick);
		// g_aMenuItemPick[g_i1stMenuItemPick + 1] = g_i2ndMenuItemPick + 1;
		// PrintToChatAll("Pick 1st = %d, 2nd = %d, %s, cmd = %s", g_i1stMenuItemPick, g_i2ndMenuItemPick, g_s1stMenuItemPick, g_sExecCmd);

		if (GetUserFlagBits(param1) & ADMFLAG_ROOT)
		{
			ServerCommand("%s", g_sExecCmd); 
			g_aMenuItemPick[g_i1stMenuItemPick + 1] = g_i2ndMenuItemPick + 1;
			char adminName[64];
			GetClientName(param1, adminName, sizeof(adminName));
			CPrintToChatAll("{yellow}VoteMode{default}: {blue}管理员 {olive}%s {blue}已直接执行配置{default}: {olive}%s.", adminName, g_s1stMenuItemPick);
			return 0;
		}

		if (StartMatchVote(param1, g_s1stMenuItemPick)) {
			FakeClientCommand(param1, "Vote Yes");
		} else {
			VoteModeMenu(param1);
			PrintToChatAll("StartMatchVote FAILED...\n");
		}
	}

	return 0;
}

bool StartMatchVote(int iClient, const char[] sItemTitle)
{
	if (GetClientTeam(iClient) <= TEAM_SPECTATE) {
		CPrintToChat(iClient, "{blue}[{default}Match{blue}] {default}旁观者不允许发起投票.");
		return false;
	}

	if (!IsBuiltinVoteInProgress()) {
		int iNumPlayers = 0;
		int[] iPlayers = new int[MaxClients];

		//list of non-spectators players
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) <= TEAM_SPECTATE) {
				continue;
			}

			iPlayers[iNumPlayers++] = i;
		}

		g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(g_hVote, sItemTitle);
		SetBuiltinVoteInitiator(g_hVote, iClient);
		SetBuiltinVoteResultCallback(g_hVote, MatchVoteResultHandler);
		DisplayBuiltinVote(g_hVote, iPlayers, iNumPlayers, 20);

		return true;
	}

	CPrintToChat(iClient, "{blue}[{default}Match{blue}] {default}投票正在进行中....");
	return false;
}

public void VoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action) {
		case BuiltinVoteAction_End: {
			delete vote;
			g_hVote = null;
		}
		case BuiltinVoteAction_Cancel: {
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
		}
	}
}

public void MatchVoteResultHandler(Handle vote, int num_votes, int num_clients, \
										const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				DisplayBuiltinVotePass(vote, g_s1stMenuItemPick);
				// PrintToChatAll("%s", g_sExecCmd);
				ServerCommand("%s", g_sExecCmd); 
				g_aMenuItemPick[g_i1stMenuItemPick + 1] = g_i2ndMenuItemPick + 1;
				// PrintToChatAll("Result: Pick 1st = %d, 2nd = %d, %s, cmd = %s", g_i1stMenuItemPick, g_i2ndMenuItemPick, g_s1stMenuItemPick, g_sExecCmd);
				// LogMessage("Vote Success...Picked: %d, %d\n", g_i1stMenuItemPick + 1, g_aMenuItemPick[g_i1stMenuItemPick + 1]);
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
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
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if( !client || (IsClientConnected(client) && !IsClientInGame(client))) return;
	if( client && !IsFakeClient(client) && !checkrealplayerinSV(client))
	{
		LoadGameModeConfig();
		for (int i = 1; i < FIRSTMENUITEM_NUM_MAX; ++i)
		{
			g_aMenuItemPick[i] = 0;
		}
	}
}