local modname = minetest.get_current_modname()
local storage = minetest.get_mod_storage()
local S = minetest.get_translator("lmz_opening_hours")

opening_hours = {}

local opening_hours_default = {
	version = 2,
	day0_start_hour = 8,
	day0_start_minute = 0,
	day0_end_hour = 21,
	day0_end_minute = 0,
	day1_start_hour = 14,
	day1_start_minute = 0,
	day1_end_hour = 21,
	day1_end_minute = 0,
	day2_start_hour = 14,
	day2_start_minute = 0,
	day2_end_hour = 21,
	day2_end_minute = 0,
	day3_start_hour = 14,
	day3_start_minute = 0,
	day3_end_hour = 21,
	day3_end_minute = 0,
	day4_start_hour = 14,
	day4_start_minute = 0,
	day4_end_hour = 21,
	day4_end_minute = 0,
	day5_start_hour = 14,
	day5_start_minute = 0,
	day5_end_hour = 21,
	day5_end_minute = 0,
	day6_start_hour = 8,
	day6_start_minute = 0,
	day6_end_hour = 21,
	day6_end_minute = 0,
	warn_offset = 15,
	warn_interval = 5
}

local warn_cooldown = 0

local function get_date()
	return os.date("*t")
end

local function get_date_formated()
	return os.date("%d.%m.%y")
end

local function upgrade_configuration(old)
	local new = {
		version = 2,
		day0_start_hour = tonumber(old.weekend_start),
		day0_start_minute = 0,
		day0_end_hour = tonumber(old.weekend_end),
		day0_end_minute = 0,
		day1_start_hour = tonumber(old.weekday_start),
		day1_start_minute = 0,
		day1_end_hour = tonumber(old.weekday_end),
		day1_end_minute = 0,
		day2_start_hour = tonumber(old.weekday_start),
		day2_start_minute = 0,
		day2_end_hour = tonumber(old.weekday_end),
		day2_end_minute = 0,
		day3_start_hour = tonumber(old.weekday_start),
		day3_start_minute = 0,
		day3_end_hour = tonumber(old.weekday_end),
		day3_end_minute = 0,
		day4_start_hour = tonumber(old.weekday_start),
		day4_start_minute = 0,
		day4_end_hour = tonumber(old.weekday_end),
		day4_end_minute = 0,
		day5_start_hour = tonumber(old.weekday_start),
		day5_start_minute = 0,
		day5_end_hour = tonumber(old.weekday_end),
		day5_end_minute = 0,
		day6_start_hour = tonumber(old.weekend_start),
		day6_start_minute = 0,
		day6_end_hour = tonumber(old.weekend_end),
		day6_end_minute = 0,
		warn_offset = tonumber(old.warn_offset),
		warn_interval = tonumber(old.warn_interval)
	}
	if old.today then
		new.exception_today = old.today
		new.exception_start_hour = old.today_start
		new.exception_start_minute = 0
		new.exception_end_hour = old.today_end
		new.exception_end_minute = 0
	end
	return new
end

local function save_data()
	storage:from_table({fields = opening_hours})
end

local function load_data()
	opening_hours = storage:to_table().fields
	if opening_hours.weekday_start then
		opening_hours = upgrade_configuration(opening_hours)
	elseif not opening_hours.version then
		opening_hours = opening_hours_default
	end
end

local function reset_execption()
	opening_hours.exception_today = nil
end

local function opening_today()
	local exception = opening_hours.exception_today
	local day_key
	if exception and exception == get_date_formated() then
		day_key = "exception"
	else
		local d = os.date("%w")
		day_key = "day" .. d
	end
	return {
		start_hour = opening_hours[day_key .. "_start_hour"],
		start_minute = opening_hours[day_key .. "_start_minute"],
		end_hour = opening_hours[day_key .. "_end_hour"],
		end_minute = opening_hours[day_key .. "_end_minute"]
	}
end

