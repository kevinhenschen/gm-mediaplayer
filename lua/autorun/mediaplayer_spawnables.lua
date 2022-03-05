local MediaPlayerClass = "mediaplayer_tv"

local function AddMediaPlayerModel( spawnName, name, model, playerConfig )
	list.Set( "SpawnableEntities", spawnName, {
		PrintName = name,
		ClassName = MediaPlayerClass,
		Category = "Media Player",
		DropToFloor = true,
		KeyValues = {
			model = model
		}
	} )

	list.Set( "MediaPlayerModelConfigs", model, playerConfig )
end

AddMediaPlayerModel(
	"../spawnicons/models/hunter/plates/plate5x8",
	"Huge Billboard",
	"models/hunter/plates/plate5x8.mdl",
	{
		angle = Angle(0, 90, 0),
		offset = Vector(-118.8, 189.8, 2.5),
		width = 380,
		height = 238
	}
)

AddMediaPlayerModel(
	"../spawnicons/models/props_phx/rt_screen",
	"Small TV",
	"models/props_phx/rt_screen.mdl",
	{
		angle = Angle(-90, 90, 0),
		offset = Vector(6.5, 27.9, 35.3),
		width = 56,
		height = 33
	}
)

local function CubeSY(size) return 47.5*size end
local function CubeSX(size) return 47.6*size end
local function CubePY(size) return 23.725*size end
local function CubePX(size) return -(23.76*size) end


local function newScreen(x,y)
	local x_ = x == 0.25 and "025" or (x == 0.5 and "05" or (x == 0.75 and "075" or x))
	local y_ = y == 0.25 and "025" or (y == 0.5 and "05" or (y == 0.75 and "075" or y))
	local xt = (x < 10 and x >= 1) and string.format("0%s",x) or x
	local yt = (y < 10 and y >= 1) and string.format("0%s",y) or y
	local s = x <= 1 and "Petit Ecran" or (x <= 5 and "Ecran Moyen" or (x <= 8 and "Grand Ecran" or "Ecran Géant"))

	AddMediaPlayerModel(
		string.format("../spawnicons/models/hunter/plates/plate%sx%s",x_,y_),
		string.format("%s %sx%s",s,xt,yt),
		string.format("models/hunter/plates/plate%sx%s.mdl",x_,y_),
		{
			angle = Angle(0, 90, 0),
			offset = Vector(CubePX(x), CubePY(y), 2.5),
			width = CubeSY(y),
			height = CubeSX(x)
		}
	)
end

local function Screens()
	local i = 0.25
	local i_i = 0.25
	while(i <= 32) do
		i_i = i >= 1 and (i >= 8 and 8 or 1) or 0.25
		local j = 0.25
		local j_i = 0.25
		while(j <= 32) do
			j_i = j >= 1 and (j >= 8 and 8 or 1) or 0.25
			if(j >= i) then newScreen(i,j) end
			j = j + j_i
		end
		i = i + i_i
	end
end

Screens()




if SERVER then

	-- fix for media player owner not getting set on alternate model spawn
	hook.Add( "PlayerSpawnedSENT", "MediaPlayer.SetOwner", function(ply, ent)
		if not ent.IsMediaPlayerEntity then return end
		ent:SetCreator(ply)
		local mp = ent:GetMediaPlayer()
		if mp.SetOwner then
			mp:SetOwner(ply)
		else
			ErrorNoHalt("[MediaPlayer] ",ply," ",ent," Tried to SetOwner on "..tostring(mp).." but no .SetOwner\n")
		end
	end )

end
