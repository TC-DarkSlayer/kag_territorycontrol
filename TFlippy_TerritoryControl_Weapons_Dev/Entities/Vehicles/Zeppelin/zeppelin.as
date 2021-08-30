#include "VehicleCommon.as"
#include "Hitters.as"
#include "Explosion.as";

//most of the code is in BomberCommon.as

void onInit(CBlob@ this)
{
	Vehicle_Setup(this,
	              20.0f, // move speed
	              0.19f,  // turn speed
	              Vec2f(5.0f, 5.0f), // jump out velocity
	              true  // inventory access
	             );

	VehicleInfo@ v;
	if (!this.get("VehicleInfo", @v)) return;
	
	Vehicle_SetupAirship(this, v, 50.0f);

	this.Tag("vehicle");
	this.Tag("heavy weight");
	
	this.getShape().SetOffset(Vec2f(0, 10));
	this.getShape().SetRotationsAllowed(false);
	this.getShape().getConsts().transports = true;
	this.SetLight(false);

	this.set_f32("max_fuel", 20000);
	this.set_f32("fuel_consumption_modifier", 1.50f);
	
	{
		//front window shitbox
		Vec2f[] shape = { 
						  Vec2f(80.0f,  80.0f),
		                  Vec2f(70.0f,  110.0f),
		                  Vec2f(90.0f,  80.0f),
		                  Vec2f(80.0f,  110.0f)
		                };
		this.getShape().AddShape(shape);
	}
	{
		//roof shitbox
		Vec2f[] shape = { 
						  Vec2f(0.0f,  85.0f),
		                  Vec2f(-40.0f,  65.0f),
		                  Vec2f(80.0f,  85.0f),
		                  Vec2f(125.0f,  65.0f)
		                };
		this.getShape().AddShape(shape);
	}
	{
		//roof shitbox redux
		Vec2f[] shape = { 
						  Vec2f(-40.0f,  65.0f),
		                  Vec2f(0.0f,  45.0f),
		                  Vec2f(125.0f,  65.0f),
		                  Vec2f(85.0f,  45.0f)
		                };
		this.getShape().AddShape(shape);
	}
}

void onDie( CBlob@ this )
{
	if (isServer())
	{
		CBlob@ wreck = server_CreateBlobNoInit("armoredbomberwreck");
		wreck.setPosition(this.getPosition());
		wreck.setVelocity(this.getVelocity());
		wreck.setAngleDegrees(this.getAngleDegrees());
		wreck.server_setTeamNum(this.getTeamNum());
		wreck.Init();
		
		for (int i = 0; i < 5 + XORRandom(3); i++)
		{
			CBlob@ blob = server_CreateBlob("flame", -1, this.getPosition());
			blob.setVelocity(Vec2f(XORRandom(10) - 5, -XORRandom(6)));
			blob.server_SetTimeToDie(4 + XORRandom(15));
		}
	}
}

//required shit
void Vehicle_onFire(CBlob@ this, VehicleInfo@ v, CBlob@ bullet, const u8 charge)
{

}

bool Vehicle_canFire(CBlob@ this, VehicleInfo@ v, bool isActionPressed, bool wasActionPressed, u8 &out chargeValue)
{
	return true;
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}

//SPRITE
void onInit(CSprite@ this)
{
	this.SetZ(-50.0f);
	this.getCurrentScript().tickFrequency = 5;
	
	// should only appear when not inside 
	CSpriteLayer@ hull = this.addSpriteLayer("front layer", "zeppelinexterior.png", 89, 23);
	if (hull !is null)
	{
		hull.addAnimation("default", 0, false);
		int[] frames = { 0, 1 };
		hull.animation.AddFrames(frames);
		hull.SetRelativeZ(200.0f);
		//was 0.0, -26.0
		hull.SetOffset(Vec2f(-13.0f, -5.0f));
	}

	CSpriteLayer@ balloon = this.addSpriteLayer("balloon", "zeppelinballoon.png", 181, 46);
	if (balloon !is null)
	{
		balloon.addAnimation("default", 0, false);
		int[] frames = { 0 };
		balloon.animation.AddFrames(frames);
		balloon.SetRelativeZ(1.0f);
		balloon.SetOffset(Vec2f(-20.0f, -35.0f));
	}
}

void onTick(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	f32 ratio = 1.0f - (blob.getHealth() / blob.getInitialHealth());
	this.animation.setFrameFromRatio(ratio);

	CSpriteLayer@ balloon = this.getSpriteLayer("balloon");
	if (balloon !is null)
	{
		if (blob.getHealth() > 1.0f)
			balloon.animation.frame = Maths::Min((ratio) * 3, 1.0f);
		else
			balloon.animation.frame = 2;
	}
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	f32 dmg = damage;
	switch (customData)
	{
		case Hitters::sword:
		case Hitters::arrow:
		case Hitters::stab:
			dmg *= 0.25f;
			break;
		case Hitters::bomb:
			dmg *= 3.0f;
			break;
		case Hitters::keg:
		case Hitters::explosion:
			dmg *= 3.0f;
			break;
		case Hitters::bomb_arrow:
			dmg *= 3.00f;
			break;
		case Hitters::cata_stones:
			dmg *= 1.0f;
			break;
		case Hitters::crush:
			dmg *= 1.0f;
			break;
		case Hitters::flying:
			dmg *= 0.5f;
			break;
		// case Hitters::bullet:
			// dmg *= 0.4f;
			// break;
	}
	return dmg;
}
