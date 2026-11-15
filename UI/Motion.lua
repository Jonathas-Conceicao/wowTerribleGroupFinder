-------------------------------------------------------------------------------
--  UI/Motion.lua -- the row animations of a Dynamic refresh (ns.Motion).
--
--  Rows of listings that left swipe out (left, fade), the list updates, then the rows below
--  a removed one slide up from where they were while new rows swipe in (from the right,
--  fade). Every animation is an AnimationGroup of Translation and Alpha only: render-time
--  offsets that never move a pooled row's anchors, so the ScrollBox keeps its own layout.
--  A slide is found by recording each shown row's GetTop() by listing key before the update
--  and playing from the old offset after it. Rows filtered out or in a collapsed section
--  have no frame, so they just change.
--
--  The game's refresh (UI/InPlace.lua) and the preview's simulated one share Motion.Show.
--  With the swipeAnimations setting off the list updates in place, with no animation.
-------------------------------------------------------------------------------
local _, ns = ...

local M = {}
ns.Motion = M

M.SWIPE_OUT = 0.4 -- seconds a leaving row takes to swipe out (the wait before the list updates)
M.SWIPE_IN = 0.4 -- seconds a new row takes to swipe in
M.SLIDE = 0.3 -- seconds a row takes to slide to its new place
M.SWIPE_X = 40 -- pixels a swipe travels
M.SMOOTHING = "OUT"
M.MIN_DELTA = 1 -- pixels a row must have moved to slide

local abs = math.abs

local busy = false -- a swipe-out is playing: the rows still hold the old results
local token = 0 -- bumped by every Show and Cancel; a timer of an older one does nothing
local pending -- the update waiting on the swipe-out timer: function(animate)
local tops -- instance -> key -> GetTop() before the update
local onUpdated = {} -- functions called after every Show's update (M.OnUpdated)

