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

local function is_weekend()
	local d = os.date("%w")
	return d == "0" or d == "6"
end

local function upgrade_configuration(old)
	local new = {
		version = 2,
		day0_start_hour = old.weekend_start,
		day0_start_minute = 0,
		day0_end_hour = old.weekend_end,
		day0_end_minute = 0,
		day1_start_hour = old.weekday_start,
		day1_start_minute = 0,
		day1_end_hour = old.weekday_end,
		day1_end_minute = 0,
		day2_start_hour = old.weekday_start,
		day2_start_minute = 0,
		day2_end_hour = old.weekday_end,
		day2_end_minute = 0,
		day3_start_hour = old.weekday_start,
		day3_start_minute = 0,
		day3_end_hour = old.weekday_end,
		day3_end_minute = 0,
		day4_start_hour = old.weekday_start,
		day4_start_minute = 0,
		day4_end_hour = old.weekday_end,
		day4_end_minute = 0,
		day5_start_hour = old.weekday_start,
		day5_start_minute = 0,
		day5_end_hour = old.weekday_end,
		day5_end_minute = 0,
		day6_start_hour = old.weekend_start,
		day6_start_minute = 0,
		day6_end_hour = old.weekend_end,
		day6_end_minute = 0,
		warn_offset = old.warn_offset,
		warn_interval = old.warn_interval,
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
	elseif is_weekend() then
		day_key = "day0"
	else
		day_key = "day1"
	end
	return opening_hours[day_key .. "_start_hour"], opening_hours[day_key .. "_end_hour"]
end

local function create_exception()
	local today_start, today_end = opening_today()
	opening_hours.exception_today = get_date_formated()
	opening_hours.exception_start_hour = today_start
	opening_hours.exception_start_minute = 0
	opening_hours.exception_end_hour = today_end
	opening_hours.exception_end_minute = 0
end

local function tick(dtime)
	local d = get_date()
	local exception = opening_hours.exception_today
	if exception and exception ~= get_date_formated() then
		reset_execption()
	end
	local today_start, today_end = opening_today()
	local diff = tonumber(today_end) - d.hour
	if diff == 1 then
		local minutes_remaining = (60 - d.min)
		if minutes_remaining <= tonumber(opening_hours.warn_offset) then
			if warn_cooldown <= 0 then
				minetest.chat_send_all(minetest.colorize("#FF4D00", "Der Server schießt in " .. minutes_remaining .. " Minuten."))
				warn_cooldown = tonumber(opening_hours.warn_interval) * 60
			else
				warn_cooldown = warn_cooldown - dtime
			end
		end
	elseif diff <= 0 then
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
	local today_start, today_end = opening_today()
 	local d = get_date()
	local diff = tonumber(today_start) - d.hour
	if diff > 0 then
		return "Besuch erfolgte außerhalb der Öffnungszeiten. Der Server hat in " .. math.ceil(diff) .. " Stunde(n) wieder geöffnet."
	elseif tonumber(today_end) <= d.hour then
		return "Besuch erfolgte außerhalb der Öffnungszeiten. Der Server hat bereits geschlossen und hat Morgen wieder geöffnet."
	end
end

local function show_gui(name)
	local fld_w = 0.88
	local fld_h = 0.82429501084599
	local fld_sz = fld_w .. "," .. fld_h
	local inline_off = 0.2427394885132
	local lab_close_y = 6.3935847420893
	local fld_close_y = lab_close_y + 0.2427394885132
	local lab_day1_x = 0.1
	local pre_colon_off = 0.4
	local fld_day1_f_hour_x = 0.64
	local minute_off = 0.04
	local to_off = 1.24
	local fld_day1_f_minute_x = fld_day1_f_hour_x + fld_w - minute_off
	local lab_day1_f_colon_x = fld_day1_f_minute_x - pre_colon_off
	local fld_day1_t_hour_x = lab_day1_f_colon_x + to_off
	local fld_day1_t_minute_x = fld_day1_t_hour_x + fld_w - minute_off
	local lab_day1_t_colon_x = fld_day1_t_minute_x - pre_colon_off
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
	local formspec = "size[10.01,7.9267895878525]"
	.. "label[-0.14,-0.23840485478977;Öffnungszeiten]"
	.. "label[" .. lab_day1_x .. "," .. lab_b_y .. ";Mo.-Fr.]"
	.. "field[" .. fld_day1_f_hour_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day1_start_hour;von;" .. string.format("%02d", o.day1_start_hour) .. "]"
	.. "label[" .. lab_day1_f_colon_x .. "," .. lab_b_colon_y .. ";:]"
	.. "field[" .. fld_day1_f_minute_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day1_start_minute;;" .. string.format("%02d", o.day1_start_minute) .. "]"
	.. "field[" .. fld_day1_t_hour_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day1_end_hour;bis;" .. string.format("%02d", o.day1_end_hour) .. "]"
	.. "label[" .. lab_day1_t_colon_x .. "," .. lab_b_colon_y .. ";:]"
	.. "field[" .. fld_day1_t_minute_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_day1_end_minute;;" .. string.format("%02d", o.day1_end_minute) .. "]"
	.. "label[" .. lab_day1_x .. "," .. lab_w_y .. ";Sa.-So.]"
	.. "field[" .. fld_day1_f_hour_x .. "," .. fld_w_y .. ";" .. fld_sz .. ";fld_day0_start_hour;von;" .. string.format("%02d", o.day0_start_hour) .. "]"
	.. "label[" .. lab_day1_f_colon_x .. "," .. lab_w_colon_y .. ";:]"
	.. "field[" .. fld_day1_f_minute_x .. "," .. fld_w_y .. ";" .. fld_sz .. ";fld_day0_start_minute;;" .. string.format("%02d", o.day0_start_minute) .. "]"
	.. "field[" .. fld_day1_t_hour_x .. "," .. fld_w_y .. ";" .. fld_sz .. ";fld_day0_end_hour;bis;" .. string.format("%02d", o.day0_end_hour) .. "]"
	.. "label[" .. lab_day1_t_colon_x .. "," .. lab_w_colon_y .. ";:]"
	.. "field[" .. fld_day1_t_minute_x .. "," .. fld_w_y .. ";" .. fld_sz .. ";fld_day0_end_minute;;" .. string.format("%02d", o.day0_end_minute) .. "]"
	.. "label[" .. lab_day1_x .. "," .. lab_e_y .. ";Heute]"
	.. (o.exception_today
			and ""
				.. "field[" .. fld_day1_f_hour_x .. "," .. fld_e_y .. ";" .. fld_sz .. ";fld_exception_start_hour;von;" .. string.format("%02d", o.exception_start_hour) .. "]"
				.. "label[" .. lab_day1_f_colon_x .. "," .. lab_e_colon_y .. ";:]"
				.. "field[" .. fld_day1_f_minute_x .. "," .. fld_e_y .. ";" .. fld_sz .. ";fld_exception_start_minute;;" .. string.format("%02d", o.exception_start_minute) .. "]"
				.. "field[" .. fld_day1_t_hour_x .. "," .. fld_e_y .. ";" .. fld_sz .. ";fld_exception_end_hour;bis;" .. string.format("%02d", o.exception_end_hour) .. "]"
				.. "label[" .. lab_day1_t_colon_x .. "," .. lab_e_colon_y .. ";:]"
				.. "field[" .. fld_day1_t_minute_x .. "," .. fld_e_y .. ";" .. fld_sz .. ";fld_exception_end_minute;;" .. string.format("%02d", o.exception_end_minute) .. "]"
			or "image_button[0.34,4.5296922410056;4.205,0.7835;;add_exception;Ausnahmeregelung hinzufügen]"
		)
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
	if not fields.quit and not fields.close then show_gui(name) end
end

load_data()

minetest.register_globalstep(tick)
minetest.register_on_shutdown(save_data)
minetest.register_on_prejoinplayer(on_join)
minetest.register_chatcommand("opening_hours", {privs = {server = true}, description = "Die Öffnungszeiten konfigurieren", func = show_gui})
minetest.register_chatcommand("öffnungszeiten", {privs = {server = true}, description = "Die Öffnungszeiten konfigurieren", func = show_gui})
minetest.register_on_player_receive_fields(progress_gui_input)


