/**
 * vim: set ts=4 :
 * =============================================================================
 * NativeVotes Vote Tester
 * Copyright (C) 2011-2013 Ross Bemrose (Powerlord).  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

#include <sourcemod>
#include <nativevotes>
#include <sdktools>

#define VERSION "1.0"
#define TEAM_SURVIVORS 		2

char VoteMenuItems[MAXPLAYERS+1][512];

static ConVar h_TrainingMode;


public Plugin:myinfo = 
{
	name = "NativeVotes Vote Tester",
	author = "Powerlord",
	description = "Various NativeVotes vote type tests",
	version = "1.0",
	url = "https://forums.alliedmods.net/showthread.php?t=208008"
}

public OnPluginStart()
{
	CreateConVar("nativevotestest_version", VERSION, "NativeVotes Vote Tester version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	// RegAdminCmd("voteyesno", Cmd_TestYesNo, ADMFLAG_VOTE, "Test Yes/No votes");
	// RegAdminCmd("votemult", Cmd_TestMult, ADMFLAG_VOTE, "Test Multiple Choice votes");
	// RegAdminCmd("voteyesnocustom", Cmd_ChangeGameMode, ADMFLAG_VOTE, "Test Multiple Choice vote with Custom Display text");
	// RegAdminCmd("votemultcustom", Cmd_TestMultCustom, ADMFLAG_VOTE, "Test Multiple Choice vote with Custom Display text");
	RegConsoleCmd("sm_votemode", VoteModeRequest);

	h_TrainingMode = FindConVar("auto_revive_enable");
}

public Action VoteModeRequest(int client, int args)
{
	if (!client)
	{
		return Plugin_Handled;
	}
	new Handle:menu = CreateMenu(ModeMenuHandler);	
	SetMenuTitle(menu, "模式设置");  // 标题
	AddMenuItem(menu, "SI num settings", "特感数量");
	AddMenuItem(menu, "SI spawn time settings", "特感复活时间");

	if (h_TrainingMode && h_TrainingMode.BoolValue)
		AddMenuItem(menu, "Enable/Disable auto revive", "开/关自动解控-当前[开]");
	else if (h_TrainingMode && !h_TrainingMode.BoolValue)
		AddMenuItem(menu, "Enable/Disable auto revive", "开/关自动解控-当前[关]");
	
	AddMenuItem(menu, "Select Training Mode", "设置训练模式");

	SetMenuExitButton(menu, true);  // 能够看见关闭按钮
	DisplayMenu(menu, client, MENU_TIME_FOREVER); //永久显示菜单,直到用户操作
	return Plugin_Handled;
}

public SINumMenu(client)
{
	new Handle:menu = CreateMenu(SINumMenuHandler);
	SetMenuTitle(menu, "特感数量选择");
	new String: siNumStr[8];
	for (new idx = 8; idx <= 28; idx += 2)
	{
		Format(siNumStr, sizeof(siNumStr),"%d特", idx);
		AddMenuItem(menu, "SI num", siNumStr);
	}
	DisplayMenu(menu, client, MENU_TIME_FOREVER); //永久显示菜单,直到用户操作
	PrintToChatAll("选择修改特感数量");
	return Plugin_Handled;
}

public SINumMenuHandler(Handle:menu, MenuAction:action, client, itemNum)
{
	if ( action == MenuAction_Select )   // 判断操作选择
	{
		PrintToChatAll("修改当前特感数量为: %d", itemNum * 2 + 8);
    }
}

public SISpawnTimeMenu(client)
{
	new Handle:menu = CreateMenu(SISpawnTimeMenuHandler);
	DisplayMenu(menu, client, MENU_TIME_FOREVER); //永久显示菜单,直到用户操作
	return Plugin_Handled;
}

public SISpawnTimeMenuHandler(Handle:menu, MenuAction:action, client, itemNum)
{

}

public TrainingModeMenu(client)
{
	new Handle:menu = CreateMenu(TrainingModeMenuHandler);
	DisplayMenu(menu, client, MENU_TIME_FOREVER); //永久显示菜单,直到用户操作
	return Plugin_Handled;
}

public TrainingModeMenuHandler(Handle:menu, MenuAction:action, client, itemNum)
{

}

public ModeMenuHandler(Handle:menu, MenuAction:action, client, itemNum) //因为上面的操作都是针对menu(CreateMenu(ModeMenuHandler); ) 所以就跳到这里了
{
	if ( action == MenuAction_Select )   // 判断操作选择
	{
		switch (itemNum)
		{
			case 0: // 特感数量 
			{
				// VoteMenuItems[client] = "SI_NUM";
				SINumMenu(client);
			}
			case 1: // 特感复活时间
			{
				VoteMenuItems[client] = "SI_SPAWN_TIME";
			}
			case 2: // 开关自动解控
			{
				VoteMenuItems[client] = "GM_training2";
			}
			case 4: // 开关自动解控
			{
				
			}
		}
		// Cmd_ChangeGameMode(client);
    }
}

public Action:Cmd_ChangeGameMode(client)
{
	if (!NativeVotes_IsVoteTypeSupported(NativeVotesType_Custom_YesNo))
	{
		ReplyToCommand(client, "Game does not support Custom Yes/No votes.");
		return Plugin_Handled;
	}

	if (!NativeVotes_IsNewVoteAllowed())
	{
		new seconds = NativeVotes_CheckVoteDelay();
		ReplyToCommand(client, "Vote is not allowed for %d more seconds", seconds);
	}
	
	char buffer[512];
	if (StrEqual(VoteMenuItems[client], "GM_training1"))
	{
		Format(buffer, sizeof buffer, "修改游戏模式为 综合防控");
	}
	else if (StrEqual(VoteMenuItems[client], "GM_community1"))
	{
		Format(buffer, sizeof buffer, "修改游戏模式为 普通速递");
	}
	else if (StrEqual(VoteMenuItems[client], "GM_training2"))
	{
		Format(buffer, sizeof buffer, "修改游戏模式为 Hunter Jockey特训");
	}
	new Handle:vote = NativeVotes_Create(YesNoCustomHandler, NativeVotesType_Custom_YesNo, NATIVEVOTES_ACTIONS_DEFAULT|MenuAction_Display);
	NativeVotes_SetInitiator(vote, client);
	NativeVotes_SetDetails(vote, buffer);
	NativeVotes_DisplayToAll(vote, 15);
	
	return Plugin_Handled;
}

public YesNoCustomHandler(Handle:vote, MenuAction:action, param1, param2)
{
	int client = NativeVotes_GetInitiator(vote);
	switch (action)
	{
		case MenuAction_End:
		{
			NativeVotes_Close(vote);
		}
		
		// case MenuAction_Display:
		// {
		// 	new String:display[64];
		// 	Format(display, sizeof(display), "%N Test Yes/No Vote", param1);
		// 	PrintToChat(param1, "New Menu Title: %s", display);
		// 	NativeVotes_RedrawVoteTitle(display);
		// 	return _:Plugin_Changed;
		// }
		
		case MenuAction_VoteCancel:
		{
			if (param1 == VoteCancel_NoVotes)
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_NotEnoughVotes);
			}
			else
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_Generic);
			}
			VoteMenuItems[client] = "";
		}
		
		case MenuAction_VoteEnd:
		{
			if (param1 == NATIVEVOTES_VOTE_NO)
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_Loses);
			}
			else
			{
				char buffer[512];
				if (StrEqual(VoteMenuItems[client], "GM_training1"))
				{
					Format(buffer, sizeof buffer, "修改游戏模式: 综合防控训练");

					// kick bot & give scout
					for (int i = 1; i < MaxClients + 1; i ++)
					{
						if (IsClientInGame(i))
						{
							if (IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVORS)
							{
								if (!IsClientInKickQueue(i))
								{
									KickClient(i);
								}
							}
							else if (!IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVORS)
							{
								GivePlayerItem(i, "weapon_sniper_scout");
							}
						}
					}
					ServerCommand("sm_execcfg sourcemod/training.cfg");
				}
				else if (StrEqual(VoteMenuItems[client], "GM_community1"))
				{
					Format(buffer, sizeof buffer, "修改游戏模式: 速递模式");

					// 需要将所有参数还原 有些CFG参数耦合在了l4d2_infectedbots_fix_ch里 本来应该在no_training 懒得改了^^
					ServerCommand("sm_execcfg sourcemod/l4d2_infectedbots_fix_ch.cfg");
					ServerCommand("sm_execcfg sourcemod/no_training.cfg");
				}
				else if (StrEqual(VoteMenuItems[client], "GM_training2"))
				{
					Format(buffer, sizeof buffer, "修改游戏模式: Hunter/Jockey特训");

					for (int i = 1; i < MaxClients + 1; i ++)
					{
						if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVORS && !IsClientInKickQueue(i))
						{
							KickClient(i);
						}
					}
					ServerCommand("sm_execcfg sourcemod/training2.cfg");
				}
				NativeVotes_DisplayPassCustom(vote, "%s 通过!", buffer);
				VoteMenuItems[client] = "";
			}
		}
	}
	
	return 0;
}
