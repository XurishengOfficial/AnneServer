
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <adminmenu>
#include <string>
#include <functions>
#define PLUGIN_VERSION "1.1.7"
#define CVAR_FLAGS FCVAR_NOTIFY

#define IsValidClient(%1)		(1 <= %1 <= MaxClients && IsClientInGame(%1))

Handle SoundStore = INVALID_HANDLE;

ConVar g_hSoundEnable;
ConVar g_hSoundHeadshot;
ConVar g_hSoundKill;
ConVar g_hSoundHit;
ConVar g_hBlast;

int SoundSelect[MAXPLAYERS + 1];
char SavePath[256];

new String: g_sPitchforkImpactFleshSnd[4][] =
{
	"weapons/pitchfork/pitchfork_impact_flesh1.wav",
	"weapons/pitchfork/pitchfork_impact_flesh2.wav",
	"weapons/pitchfork/pitchfork_impact_flesh3.wav",
	"weapons/pitchfork/pitchfork_impact_flesh4.wav"
};

new String: g_sFallDamageSnd[2][] =
{
	"player/damage1.wav",
	"player/damage2.wav"
};

new String: g_sBulletImpactSnd[8][] =
{
	"npc/infected/gore/bullets/bullet_impact_01.wav",
	"npc/infected/gore/bullets/bullet_impact_02.wav",
	"npc/infected/gore/bullets/bullet_impact_03.wav",
	"npc/infected/gore/bullets/bullet_impact_04.wav",
	"npc/infected/gore/bullets/bullet_impact_05.wav",
	"npc/infected/gore/bullets/bullet_impact_06.wav",
	"npc/infected/gore/bullets/bullet_impact_07.wav",
	"npc/infected/gore/bullets/bullet_impact_08.wav"
};

new String: g_sFleshBreakSnd[2][] =
{
	"physics/body/body_medium_break2.wav",
	"physics/body/body_medium_break3.wav"
};

public Plugin:myinfo = 
{
	name = "L4D2 kill sound feedback",
	author = "TsukasaSato, Azuki",
	description = "Custom kill sound feedback (only headshot for SI: RNG 5 Headshot sound;kill for common)",
	version = "PLUGIN_VERSION"
}

public OnPluginStart()
{
	LoadSndData();
	decl String:Game_Name[64];
	GetGameFolderName(Game_Name, sizeof(Game_Name));
	if(!StrEqual(Game_Name, "left4dead2", false))
	{
		SetFailState("本插件仅支持L4D2!");
	}

	CreateConVar("l4d2_hitsound", PLUGIN_VERSION, "Plugin version", 0);
	g_hSoundHeadshot = CreateConVar("sm_hitsound_mp3_headshot", "hitsound/headshot", "爆头音效的地址");	
	g_hSoundKill = CreateConVar("sm_hitsound_mp3_kill", "hitsound/kill.mp3", "击杀音效的地址");	
	g_hSoundHit = CreateConVar("sm_hitsound_mp3_hit", "hitsound/hit.mp3", "命中音效的地址");	
	g_hSoundEnable = CreateConVar("sm_hitsound_sound_enable", "1", "是否开启音效(0-关, 1-开)", CVAR_FLAGS);
	g_hBlast = CreateConVar("sm_blast_damage_enable", "0", "是否开启爆炸反馈提示(0-关, 1-开 建议关闭)", CVAR_FLAGS);
	RegConsoleCmd("sm_snd", MenuFunc_Snd, "设置音效类型");
	AutoExecConfig(true, "l4d2_hitsound");//是否生成cfg注释即不生成
	
	HookEvent("infected_death",	Event_InfectedDeath);
	HookEvent("player_death",	Event_PlayerDeath);
}

public Action MenuFunc_Snd(int client, int args)
{
	Handle menu = CreateMenu(MenuHandler_MainMenu);
	char line[1024];
	Format(line, sizeof(line), "*********************\n*——选择击中音效——*\n*********************\n当前选择是: %d" ,SoundSelect[client] + 1);//, SoundSelect[client]
	SetMenuTitle(menu, line);		
	AddMenuItem(menu, "item0", "设置为使用游戏内原有音效「 默认 」");
	AddMenuItem(menu, "item1", "无击中音效");
	AddMenuItem(menu, "item2", "使用自定义击杀音效");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	return Plugin_Handled;	
}

public int MenuHandler_MainMenu(Handle menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)	
		CloseHandle(menu);

	if(action == MenuAction_Select)
	{
		switch(item)
		{
			case 0:
			{
				SoundSelect[client] = 0;
				PrintToChat(client, "设置为使用游戏内原有音效「 默认 」");
			}
			case 1:
			{
				SoundSelect[client] = 1;
				PrintToChat(client, "设置为无音效");
			}

			case 2:
			{
				SoundSelect[client] = 2;
				PrintToChat(client, "使用自定义击杀音效");
			}
		}
	}
	return 0;
}

public void OnClientPutInServer(int client)
{
	if(!IsFakeClient(client))
	{
		SoundSelect[client] = 0;
		ClientSaveToFileLoad(client);		
	}
}

public void OnClientDisconnect(int client)
{
	if(!IsFakeClient(client))
	{
		ClientSaveToFileSave(client);
	}
}