--- Adds fn(), called once the list is updated by any Show (after its own `after`).
function M.OnUpdated(fn)
	if type(fn) == "function" then
		onUpdated[#onUpdated + 1] = fn
	end
end

--- Whether the rows animate (the swipeAnimations setting, read every time).
function M.Enabled()
	return ns.Settings.Get("swipeAnimations") ~= false
end

--- A shown item's key: a section header, your own row, or a listing (ns.Listings.Key).
function M.KeyOf(item)
	if not item then
		return nil
	end
	if item.header then
		return "h:" .. item.key
	end
	if item.mine then
		return "mine"
	end
	return ns.Listings.Key(item)
end

--- The set of listing keys of an array of listings (your own listing left out).
function M.Keys(listings)
	local keys = {}
	for _, l in ipairs(listings or {}) do
		if not l.mine then
			keys[ns.Listings.Key(l)] = true
		end
	end
	return keys
end

--- A row or header frame back to rest: animations stopped, fully visible. Anchors untouched.
function M.ResetRow(frame)
	if not frame then
		return
	end
	if frame.tgfSwipe then
		frame.tgfSwipe:Stop()
	end
	if frame.tgfSlide then
		frame.tgfSlide:Stop()
	end
	frame:SetAlpha(1)
end

local function Swipe(frame, out)
	local g = frame.tgfSwipe
	if not g then
		g = frame:CreateAnimationGroup()
		g.shift = g:CreateAnimation("Translation") -- the starting offset (in: from the right)
		g.shift:SetOrder(1)
		g.shift:SetDuration(0)
		g.hold = g:CreateAnimation("Alpha") -- the starting alpha, so a row swiping in never flashes
		g.hold:SetOrder(1)
		g.hold:SetDuration(0)
		g.move = g:CreateAnimation("Translation")
		g.move:SetOrder(2)
		g.move:SetSmoothing(M.SMOOTHING)
		g.fade = g:CreateAnimation("Alpha")
		g.fade:SetOrder(2)
		frame.tgfSwipe = g
	end
	g:Stop()
	local duration = out and M.SWIPE_OUT or M.SWIPE_IN
	g.shift:SetOffset(out and 0 or M.SWIPE_X, 0)
	g.hold:SetFromAlpha(out and 1 or 0)
	g.hold:SetToAlpha(out and 1 or 0)
	g.move:SetDuration(duration)
	g.move:SetOffset(-M.SWIPE_X, 0)
	g.fade:SetDuration(duration)
	g.fade:SetFromAlpha(out and 1 or 0)
	g.fade:SetToAlpha(out and 0 or 1)
	g:SetToFinalAlpha(out) -- a swiped-out row stays hidden until the list updates
	g:Play()
end

-- delta = oldTop - newTop: a row that moved up (screen Y grows upward) has a negative one.
-- Jump back to the old place at once, then glide to the new one; the net offset is zero.
local function Slide(frame, delta)
	local g = frame.tgfSlide
	if not g then
		g = frame:CreateAnimationGroup()
		g.shift = g:CreateAnimation("Translation")
		g.shift:SetOrder(1)
		g.shift:SetDuration(0)
		g.move = g:CreateAnimation("Translation")
		g.move:SetOrder(2)
		g.move:SetSmoothing(M.SMOOTHING)
		frame.tgfSlide = g
	end
	g:Stop()
	g.shift:SetOffset(0, delta)
	g.move:SetDuration(M.SLIDE)
	g.move:SetOffset(0, -delta)
	g:Play()
end

local function Record()
	tops = {}
	ns.Table.ForEachFrame(function(frame, item, inst)
		local key = M.KeyOf(item)
		local top = key and frame.GetTop and frame:GetTop()
		if top then
			tops[inst] = tops[inst] or {}
			tops[inst][key] = top
		end
	end)
end

-- Swipes the shown rows whose listing key is in keys; true when any row played.
local function SwipeRows(keys, out)
	local played = false
	if not next(keys) then
		return false
	end
	ns.Table.ForEachFrame(function(frame, item)
		if item and not item.header and not item.mine and frame.CreateAnimationGroup then
			if keys[ns.Listings.Key(item)] and pcall(Swipe, frame, out) then
				played = true
			end
		end
	end)
	return played
end

--- True while the swipe-out plays (rows still hold the old results: clicks wait).
function M.Busy()
	return busy
end

--- Shows the list as it is now. previousKeys: the set of listing keys shown before; selectedKey:
--- the listing to select again (or nil); after: called once the list is updated.
function M.Show(previousKeys, selectedKey, after)
	M.Cancel() -- a Show waiting on its swipe-out shows its state at once (a new search wins)
	local now = ns.Table.CurrentKeys()
	local went, came = {}, {}
	for key, v in pairs(previousKeys or {}) do
		if v and not now[key] then
			went[key] = true
		end
	end
	for key in pairs(now) do
		if not (previousKeys and previousKeys[key]) then
			came[key] = true
		end
	end

	local function Update(animate)
		ns.Table.SelectKey(selectedKey)
		if animate then
			ns.Table.ForEachFrame(function(frame, item, inst)
				if not frame.CreateAnimationGroup then
					return
				end
				local key = M.KeyOf(item)
				if key and came[key] and not item.header and not item.mine then
					pcall(Swipe, frame, false)
					return
				end
				local old = key and tops and tops[inst] and tops[inst][key]
				local new = old and frame.GetTop and frame:GetTop()
				if new and abs(old - new) >= M.MIN_DELTA then
					pcall(Slide, frame, old - new)
				end
			end)
		end
		tops = nil
		if type(after) == "function" then
			after()
		end
		for _, fn in ipairs(onUpdated) do
			fn()
		end
	end

	if not M.Enabled() then
		return Update(false)
	end
	Record()
	if not SwipeRows(went, true) then
		return Update(true)
	end
	busy = true
	token = token + 1
	local mine = token
	pending = function(animate)
		busy = false
		pending = nil
		Update(animate)
	end
	C_Timer.After(M.SWIPE_OUT, function()
		if token == mine and pending then
			pending(true)
		end
	end)
end

--- Ends a swipe-out that is waiting: the new list shows at once, with no slide or swipe-in.
--- True when there was one.
function M.Cancel()
	if not pending then
		return false
	end
	token = token + 1
	local run = pending
	ns.Table.ForEachFrame(function(frame)
		M.ResetRow(frame)
	end)
	run(false)
	return true
end

-- Animations turned off during a swipe-out: the list shows its new state at once.
ns.Settings.OnChange("swipeAnimations", function()
	M.Cancel()
end)
