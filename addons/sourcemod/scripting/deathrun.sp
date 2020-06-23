#include <sourcemod>
#include <sdktools>
#include <dhooks>
#include <tf2attributes>

#define CONFIG_FILE		"configs/deathrun/deathrun.cfg"

enum AttributeModMode
{
	ModMode_Set, 
	ModMode_Remove, 
}

enum struct WeaponAttributeConfig
{
	char name[PLATFORM_MAX_PATH];
	float value;
	AttributeModMode mode;
	
	void ReadConfig(KeyValues kv)
	{
		kv.GetString("name", this.name, PLATFORM_MAX_PATH);
		this.value = kv.GetFloat("value");
		
		char mode[PLATFORM_MAX_PATH];
		kv.GetString("mode", mode, sizeof(mode));
		
		if (StrEqual(mode, "set"))
			this.mode = ModMode_Set;
		else if (StrEqual(mode, "remove"))
			this.mode = ModMode_Remove;
	}
}

enum struct WeaponConfig
{
	int defindex;
	bool blockPrimaryFire;
	bool blockSecondaryAttack;
	bool remove;
	ArrayList attributes; // ArrayList of WeaponAttributeConfig
	
	void ReadConfig(KeyValues kv)
	{
		char defindexes[PLATFORM_MAX_PATH];
		kv.GetSectionName(defindexes, sizeof(defindexes));
		
		char parts[32][8]; // maximum 32 defindexes up to 8 characters
		int retrieved = ExplodeString(defindexes, ";", parts, sizeof(parts), sizeof(parts[]));
		
		for (int i = 0; i < retrieved; i++)
		{
			this.defindex = StringToInt(parts[i]);
			this.blockPrimaryFire = view_as<bool>(kv.GetNum("block_attack"));
			this.blockSecondaryAttack = view_as<bool>(kv.GetNum("block_attack2"));
			this.remove = view_as<bool>(kv.GetNum("block_attack2"));
			
			if (kv.JumpToKey("attributes", false))
			{
				this.attributes = new ArrayList(sizeof(WeaponAttributeConfig));
				
				if (kv.GotoFirstSubKey(false))
				{
					do
					{
						WeaponAttributeConfig attribute;
						attribute.ReadConfig(kv);
						this.attributes.PushArray(attribute);
					}
					while (kv.GotoNextKey(false));
					kv.GoBack();
				}
				kv.GoBack();
			}
		}
	}
}

methodmap WeaponConfigList < ArrayList
{
	public WeaponConfigList()
	{
		return view_as<WeaponConfigList>(new ArrayList(sizeof(WeaponConfig)));
	}
	
	public void ReadConfig(KeyValues kv)
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				WeaponConfig weapon;
				weapon.ReadConfig(kv);
				this.PushArray(weapon);
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
	
	public int GetByDefIndex(int defindex, WeaponConfig config)
	{
		int i = this.FindValue(defindex);
		return i != -1 ? this.GetArray(i, config) : 0;
	}
}

WeaponConfigList g_Weapons;

#include "deathrun/sdk.sp"

public Plugin pluginInfo =  {
	name = "Deathrun", 
	author = "Mikusch", 
	description = "Deathrun", 
	version = "1.0", 
	url = "https://github.com/Mikusch/deathrun"
};

public void OnPluginStart()
{
	SDK_Init();
	
	g_Weapons = new WeaponConfigList();
	
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), CONFIG_FILE);
	KeyValues kv = new KeyValues("Weapons");
	if (kv.ImportFromFile(path))
	{
		g_Weapons.ReadConfig(kv);
		kv.GoBack();
	}
	delete kv;
	
	// Late load!
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
			OnClientPutInServer(client);
	}
}

public void OnClientPutInServer(int client)
{
	DHook_HookGiveNamedItem(client);
}