local function create_exception()
	local today = opening_today()
	opening_hours.exception_today = get_date_formated()
	opening_hours.exception_start_hour = today.start_hour
	opening_hours.exception_start_minute = today.start_minute
	opening_hours.exception_end_hour = today.end_hour
	opening_hours.exception_end_minute = today.end_minute
end

local function tick(dtime)
	local d = get_date()
	local exception = opening_hours.exception_today
	if exception and exception ~= get_date_formated() then
		reset_execption()
	end
	local today = opening_today()
	local end_time = today.end_hour * 60 + today.end_minute
	local now_time = d.hour * 60 + d.min
	local minutes_remaining = end_time - now_time
	if 0 < minutes_remaining
	and minutes_remaining <= opening_hours.warn_offset then
		if warn_cooldown <= 0 then
			minetest.chat_send_all(minetest.colorize("#FF4D00", S("The server will close in @1 minutes.", minutes_remaining)))
			warn_cooldown = tonumber(opening_hours.warn_interval) * 60
		else
			warn_cooldown = warn_cooldown - dtime
		end
	elseif minutes_remaining <= 0 then
		for _, player in pairs(minetest.get_connected_players()) do
			local name = player:get_player_name()
			if not minetest.check_player_privs(name, {server = true}) then
				minetest.kick_player(name, S("The server is closing!"))
			end
		end
	end
end

local function on_join(name)
	if minetest.check_player_privs(name, {server = true}) then return end
	local today = opening_today()
 	local d = get_date()
	local start_time = today.start_hour * 60 + today.start_minute
	local end_time = today.end_hour * 60 + today.end_minute
	local now_time = d.hour * 60 + d.min
	local diff = start_time - now_time
	if diff > 0 then
		return S("You visited outside of the opening hours") .. ". " .. S("The server will open again in @1 hours", math.ceil(diff / 60)) .. "."
	elseif end_time <= now_time then
		return S("You visited outside of the opening hours") .. ". " .. S("The server has already closed and will open again tomorrow") .. "."
	end
end

local minute_step = 5

