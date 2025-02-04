if SERVER then AddCSLuaFile() end

local file = file
local math = math
local urllib = url
local ceil = math.ceil
local floor = math.floor
local Round = math.Round
local log = math.log
local pow = math.pow
local format = string.format
local tostring = tostring
local IsValid = IsValid


local utils = {}

---
-- Ceil the given number to the largest power of two.
--
function utils.CeilPower2(n)
	return pow(2, ceil(log(n) / log(2)))
end

---
-- Method for easily grabbing a value from a table without checking that each
-- fragment exists.
--
-- @param tbl Table
-- @param key e.g. "json.key.fragments"
--
function utils.TableLookup( tbl, key )
	local fragments = string.Split(key, '.')
	local value = tbl

	for _, fragment in ipairs(fragments) do
		value = value[fragment]

		if not value then
			return nil
		end
	end

	return value
end

---
-- Formats the number of seconds to a string.
-- e.g. 3612 => 24:12
--
function utils.FormatSeconds(sec)
	sec = Round(sec)

	local hours = floor(sec / 3600)
	local minutes = floor((sec % 3600) / 60)
	local seconds = sec % 60

	if minutes < 10 then
		minutes = "0" .. tostring(minutes)
	end

	if seconds < 10 then
		seconds = "0" .. tostring(seconds)
	end

	if hours > 0 then
		return format("%s:%s:%s", hours, minutes, seconds)
	else
		return format("%s:%s", minutes, seconds)
	end
end

