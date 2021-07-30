#include "CustomBlocks.as"
#include "Hitters.as"
#include "HittersTC.as"
#include "FireCommon.as"

bool isDead(Vec2f pos, CMap@ map)
{
	Tile backtile = map.getTile(pos);
	if (!isTileTypeKudzu(backtile.type))
	{
		return true;
	}
	return false;
}

bool isTileTypeKudzu(TileType tile)
{
	return tile >= CMap::tile_kudzu && tile <= CMap::tile_kudzu_d0;
}

u8 canGrowTo(CBlob@ this, Vec2f pos, CMap@ map, Vec2f dir) //0 = no good, 1 = good, 2 = good and no kudzu blob already here
{
	Tile backtile = map.getTile(pos);
	TileType type = backtile.type;

	//if (!map.hasSupportAtPos(pos)) 
	//	return false;

	if (map.isTileBedrock(type)  || (isTileBGlass(type) && !this.hasTag("Mut_IgnoreBGlass"))) //Does not grow past bedrock or glass backgrounds (unless mutated)
	{
		return 0;
	}

	if (isTileSolid(pos, map) && !isTileTypeKudzu(type)) //Dont go past solid blocks unless they are kudzu
	{
		return 0;
	}

	if (pos.y < 2 * map.tilesize || //Check map edges
	        pos.x < 2 * map.tilesize ||
	        pos.x > (map.tilemapwidth - 2.0f)*map.tilesize)
	{
		return 0;
	}

	if(map.getSectorAtPosition(pos, "no build") !is null) //Dont grow into railwail tracks (and other no build areas)
	{
		return 0;
	}

	double halfsize = map.tilesize * 0.5f;
	Vec2f middle = pos; //+ Vec2f(halfsize, halfsize);
	u8 kudzublob = 1;

	CBlob@[] blobsInRadius;
	if (map.getBlobsInRadius(middle, map.tilesize, @blobsInRadius))
	{
		for (uint i = 0; i < blobsInRadius.length; i++)
		{
			CBlob @b = blobsInRadius[i];
			if (!b.isAttached())
			{	
				Vec2f bpos = b.getPosition();

				const string bname = b.getName();

				bool cantBuild = (b.isCollidable() || b.getShape().isStatic());
				//print(cantBuild + " "+ bname);

				// cant place on any other blob
				if (cantBuild &&
						!b.hasTag("dead") &&
						!b.hasTag("material") && //Will just push materials dead things or projectiles similar to the normal human build mode
						!b.hasTag("projectile") &&
						bname != "bush")
				{
					//print(pos + " " +bpos);

					f32 angle_decomp = Maths::FMod(Maths::Abs(b.getAngleDegrees()), 180.0f);
					bool rotated = angle_decomp > 45.0f && angle_decomp < 135.0f;
					f32 width = rotated ? b.getHeight() : b.getWidth();
					f32 height = rotated ? b.getWidth() : b.getHeight();
					if ((middle.x > bpos.x - width * 0.5f - halfsize) && (middle.x - halfsize < bpos.x + width * 0.5f)
							&& (middle.y > bpos.y - height * 0.5f - halfsize) && (middle.y - halfsize < bpos.y + height * 0.5f))
					{
						if (b.hasTag("kudzu"))	//Ignores kudzu blobs for obvious reasons (From KudzuHit.as))
						{
							kudzublob = 0; //This is not a place where you should upgrade
							//print("OVERLAP FOUND");
						}
						else 
						{
							if (!b.hasTag("invincible"))
							{
								int Type = HittersTC::poison;
								double Amount = 0.125f * this.get_u8("DamageMod");

								if (this.hasTag("Mut_StunningDamage")) Type = Hitters::spikes;

								this.server_Hit(b, bpos, bpos - pos, Amount, Type, false);

								if (this.hasTag("Mut_Knockback"))
								{
									Vec2f force = (bpos - pos);
									force.Normalize();
									b.AddForce(force * Maths::Min(50, b.getMass()) * (XORRandom(6) + 1));
								}
							}
							return 0;
						}
					}
				}	
			}
		}
	}

	//Check if it has support there
	if (map.isTileBackgroundNonEmpty(backtile) || isTileTypeKudzu(type)) //Can grow on backgrounds (and pass through kudzu)
	{
		return 1 + kudzublob;
	}

	if ((this.getPosition() - pos).Length() < 15.0f) //Can be unsuported while near the core
	{
		return 1 + kudzublob;
	}
	
	for (u8 i = 0; i < 8; i++)
    {
		Tile test = map.getTile(pos + directions[i]);
		//print(directions[i].x + " " + directions[i].y);
        if (isTileSolid(pos + directions[i], map) && !isTileTypeKudzu(test.type)) return 1 + kudzublob; //Can grow while at least 1 solid non kudzu tile in the 8 tiles around it
    }

	if (Vec2f(0.0f,-8.0f) == dir && this.hasTag("Mut_UpwardLines"))
	{
		if (CMap::tile_empty == map.getTile(pos + Vec2f(8.0f, 0.0f)).type && CMap::tile_empty == map.getTile(pos + Vec2f(-8.0f, 0.0f)).type)
		{
			return 1 + kudzublob;
		}
	}

	if (Vec2f(0.0f,8.0f) == dir && this.hasTag("Mut_DownLines"))
	{
		if (CMap::tile_empty == map.getTile(pos + Vec2f(8.0f, 0.0f)).type && CMap::tile_empty == map.getTile(pos + Vec2f(-8.0f, 0.0f)).type)
		{
			return 1 + kudzublob;
		}
	}

	if (this.hasTag("Mut_SupportHalo"))
	{
		Vec2f distance = this.getPosition() - pos;
		if (8.0f * 7 <= distance.Length() && 8.0f * 9 >= distance.Length())
		{
			//print("TEST");
			return 1 + kudzublob;
		}
		
	}

	return 0; //No support found
	
}

