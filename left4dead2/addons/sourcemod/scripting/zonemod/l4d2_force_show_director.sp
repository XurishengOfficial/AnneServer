#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

public Plugin myinfo =
{
	name = "Force Show Director",
	author = "Azuki(Cirno)",
	description = "",
	version = "1.0",
	url = ""
};

public void OnPluginStart()
{
	RegAdminCmd("sm_test", Cmd_Test, ADMFLAG_ROOT);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

void CheatCommandForAll(char[] strCommand)
{
	int flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
	for (int client = 1; client <= 31; client++)
	{
		if (IsClientConnected(client) && IsClientInGame(client))
		{
			ClientCommand(client, strCommand);
		}
	}
	SetCommandFlags(strCommand, flags | FCVAR_CHEAT);
}

public Action Cmd_Test(int client, int args)
{
	CheatCommandForAll("director_show_intensity 1");
	return Plugin_Handled;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CheatCommandForAll("director_show_intensity 1");
}


