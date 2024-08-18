Msg("Activating Mutation4 Script\n");

DirectorOptions <-
{	
	//ActiveChallenge = 1

// 特感刷新秒数，绝境默认15
	cm_SpecialRespawnInterval = 15

// 特感同时出现的最大数量
	cm_MaxSpecials = 	28
	HunterLimit = 		6
	BoomerLimit = 		6
	SmokerLimit = 		6
	JockeyLimit = 		6
	ChargerLimit = 		6
	SpitterLimit = 		5
	 
// 控制型特感同时出现的最大数量 (除了口水胖子之外的所有特感的总和)
	DominatorLimit = 	28

// 用来防止藏特感的参数，不用管
	cm_AggressiveSpecials = 1

// Relax => build
	//RelaxMaxFlowTravel = 3000

	DefaultItems =
	[
		"smg_silenced",
		"knife",
	]

	function GetDefaultItem( idx )
	{
		if ( idx < DefaultItems.len() )
		{
			return DefaultItems[idx];
		}
		return 0;
	}

	weaponsToConvert =
	{
		weapon_smg = "weapon_smg_silenced_spawn"
	}

	function ConvertWeaponSpawn( classname )
	{
		if ( classname in weaponsToConvert )
		{
			return weaponsToConvert[classname];
		}
		return 0;
	}
}

last_set <- 0;
SIFastRespawn <- 0;

function OnGameEvent_player_death( params )
{
    local EntityKill = GetPlayerFromUserID(params.userid);
	local _interval = DirectorOptions.cm_SpecialRespawnInterval;
    if (IsPlayerABot(EntityKill)
        && EntityKill.GetZombieType() < 7
        && EntityKill.GetZombieType() != 4)
    {
		if (SIFastRespawn == 1)
		{
			//ClientPrint(null, DirectorScript.HUD_PRINTTALK, "quick spawn");
			last_set = Time();
			EntityKill.Kill();
			if (Time() >= last_set + DirectorOptions.cm_SpecialRespawnInterval)
			{
				Director.ResetSpecialTimers();
			}
		}
    }
    else
    {
        return
    }
}

function update_settings()
{
    local cvarSINum = (Convars.GetFloat("l4d_infectedbots_max_specials")).tointeger()
    local cvarSIRespawnInterval = (Convars.GetFloat("l4d_infectedbots_spawn_time_max")).tointeger()
    local cvarSIFlowTravel = (Convars.GetFloat("l4d_infectedbots_spawn_relax_flow_travel_max")).tointeger()
    
    SIFastRespawn = (Convars.GetFloat("l4d_infectedbots_fast_spawn")).tointeger()

    local otherSINum = cvarSINum / 4
    otherSINum = otherSINum > 6 ? 6 : otherSINum
    otherSINum = otherSINum < 2 ? 2 : otherSINum

	local spitterNum = otherSINum - 1
    spitterNum = spitterNum > 5 ? 5 : spitterNum

	DirectorOptions.cm_MaxSpecials = cvarSINum
    DirectorOptions.DominatorLimit = cvarSINum
	DirectorOptions.cm_SpecialRespawnInterval = cvarSIRespawnInterval
	DirectorOptions.HunterLimit = otherSINum
	DirectorOptions.BoomerLimit = otherSINum
	DirectorOptions.SmokerLimit = otherSINum
	DirectorOptions.JockeyLimit = otherSINum
	DirectorOptions.ChargerLimit =otherSINum
	DirectorOptions.SpitterLimit = spitterNum
	//DirectorOptions.RelaxMaxFlowTravel = cvarSIFlowTravel
	
	DirectorOptions.cm_AggressiveSpecials = 1
}

update_settings();
g_ModeScript.update_settings();