bool isTileSolid(Vec2f pos, CMap@ map)
{
	const u32 offset = map.getTileOffset(pos);
	if (map.hasTileFlag(offset, Tile::SOLID)) return true;
	return false;
}

void MutateTick(CBlob@ this)
{
	if (this.hasTag("Mut_Regeneration"))
	{
		//print(this.getHealth() + "");
		this.server_Heal(0.1f);
	}
	if (this.get_u8("MutateMax") <= 70)
	{
		if (this.hasTag("Mut_Mutating"))
		{
			int r = XORRandom(this.get_f32("MutationTime")*0.5);
			if (r <= 50)
			{
				Mutate(this);
			}
		}
		else if (getGameTime() >= this.get_f32("NextMutate") && this.get_f32("MutationTime") < (1800*5))
		{
			Mutate(this);
		}
	}
}

void UpgradeTile(CBlob@ this, Vec2f pos, CMap@ map, Random@ rand)
{
	//Create a new core if its time and its chance
	Vec2f distance = this.getPosition() - pos;
	if (getGameTime() > this.get_u32("Duplication Time") && this.get_u32("Duplication Time") != 0 && rand.NextRanged(30) == 0 && distance.Length() > 8.0f * 15) //Minimum distance for offshoots
	{
		CBlob@ core = server_CreateBlob("kudzucore", 0, pos);
		if (core != null)
		{
			core.getShape().SetStatic(true);
			Mutate(core); //Offspring start with 1 random mutation
		}
		this.set_u32("Duplication Time", 0); //No more duplicating after the first one
	}
	else if (getGameTime() > this.get_u32("Upgrade Time"))
	{
		double UpgradeSpeed = this.get_f32("UpgradeSpeed"); //Devides the time between upgrades

		if (this.hasTag("Mut_Badgers") && rand.NextRanged(150) == 0)
		{
			CBlob@ node = server_CreateBlob("kudzubadger", 0, pos);
			if (node != null)
			{
				node.getShape().SetStatic(true);
				if (this.hasTag("Mut_Explosive")) node.Tag("Mut_Explosive");
			}
			this.set_u32("Upgrade Time", getGameTime() + 1500 / UpgradeSpeed);
		}
		else if (this.hasTag("Mut_Explosive") && rand.NextRanged(50) == 0)
		{
			CBlob@ node = server_CreateBlob("kudzuexplosive", 0, pos);
			if (node != null)
			{
				node.getShape().SetStatic(true);
			}
			this.set_u32("Upgrade Time", getGameTime() + 600 / UpgradeSpeed);
		}
		else if (this.hasTag("Mut_Gold") && rand.NextRanged(70) == 0)
		{
			CBlob@ node = server_CreateBlob("kudzugold", 0, pos);
			if (node != null)
			{
				node.getShape().SetStatic(true);
			}
			this.set_u32("Upgrade Time", getGameTime() + 900 / UpgradeSpeed);
		}
		else if (this.hasTag("Mut_MysteryBox") && rand.NextRanged(300) == 0)
		{
			CBlob@ node = server_CreateBlob("kudzumysterybox", 0, pos);
			if (node != null)
			{
				node.getShape().SetStatic(true);
			}
			this.set_u32("Upgrade Time", getGameTime() + 1500 / UpgradeSpeed);
		}
	}
}

