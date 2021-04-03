local modname = minetest.get_current_modname()
local storage = minetest.get_mod_storage()

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
			minetest.chat_send_all(minetest.colorize("#FF4D00", "Der Server schießt in " .. minutes_remaining .. " Minuten."))
			warn_cooldown = tonumber(opening_hours.warn_interval) * 60
		else
			warn_cooldown = warn_cooldown - dtime
		end
	elseif minutes_remaining <= 0 then
		for _, player in pairs(minetest.get_connected_players()) do
			local name = player:get_player_name()
			if not minetest.check_player_privs(name, {server = true}) then
				minetest.kick_player(name, "Der Server schließt!")
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
		return "Besuch erfolgte außerhalb der Öffnungszeiten. Der Server hat in " .. math.ceil(diff / 60) .. " Stunde(n) wieder geöffnet."
	elseif end_time <= now_time then
		return "Besuch erfolgte außerhalb der Öffnungszeiten. Der Server hat bereits geschlossen und hat Morgen wieder geöffnet."
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
	local lab_day1_x = 0.1
	local fld_day1_f_hour_x = 0.64
	local fld_day1_f_minute_x = fld_day1_f_hour_x + fld_w - minute_off
	local lab_day1_f_colon_x = fld_day1_f_minute_x - pre_colon_off
	local fld_day1_t_hour_x = lab_day1_f_colon_x + to_off
	local fld_day1_t_minute_x = fld_day1_t_hour_x + fld_w - minute_off
	local lab_day1_t_colon_x = fld_day1_t_minute_x - pre_colon_off
	local lab_day2_x = lab_day1_x + day_off
	local fld_day2_f_hour_x = fld_day1_f_hour_x + day_off
	local fld_day2_f_minute_x = fld_day1_f_minute_x + day_off
	local lab_day2_f_colon_x = lab_day1_f_colon_x + day_off
	local fld_day2_t_hour_x = fld_day1_t_hour_x + day_off
	local fld_day2_t_minute_x = fld_day1_t_minute_x + day_off
	local lab_day2_t_colon_x = lab_day1_t_colon_x + day_off
	local lab_day3_x = lab_day2_x + day_off
	local fld_day3_f_hour_x = fld_day2_f_hour_x + day_off
	local fld_day3_f_minute_x = fld_day2_f_minute_x + day_off
	local lab_day3_f_colon_x = lab_day2_f_colon_x + day_off
	local fld_day3_t_hour_x = fld_day2_t_hour_x + day_off
	local fld_day3_t_minute_x = fld_day2_t_minute_x + day_off
	local lab_day3_t_colon_x = lab_day2_t_colon_x + day_off
	local lab_day4_x = lab_day3_x + day_off
	local fld_day4_f_hour_x = fld_day3_f_hour_x + day_off
	local fld_day4_f_minute_x = fld_day3_f_minute_x + day_off
	local lab_day4_f_colon_x = lab_day3_f_colon_x + day_off
	local fld_day4_t_hour_x = fld_day3_t_hour_x + day_off
	local fld_day4_t_minute_x = fld_day3_t_minute_x + day_off
	local lab_day4_t_colon_x = lab_day3_t_colon_x + day_off
	local lab_day5_x = lab_day4_x + day_off
	local fld_day5_f_hour_x = fld_day4_f_hour_x + day_off
	local fld_day5_f_minute_x = fld_day4_f_minute_x + day_off
	local lab_day5_f_colon_x = lab_day4_f_colon_x + day_off
	local fld_day5_t_hour_x = fld_day4_t_hour_x + day_off
	local fld_day5_t_minute_x = fld_day4_t_minute_x + day_off
	local lab_day5_t_colon_x = lab_day4_t_colon_x + day_off
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
	local formspec_day1 = ""
	.. "label[" .. lab_day1_x .. "," .. lab_b_y .. ";Mo.]"
	.. "field[" .. fld_day1_f_hour_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day1_start_hour;von;" .. string.format("%02d", o.day1_start_hour) .. "]"
	.. "label[" .. lab_day1_f_colon_x .. "," .. lab_b_colon_y .. ";:]"
	.. "field[" .. fld_day1_f_minute_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day1_start_minute;;" .. string.format("%02d", o.day1_start_minute) .. "]"
	.. "field[" .. fld_day1_t_hour_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day1_end_hour;bis;" .. string.format("%02d", o.day1_end_hour) .. "]"
	.. "label[" .. lab_day1_t_colon_x .. "," .. lab_b_colon_y .. ";:]"
	.. "field[" .. fld_day1_t_minute_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day1_end_minute;;" .. string.format("%02d", o.day1_end_minute) .. "]"
	local formspec_day2 = ""
	.. "label[" .. lab_day2_x .. "," .. lab_b_y .. ";Di.]"
	.. "field[" .. fld_day2_f_hour_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day2_start_hour;von;" .. string.format("%02d", o.day2_start_hour) .. "]"
	.. "label[" .. lab_day2_f_colon_x .. "," .. lab_b_colon_y .. ";:]"
	.. "field[" .. fld_day2_f_minute_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day2_start_minute;;" .. string.format("%02d", o.day2_start_minute) .. "]"
	.. "field[" .. fld_day2_t_hour_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day2_end_hour;bis;" .. string.format("%02d", o.day2_end_hour) .. "]"
	.. "label[" .. lab_day2_t_colon_x .. "," .. lab_b_colon_y .. ";:]"
	.. "field[" .. fld_day2_t_minute_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day2_end_minute;;" .. string.format("%02d", o.day2_end_minute) .. "]"
	local formspec_day3 = ""
	.. "label[" .. lab_day3_x .. "," .. lab_b_y .. ";Mi.]"
	.. "field[" .. fld_day3_f_hour_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day3_start_hour;von;" .. string.format("%02d", o.day3_start_hour) .. "]"
	.. "label[" .. lab_day3_f_colon_x .. "," .. lab_b_colon_y .. ";:]"
	.. "field[" .. fld_day3_f_minute_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day3_start_minute;;" .. string.format("%02d", o.day3_start_minute) .. "]"
	.. "field[" .. fld_day3_t_hour_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day3_end_hour;bis;" .. string.format("%02d", o.day3_end_hour) .. "]"
	.. "label[" .. lab_day3_t_colon_x .. "," .. lab_b_colon_y .. ";:]"
	.. "field[" .. fld_day3_t_minute_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day3_end_minute;;" .. string.format("%02d", o.day3_end_minute) .. "]"
	local formspec_day4 = ""
	.. "label[" .. lab_day4_x .. "," .. lab_b_y .. ";Do.]"
	.. "field[" .. fld_day4_f_hour_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day4_start_hour;von;" .. string.format("%02d", o.day4_start_hour) .. "]"
	.. "label[" .. lab_day4_f_colon_x .. "," .. lab_b_colon_y .. ";:]"
	.. "field[" .. fld_day4_f_minute_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day4_start_minute;;" .. string.format("%02d", o.day4_start_minute) .. "]"
	.. "field[" .. fld_day4_t_hour_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day4_end_hour;bis;" .. string.format("%02d", o.day4_end_hour) .. "]"
	.. "label[" .. lab_day4_t_colon_x .. "," .. lab_b_colon_y .. ";:]"
	.. "field[" .. fld_day4_t_minute_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day4_end_minute;;" .. string.format("%02d", o.day4_end_minute) .. "]"
	local formspec_day5 = ""
	.. "label[" .. lab_day5_x .. "," .. lab_b_y .. ";Fr.]"
	.. "field[" .. fld_day5_f_hour_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day5_start_hour;von;" .. string.format("%02d", o.day5_start_hour) .. "]"
	.. "label[" .. lab_day5_f_colon_x .. "," .. lab_b_colon_y .. ";:]"
	.. "field[" .. fld_day5_f_minute_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day5_start_minute;;" .. string.format("%02d", o.day5_start_minute) .. "]"
	.. "field[" .. fld_day5_t_hour_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day5_end_hour;bis;" .. string.format("%02d", o.day5_end_hour) .. "]"
	.. "label[" .. lab_day5_t_colon_x .. "," .. lab_b_colon_y .. ";:]"
	.. "field[" .. fld_day5_t_minute_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day5_end_minute;;" .. string.format("%02d", o.day5_end_minute) .. "]"
	local formspec_business_days = ""
	.. formspec_day1
	.. formspec_day2
	.. formspec_day3
	.. formspec_day4
	.. formspec_day5
	local formspec_day6 = ""
	.. "label[" .. lab_day1_x .. "," .. lab_w_y .. ";Sa.]"
	.. "field[" .. fld_day1_f_hour_x .. "," .. fld_w_y .. ";" .. fld_sz .. ";fld_day6_start_hour;von;" .. string.format("%02d", o.day6_start_hour) .. "]"
	.. "label[" .. lab_day1_f_colon_x .. "," .. lab_w_colon_y .. ";:]"
	.. "field[" .. fld_day1_f_minute_x .. "," .. fld_w_y .. ";" .. fld_sz .. ";fld_day6_start_minute;;" .. string.format("%02d", o.day6_start_minute) .. "]"
	.. "field[" .. fld_day1_t_hour_x .. "," .. fld_w_y .. ";" .. fld_sz .. ";fld_day6_end_hour;bis;" .. string.format("%02d", o.day6_end_hour) .. "]"
	.. "label[" .. lab_day1_t_colon_x .. "," .. lab_w_colon_y .. ";:]"
	.. "field[" .. fld_day1_t_minute_x .. "," .. fld_w_y .. ";" .. fld_sz .. ";fld_day6_end_minute;;" .. string.format("%02d", o.day6_end_minute) .. "]"
	local formspec_day0 = ""
	.. "label[" .. lab_day2_x .. "," .. lab_w_y .. ";So.]"
	.. "field[" .. fld_day2_f_hour_x .. "," .. fld_w_y .. ";" .. fld_sz .. ";fld_day0_start_hour;von;" .. string.format("%02d", o.day0_start_hour) .. "]"
	.. "label[" .. lab_day2_f_colon_x .. "," .. lab_w_colon_y .. ";:]"
	.. "field[" .. fld_day2_f_minute_x .. "," .. fld_w_y .. ";" .. fld_sz .. ";fld_day0_start_minute;;" .. string.format("%02d", o.day0_start_minute) .. "]"
	.. "field[" .. fld_day2_t_hour_x .. "," .. fld_w_y .. ";" .. fld_sz .. ";fld_day0_end_hour;bis;" .. string.format("%02d", o.day0_end_hour) .. "]"
	.. "label[" .. lab_day2_t_colon_x .. "," .. lab_w_colon_y .. ";:]"
	.. "field[" .. fld_day2_t_minute_x .. "," .. fld_w_y .. ";" .. fld_sz .. ";fld_day0_end_minute;;" .. string.format("%02d", o.day0_end_minute) .. "]"
	local formspec_exception = (o.exception_today
			and ""
				.. "label[" .. lab_day1_x .. "," .. lab_e_y .. ";Heute]"
				.. "field[" .. fld_day1_f_hour_x .. "," .. fld_e_y .. ";" .. fld_sz .. ";fld_exception_start_hour;von;" .. string.format("%02d", o.exception_start_hour) .. "]"
				.. "label[" .. lab_day1_f_colon_x .. "," .. lab_e_colon_y .. ";:]"
				.. "field[" .. fld_day1_f_minute_x .. "," .. fld_e_y .. ";" .. fld_sz .. ";fld_exception_start_minute;;" .. string.format("%02d", o.exception_start_minute) .. "]"
				.. "field[" .. fld_day1_t_hour_x .. "," .. fld_e_y .. ";" .. fld_sz .. ";fld_exception_end_hour;bis;" .. string.format("%02d", o.exception_end_hour) .. "]"
				.. "label[" .. lab_day1_t_colon_x .. "," .. lab_e_colon_y .. ";:]"
				.. "field[" .. fld_day1_t_minute_x .. "," .. fld_e_y .. ";" .. fld_sz .. ";fld_exception_end_minute;;" .. string.format("%02d", o.exception_end_minute) .. "]"
			or "image_button[0.34,4.5296922410056;4.205,0.7835;;add_exception;Ausnahmeregelung hinzufügen]"
		)
	local formspec = "size[18.01,7.9267895878525]"
	.. "label[-0.14,-0.23840485478977;Öffnungszeiten]"
	.. formspec_business_days
	.. formspec_day6
	.. formspec_day0
	.. formspec_exception
	.. "label[" .. lab_day1_x .. ",5.4833116601647;Einstellungen]"
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
minetest.register_chatcommand("opening_hours", {privs = {server = true}, description = "Die Öffnungszeiten konfigurieren", func = show_gui})
minetest.register_chatcommand("öffnungszeiten", {privs = {server = true}, description = "Die Öffnungszeiten konfigurieren", func = show_gui})
minetest.register_on_player_receive_fields(progress_gui_input)