void LoadSndData()
{
	SoundStore = CreateKeyValues("SoundSelect");
	BuildPath(Path_SM, SavePath, 255, "data/SoundSelect.txt");

	if (FileExists(SavePath))
		FileToKeyValues(SoundStore, SavePath);
	else
		KeyValuesToFile(SoundStore, SavePath);
}

public void ClientSaveToFileSave(int client)
{
	char user_id[128]="";
	GetClientAuthId(client, AuthId_Engine, user_id, sizeof(user_id), true);

	KvJumpToKey(SoundStore, user_id, true);
	KvSetNum(SoundStore, "Snd", SoundSelect[client]);

	KvGoBack(SoundStore);
	KvRewind(SoundStore);
	KeyValuesToFile(SoundStore, SavePath);
}

public void ClientSaveToFileLoad(int client)
{
	char user_id[128]="";
	GetClientAuthId(client, AuthId_Engine, user_id, sizeof(user_id), true);

	KvJumpToKey(SoundStore, user_id, true);
	SoundSelect[client] = KvGetNum(SoundStore, "Snd", 0);

	KvGoBack(SoundStore);
	KvRewind(SoundStore);
}

public Action:TaskEmit_PitchforkImpactFlesh_Snd(Handle:Timer, any:attacker)
{
	new i = GetRandomInt(0, 3);
	PrecacheSound(g_sPitchforkImpactFleshSnd[i], true);
	EmitSoundToClient(attacker, g_sPitchforkImpactFleshSnd[i], SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	return Plugin_Stop;
}

public Action:TaskEmit_FallDamageSnd(Handle:Timer, any:attacker)
{
	new i = GetRandomInt(0, 1);
	PrecacheSound(g_sFallDamageSnd[i], true);
	EmitSoundToClient(attacker, g_sFallDamageSnd[i], SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	return Plugin_Stop;
}

public Action:TaskEmit_BulletImpactSnd(Handle:Timer, any:attacker)
{
	new i = GetRandomInt(0, 7);
	PrecacheSound(g_sBulletImpactSnd[i], true);
	EmitSoundToClient(attacker, g_sBulletImpactSnd[i], SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	return Plugin_Stop;
}

public void Emit_FleshBreakSnd(int attacker)
{
	new i = GetRandomInt(0, 1);
	PrecacheSound(g_sFleshBreakSnd[i], true);
	EmitSoundToClient(attacker, g_sFleshBreakSnd[i], SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new bool:heatshout = false;
	heatshout = GetEventBool(event, "headshot");
	new damagetype = GetClientOfUserId(GetEventInt(event, "type"));

	if (GetConVarInt(g_hSoundEnable) != 1)
		return Plugin_Continue;

	if(damagetype & DMG_DIRECT)
		return Plugin_Continue;
		
	if(GetConVarInt(g_hBlast) == 0 && damagetype & DMG_BLAST)
		return Plugin_Continue;

	if(!heatshout) return Plugin_Continue;
	
	if(!IsValidClient(victim) || GetClientTeam(victim) != 3 || !IsValidClient(attacker) || GetClientTeam(attacker) != 2 || IsFakeClient(attacker))  
		return Plugin_Continue;
	
	if(SoundSelect[attacker] == 2)
	{
		new String:tmp[64];
		/* RNG */
		new randomIdx = GetRandomInt(1, 5);

		GetConVarString(g_hSoundHeadshot, tmp, sizeof(tmp));
		Format(tmp, sizeof(tmp), "%s%d.mp3", tmp, randomIdx);

		PrecacheSound(tmp, true);
		EmitSoundToClient(attacker, tmp, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	}

	if(SoundSelect[attacker] == 0)
	{
		Emit_FleshBreakSnd(attacker);
		CreateTimer(0.1, TaskEmit_PitchforkImpactFlesh_Snd, attacker);
		CreateTimer(0.295, TaskEmit_FallDamageSnd, attacker);
		CreateTimer(0.15, TaskEmit_BulletImpactSnd, attacker);
	}
	return Plugin_Continue;
}

public Action:Event_InfectedDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	// new bool:heatshout = false;
	// heatshout = GetEventBool(event, "headshot");
	new bool:damagetype = GetEventBool(event, "blast");
	new WeaponID = GetEventInt(event, "weapon_id");

	if (!attacker || IsFakeClient(attacker) || GetConVarInt(g_hSoundEnable) != 1 || SoundSelect[attacker] == 1 || GetClientTeam(attacker) != 2)
		return Plugin_Continue;

	/* 后续排除近战 */
	if(WeaponID == 0)
    	return Plugin_Continue;

	if(GetConVarInt(g_hBlast) == 0 && damagetype)
    	return Plugin_Continue;

	if(SoundSelect[attacker] == 2)
	{
		new String:tmp[64];
		if (GetRandomInt(0, 1))
			GetConVarString(g_hSoundKill, tmp, sizeof(tmp));
		else 
			GetConVarString(g_hSoundHit, tmp, sizeof(tmp));

		PrecacheSound(tmp, true);
		EmitSoundToClient(attacker, tmp, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	}
	if(SoundSelect[attacker] == 0)
	{
		CreateTimer(0.025, TaskEmit_BulletImpactSnd, attacker);
	}
	return Plugin_Continue;
}