void Mutate(CBlob@ this, int hash = 0)
{
	this.set_f32("NextMutate", this.get_f32("MutationTime")+getGameTime());

	if (hash != 0)
	{
		u8 mutChance = this.get_u8("MutationChance");
		switch(hash)
		{
			case -661490310:	// mithrilingot
				this.set_f32("MutationTime", this.get_f32("MutationTime") * 0.9);
				this.add_u8("MutationChance", 1);
				break;

			case -1288560969:	// mithril
				if (!this.hasTag("Mut_RadResistance") && mutChance < XORRandom(50)) this.Tag("Mut_RadResistance");
				break;

			case -989285105:	// mithrilenriched
				if (!this.hasTag("Mut_RadResistance")) this.Tag("Mut_RadResistance");
				this.add_u8("MutationChance", 10);
				break;

			case 1074492747:	// dirt
				if (!this.hasTag("Mut_Regeneration") && mutChance < XORRandom(50)) this.Tag("Mut_Regeneration");
				else Mutate_ExpansionBehavior(this);
				break;

			case -1326479778:	// oil
				if (!this.hasTag("Mut_FireResistance") && mutChance < XORRandom(60))
				{
					this.Tag("Mut_FireResistance");
					this.Untag(spread_fire_tag);
					this.RemoveScript("IsFlammable.as");
				}
				break;

			case -123101143:	// meat
			case 336243301:		// steak
				if (mutChance < XORRandom(50)) Mutate_DamageBehavior(this);
				break;

			case -1370030172:	// gold ore
				if (!this.hasTag("Mut_Gold") && mutChance < XORRandom(40)) this.Tag("Mut_Gold");
				break;

			case -617913447:	// sulphur
				if (!this.hasTag("Mut_Explosive") && mutChance < XORRandom(40)) this.Tag("Mut_Explosive");
				break;

			case 389592510:		// badger
				if (!this.hasTag("Mut_Badgers") && mutChance < XORRandom(60)) this.Tag("Mut_Badgers");
				break;
		}
	}
	else
	{
		this.add_u8("MutateMax", 1);
		CParticle@ particle = ParticleAnimated("SmallSmoke", this.getPosition(), Vec2f(0, 0), 0, 1.0f, 2, 0.0f, false);
		if (particle != null)
		{
			particle.Z = 500;
		}

		if (this.get_u8("MutationChance") < XORRandom(15)) return;

		int r = XORRandom(20);
		if (r < 1 && !this.hasTag("Mut_Mutating")) //Possibly the most dangerous mutation, (At first slot to reduce the chance of getting it with other mutations)
		{
			this.Tag("Mut_Mutating");
		}
		else if (r < 5)
		{
			Mutate_SurvivabilityBahvior(this);
		}
		else if (r < 10)
		{
			Mutate_DamageBehavior(this);
		}
		else if (r < 15)
		{
			Mutate_ExpansionBehavior(this);
		}
		else if (r < 20)
		{
			Mutate_UpgradeBehavior(this);
		}
	}
}