local function show_gui(name)
	local fld_w = 0.88
	local fld_h = 0.82429501084599
	local fld_sz = fld_w .. "," .. fld_h
	local inline_off = 0.2427394885132
	local lab_close_y = 6.3935847420893
	local fld_close_y = lab_close_y + 0.2427394885132
	local pre_colon_off = 0.4
	local minute_off = 0.04
	local to_off = 1.24
	local day_off = 3.6
	local x = {
		day1 = {}
	}
	x.day1.lab = 0.1
	x.day1.fld_f_hour = 0.64
	x.day1.fld_f_minute = x.day1.fld_f_hour + fld_w - minute_off
	x.day1.lab_f_colon = x.day1.fld_f_minute - pre_colon_off
	x.day1.fld_t_hour = x.day1.lab_f_colon + to_off
	x.day1.fld_t_minute = x.day1.fld_t_hour + fld_w - minute_off
	x.day1.lab_t_colon = x.day1.fld_t_minute - pre_colon_off
	local last
	for day = 1, 5, 1 do
		if last then
			x["day" .. day] = {}
			for k, v in pairs(x["day" .. last]) do
				x["day" .. day][k] = v + day_off
			end
		end
		last = day
	end
	local below_off = 1.1530125704378
	local lab_b_y = 0.28175119202427
	local fld_b_y = lab_b_y + below_off
	local lab_b_colon_y = fld_b_y - inline_off
	local lab_w_y = 2.0156046814044
	local fld_w_y = lab_w_y + below_off
	local lab_w_colon_y = fld_w_y - inline_off
	local lab_e_y = 3.7494581707846
	local fld_e_y = lab_e_y + below_off
	local lab_e_colon_y = fld_e_y - inline_off
	local o = opening_hours
	local day_abbreviations = {
		[0] = S("Su."),
		[1] = S("Mo."),
		[2] = S("Tu."),
		[3] = S("We."),
		[4] = S("Th."),
		[5] = S("Fr."),
		[6] = S("Sa.")
	}
	local formspec_business_days = ""
	for day = 1, 5, 1 do
		formspec_business_days = formspec_business_days
		.. "label[" .. x["day" .. day].lab .. "," .. lab_b_y .. ";" .. day_abbreviations[day] .. "]"
		.. "field[" .. x["day" .. day].fld_f_hour .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day" .. day .. "_start_hour;" .. S("from") .. ";" .. string.format("%02d", o["day" .. day .. "_start_hour"]) .. "]"
		.. "label[" .. x["day" .. day].lab_f_colon .. "," .. lab_b_colon_y .. ";:]"
		.. "field[" .. x["day" .. day].fld_f_minute .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day" .. day .. "_start_minute;;" .. string.format("%02d", o["day" .. day .. "_start_minute"]) .. "]"
		.. "field[" .. x["day" .. day].fld_t_hour .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day" .. day .. "_end_hour;" .. S("to") .. ";" .. string.format("%02d", o["day" .. day .. "_end_hour"]) .. "]"
		.. "label[" .. x["day" .. day].lab_t_colon .. "," .. lab_b_colon_y .. ";:]"
		.. "field[" .. x["day" .. day].fld_t_minute .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day" .. day .. "_end_minute;;" .. string.format("%02d", o["day" .. day .. "_end_minute"]) .. "]"
	end
	local formspec_weekend = ""
	for col = 1, 2, 1 do
		day = (5 + col) % 7
		formspec_weekend = formspec_weekend
		.. "label[" .. x["day" .. col].lab .. "," .. lab_w_y .. ";" .. day_abbreviations[day] .. "]"
		.. "field[" .. x["day" .. col].fld_f_hour .. "," .. fld_w_y .. ";" .. fld_sz .. ";fld_day" .. day .. "_start_hour;" .. S("from") .. ";" .. string.format("%02d", o["day" .. day .. "_start_hour"]) .. "]"
		.. "label[" .. x["day" .. col].lab_f_colon .. "," .. lab_w_colon_y .. ";:]"
		.. "field[" .. x["day" .. col].fld_f_minute .. "," .. fld_w_y .. ";" .. fld_sz .. ";fld_day" .. day .. "_start_minute;;" .. string.format("%02d", o["day" .. day .. "_start_minute"]) .. "]"
		.. "field[" .. x["day" .. col].fld_t_hour .. "," .. fld_w_y .. ";" .. fld_sz .. ";fld_day" .. day .. "_end_hour;" .. S("to") .. ";" .. string.format("%02d", o["day" .. day .. "_end_hour"]) .. "]"
		.. "label[" .. x["day" .. col].lab_t_colon .. "," .. lab_w_colon_y .. ";:]"
		.. "field[" .. x["day" .. col].fld_t_minute .. "," .. fld_w_y .. ";" .. fld_sz .. ";fld_day" .. day .. "_end_minute;;" .. string.format("%02d", o["day" .. day .. "_end_minute"]) .. "]"
	end
	local formspec_exception = (o.exception_today
			and ""
				.. "label[" .. x.day1.lab .. "," .. lab_e_y .. ";" .. S("Today") .. "]"
				.. "field[" .. x.day1.fld_f_hour .. "," .. fld_e_y .. ";" .. fld_sz .. ";fld_exception_start_hour;" .. S("from") .. ";" .. string.format("%02d", o.exception_start_hour) .. "]"
				.. "label[" .. x.day1.lab_f_colon .. "," .. lab_e_colon_y .. ";:]"
				.. "field[" .. x.day1.fld_f_minute .. "," .. fld_e_y .. ";" .. fld_sz .. ";fld_exception_start_minute;;" .. string.format("%02d", o.exception_start_minute) .. "]"
				.. "field[" .. x.day1.fld_t_hour .. "," .. fld_e_y .. ";" .. fld_sz .. ";fld_exception_end_hour;" .. S("to") .. ";" .. string.format("%02d", o.exception_end_hour) .. "]"
				.. "label[" .. x.day1.lab_t_colon .. "," .. lab_e_colon_y .. ";:]"
				.. "field[" .. x.day1.fld_t_minute .. "," .. fld_e_y .. ";" .. fld_sz .. ";fld_exception_end_minute;;" .. string.format("%02d", o.exception_end_minute) .. "]"
			or "image_button[0.34,4.5296922410056;4.205,0.7835;;add_exception;" .. S("Add exception") .. "]"
		)
	local formspec = "size[18.01,7.9267895878525]"
	.. "label[-0.14,-0.23840485478977;" .. S("Opening hours") .. "]"
	.. formspec_business_days
	.. formspec_weekend
	.. formspec_exception
	.. "label[" .. x.day1.lab .. ",5.4833116601647;" .. S("Settings") .. "]"
	.. "label[0.34," .. lab_close_y .. ";Spieler ]"
	.. "field[1.6," .. fld_close_y .. ";" .. fld_sz .. ";fld_warn_offset;;" .. o.warn_offset .. "]"
	.. "label[2.18," .. lab_close_y .. ";Minuten vor Ablauf der Zeit alle]"
	.. "field[6.0," .. fld_close_y .. ";" .. fld_sz .. ";fld_warn_interval;;" .. o.warn_interval .. "]"
	.. "label[6.6," .. lab_close_y .. ";Minuten warnen.]"
	.. "image_button[5.14,7.6072821846554;2.605,0.7835;;save;Speichern]"
	.. "image_button_exit[7.62,7.6072821846554;2.605,0.7835;;close;Schließen]"
	minetest.show_formspec(name, "lmz_opening_hours:gui", formspec)