-- https://github.com/xfbs/PiL3/blob/master/18MathLibrary/shuffle.lua
function utils.Shuffle(list)
    -- make and fill array of indices
    local indices = {}
    for i = 1, #list do
        indices[#indices+1] = i
    end

    -- create shuffled list
    local shuffled = {}
    for i = 1, #list do
        -- get a random index
        local index = math.random(#indices)

        -- get the value
        local value = list[indices[index]]

        -- remove it from the list so it won't be used again
        table.remove(indices, index)

        -- insert into shuffled array
        shuffled[#shuffled+1] = value
    end

    return shuffled
end

function utils.Retry( func, success, error, maxAttempts )

	maxAttempts = maxAttempts or 3
	local attempts = 1

	local function callback( value )
		if value then
			success( value )
		elseif attempts < maxAttempts then
			attempts = attempts + 1
			func( callback )
		else
			error()
		end
	end

	func( callback )

end

local function setTimeout( func, wait )
	local timerID = tostring( func )
	timer.Create( timerID, wait, 1, func )
	timer.Start( timerID )
	return timerID
end

local function clearTimeout( timerID )
	if timer.Exists( timerID ) then
		timer.Destroy( timerID )
	end
end

-- based on underscore.js' _.throttle function
function utils.Throttle( func, wait, options )
	wait = wait or 1
	options = options or {}

	local timeout, args, result
	local previous

	local function later()
		previous = (options.leading == false) and 0 or RealTime()
		timeout = nil
		result = func( unpack(args) )
		if not timeout then
			args = nil
		end
	end

	local function throttled(...)
		local now = RealTime()
		if not previous then
			previous = now
		end

		local remaining = wait - (now - previous)

		args = {...}

		if remaining <= 0 or remaining > wait then
			if timeout then
				clearTimeout(timeout)
				timeout = nil
			end

			previous = now
			result = func( unpack(args) )

			if not timeout then
				args = nil
			end
		elseif not timeout and options.trailing ~= false then
			timeout = setTimeout(later, remaining)
		end

		return result
	end

	return throttled
end

if CLIENT then

	local CeilPower2 = utils.CeilPower2
	local SetDrawColor = surface.SetDrawColor
	local SetMaterial = surface.SetMaterial
	local DrawTexturedRect = surface.DrawTexturedRect
	local DrawRect = surface.DrawRect

	local color_white = color_white

	function utils.DrawHTMLPanel( panel, w, h )
		if not (IsValid( panel ) and w and h) then return end

		panel:UpdateHTMLTexture()

		local pw, ph = panel:GetSize()

		-- Convert to scalar
		w = w / pw
		h = h / ph

		-- Fix for non-power-of-two html panel size
		pw = CeilPower2(pw)
		ph = CeilPower2(ph)

		SetDrawColor( color_white )

		local mat = panel:GetHTMLMaterial()

		if mat then
			SetMaterial( mat )
			DrawTexturedRect( 0, 0, w * pw, h * ph )
		else
			DrawRect( 0, 0, w * pw, h * ph )
		end
	end

	function utils.ParseHHMMSS( time )
	    local tbl = {}

		-- insert fragments in reverse
		for fragment, _ in string.gmatch(time, ":?(%d+)") do
			table.insert(tbl, 1, tonumber(fragment) or 0)
		end

		if #tbl == 0 then
			return nil
		end

		local seconds = 0

		for i = 1, #tbl do
			seconds = seconds + tbl[i] * math.max(60 ^ (i-1), 1)
		end

		return seconds
	end

	---
	-- Attempts to play uri from stream or local file and returns channel in
	-- callback.
	--
	function utils.LoadStreamChannel(uri, options, callback)
		local isLocalFile = false

		-- Play uri from a local file if:
		-- 1. Windows OS and path contains drive letter
		-- 2. Linux or OS X and path starts with a single '/'
		--
		-- We can't check this using file.Exists since GMod only allows checking
		-- within the GMod directory. However, sound.PlayFile will still load
		-- a file from any directory.
		if (system.IsWindows() and uri:find("^%w:/")) or (not system.IsWindows() and uri:find("^/[^/]")) then
			isLocalFile = true
			local success, decoded = pcall(urllib.unescape, uri)

			if success then
				uri = decoded
			end
		end

		local playFunc = isLocalFile and sound.PlayFile or sound.PlayURL

		playFunc(uri, options or "noplay", function(channel)
			if IsValid(channel) then
				local channel_ensured = utils.BassEnsurePlayback(channel)
				assert(IsValid(channel_ensured))
				callback(channel_ensured)
			else
				callback(nil)
			end
		end)
	end

	local DEBUG = false

	local channels = utils.GetEnsuredPlayers and utils.GetEnsuredPlayers() or setmetatable({}, {
		__mode = 'k'
	})

	function utils.GetEnsuredPlayers()
		return channels
	end

	if DEBUG then
		table.Empty(utils.GetEnsuredPlayers())
	end

	local WRAPPERS = {}

	local MT = {
		__tostring = function(self) return "EnsureWrapped: " .. tostring(self.__channel__) end
	}

	local IGModAudioChannel = FindMetaTable"IGModAudioChannel"

	function MT:__index(k)
		local f = WRAPPERS[k]
		if f ~= nil then return f end

		local function wrapper(me, ...)
			return IGModAudioChannel[k](me.__channel__, ...)
		end

		WRAPPERS[k] = wrapper

		return wrapper
	end

	function WRAPPERS:Play(...)
		local channel = self.__channel__
		channels[channel] = true

		return IGModAudioChannel.Play(channel, ...)
	end

	function WRAPPERS:Stop(...)
		local channel = self.__channel__
		channels[channel] = nil

		return IGModAudioChannel.Stop(channel, ...)
	end

	function WRAPPERS:Pause(...)
		local channel = self.__channel__
		channels[channel] = nil

		return IGModAudioChannel.Pause(channel, ...)
	end

	--MediaPlayer.Cvars.EnsurePlayback
	local EnsurePlayback = CreateClientConVar("mediaplayer_force_playback", '1', true, false)

	local function process()
		if not EnsurePlayback:GetBool() then return end

		if not next(channels) then
			timer.Exists"MP_BassEnsurePlayback"
		end

		for channel, inited in pairs(channels) do
			if channel:IsValid() then
				local stopped = channel:GetState() == GMOD_CHANNEL_STOPPED

				if DEBUG then
					print(channel, "inited=", inited, "stopped=", stopped)
				end

				if not inited and not stopped then
					channels[channel] = true
				elseif inited and stopped then
					channel:Play()
					print("Forcing playback for", channel)
				end
			else
				channels[channel] = nil
			end
		end
	end

	concommand.Add("stopsound_mediplayer_bass", function()
		for channel, inited in pairs(channels) do
			if channel:IsValid() then
				channels[channel] = nil
				channel:Stop()
				print("Stopped", channel)
			else
				channels[channel] = nil
			end
		end
	end)

	function utils.BassEnsurePlayback(channel, remove)
		if remove == true then
			channels[channel] = nil

			return
		end

		channels[channel] = false

		if DEBUG or not timer.Exists"MP_BassEnsurePlayback" then
			timer.Create("MP_BassEnsurePlayback", DEBUG and 3.123 or 0.351, 0, process)
		end

		local wrapped = setmetatable({
			__channel__ = channel,
			channel = channel,
			__wrappers = WRAPPERS
		}, MT)

		if DEBUG then
			print("Wrapping to ensure playback", channel, "->", wrapped)
		end

		return wrapped
	end

	if DEBUG then
		sound.PlayURL("https://www.happyhardcore.com/livestreams/p/u9/", "noplay", function(a, ...)
			local asd = MediaPlayerUtils.BassEnsurePlayback(a)
			print(asd == nil, asd)
			_G.asd = asd
		end)
	end
end

_G.MediaPlayerUtils = utils