void Mutate_SurvivabilityBahvior(CBlob@ this)
{
	int r = XORRandom(4);
	if (r < 1 && !this.hasTag("Mut_NoLight"))
	{
		this.SetLight(false);
		this.Tag("Mut_NoLight");
	}
	else if (r < 2 && !this.hasTag("Mut_FireResistance")) //Does not make the tiles fire resistant but the core at least
	{
		this.Tag("Mut_FireResistance");
		this.Untag(spread_fire_tag);
		this.RemoveScript("IsFlammable.as");
	}
	else if (r < 3 && !this.hasTag("Mut_Regeneration"))
	{
		this.Tag("Mut_Regeneration");
	}
	else if (r < 4 && !this.hasTag("Mut_RadResistance"))
	{
		this.Tag("Mut_RadResistance");
	}
}

void Mutate_DamageBehavior(CBlob@ this)
{
	int r = XORRandom(3);
	if (r < 1 && !this.hasTag("Mut_StunningDamage"))
	{
		this.Tag("Mut_StunningDamage");
	}
	else if (r < 2 && !this.hasTag("Mut_Knockback"))
	{
		this.Tag("Mut_Knockback");
	}
	else //Repeatable Mutation (+0.125 damage)
	{
		this.set_u8("DamageMod", this.get_u8("DamageMod") + 1);
	}
}

void Mutate_ExpansionBehavior(CBlob@ this)
{	
	int r = XORRandom(5);
	if (r < 1 && !this.hasTag("Mut_IgnoreBGlass"))
	{
		this.Tag("Mut_IgnoreBGlass");
	}
	else if (r < 2 && !this.hasTag("Mut_UpwardLines"))
	{
		this.Tag("Mut_UpwardLines");
	}
	else if (r < 3 && !this.hasTag("Mut_DownLines"))
	{
		this.Tag("Mut_DownLines");
	}
	else if (r < 4 && !this.hasTag("Mut_SupportHalo"))
	{
		this.Tag("Mut_SupportHalo");
	}
	else if (r != 4 && !this.hasTag("Mut_Teleporting")) //Can only be obtained if you already have at least support halo
	{
		this.Tag("Mut_Teleporting");
	}
	else //Repeatable Mutation (+1 Sprout, no cap but very slow)
	{
		this.set_u8("MaxSprouts", this.get_u8("MaxSprouts") + 1);
	}
}

void Mutate_UpgradeBehavior(CBlob@ this)
{	
	int r = XORRandom(5);
	if (r < 1 && XORRandom(3) == 0 && !this.hasTag("Mut_MysteryBox"))
	{
		this.Tag("Mut_MysteryBox");
	}
	else if (r < 2 && !this.hasTag("Mut_Explosive")) //Honestly a negative mutation, since the explosion also damages the plant and causes chain reactions
	{
		this.Tag("Mut_Explosive");
	}
	else if (r < 3 && !this.hasTag("Mut_Badgers"))
	{
		this.Tag("Mut_Badgers");
	}
	else if (r < 4 && !this.hasTag("Mut_Gold"))
	{
		this.Tag("Mut_Gold");
	}
	else //Repeatable Mutation
	{
		this.set_f32("UpgradeSpeed", this.get_f32("UpgradeSpeed") + 0.2); //Devides time between upgrades
	}
}

const Vec2f[] directions =
{
	Vec2f(0, -8),
	Vec2f(0, 8),
	Vec2f(8, 0),
	Vec2f(-8, 0),
	Vec2f(-8, -8),
	Vec2f(-8, 8),
	Vec2f(8, -8),
	Vec2f(8, 8)
};