end

local function progress_gui_input(player, formname, fields)
	local name = player:get_player_name()
	if formname ~= "lmz_opening_hours:gui" or not minetest.check_player_privs(name, {server = true}) then return end
	if fields.add_exception then
		create_exception()
	end
	for k, v in pairs(fields) do
		if k:sub(1, 4) == "fld_" then
			local field = k:gsub("fld_", "")
			local old = opening_hours[field]
			opening_hours[field] = tonumber(v) or old
		end
	end
	for k, v in pairs(opening_hours) do
		if k:match("_hour$") then
			opening_hours[k] = math.max(0, math.min(23, v))
		elseif k:match("_minute$") then
			opening_hours[k] = math.max(
				0,
				math.min(
					60 - minute_step,
					minute_step * math.floor(
						v / minute_step + 0.5
					)
				)
			)
		end
	end
	for k, v in pairs(opening_hours) do
		if k:match("_end_hour$") then
			local start = opening_hours[k:gsub("_end_", "_start_")]
			if start > v then
				opening_hours[k] = start
			end
		elseif k:match("_end_minute$") then
			local hour_k = k:gsub("_minute$", "_hour")
			local hour_start_k = hour_k:gsub("_end_", "_start_")
			local start_k = k:gsub("_end_", "_start_")
			if opening_hours[hour_start_k] >= opening_hours[hour_k]
			and opening_hours[start_k] > v then
				opening_hours[k] = opening_hours[start_k]
			end
		end
	end
	if not fields.quit and not fields.close then show_gui(name) end
end

load_data()

minetest.register_globalstep(tick)
minetest.register_on_shutdown(save_data)
minetest.register_on_prejoinplayer(on_join)
minetest.register_chatcommand(
	"opening_hours",
	{
		privs = {server = true},
		description = S("Configure the opening hours"),
		func = show_gui
	}
)
minetest.register_chatcommand(
	"öffnungszeiten",
	{
		privs = {server = true},
		description = S("Configure the opening hours"),
		func = show_gui
	}
)
minetest.register_on_player_receive_fields(progress_gui_input)


