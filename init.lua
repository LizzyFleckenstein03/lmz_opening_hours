local modname = minetest.get_current_modname()
local storage = minetest.get_mod_storage()

opening_hours = {}

local opening_hours_default = {weekday_start = 14, weekday_end = 21, weekend_start = 8, weekend_end = 21, warn_offset = 15, warn_interval = 5}

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

local function save_data()
	storage:from_table({fields = opening_hours})
end

local function load_data()
	opening_hours = storage:to_table().fields
	if not opening_hours.weekday_start then
		opening_hours = opening_hours_default
	end
end

local function reset_execption()
	opening_hours.today = nil
	opening_hours.today_start = nil
	opening_hours.today_end = nil
end

local function opening_today()
	local today = opening_hours_today
	if today and today == get_date_formated() then
		return opening_hours.today_start, opening_hours.today_end
	elseif is_weekend() then
		return opening_hours.weekend_start, opening_hours.weekend_end
	else
		return opening_hours.weekday_start, opening_hours.weekday_end
	end
end

local function create_exception()
	local today_start, today_end = opening_today()
	opening_hours.today = get_date_formated()
	opening_hours.today_start = today_start
	opening_hours.today_end = today_end
end

local function tick(dtime)
	local d = get_date()
	if opening_hours.today and opening_hours.today ~= get_date_formated() then
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
	local fld_w = 1.0
	local fld_h = 0.82429501084599
	local fld_sz = fld_w .. "," .. fld_h
	local lab_close_y = 6.3935847420893
	local fld_close_y = lab_close_y + 0.2427394885132
	local lab_day1_x = 0.1
	local fld_day1_f_x = 0.64
	local fld_day1_t_x = 1.6
	local time_off = 1.1530125704378
	local lab_b_y = 0.28175119202427
	local fld_b_y = lab_b_y + time_off
	local lab_w_y = 2.0156046814044
	local fld_w_y = lab_w_y + time_off
	local lab_e_y = 3.7494581707846
	local fld_e_y = lab_e_y + time_off
	local o = opening_hours
	local formspec = "size[10.01,7.9267895878525]"
	.. "label[-0.14,-0.23840485478977;Öffnungszeiten]"
	.. "label[" .. lab_day1_x .. "," .. lab_b_y .. ";Mo.-Fr.]"
	.. "field[" .. fld_day1_f_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_weekday_start;von;" .. o.weekday_start .. "]"
	.. "field[" .. fld_day1_t_x .. "," .. fld_b_y .. ";" .. fld_sz .. ";fld_weekday_end;bis;" .. o.weekday_end .. "]"
	.. "label[" .. lab_day1_x .. "," .. lab_w_y .. ";Sa.-So.]"
	.. "field[" .. fld_day1_f_x .. "," .. fld_w_y .. ";" .. fld_sz .. ";fld_weekend_start;von;" .. o.weekend_start .. "]"
	.. "field[" .. fld_day1_t_x .. "," .. fld_w_y .. ";" .. fld_sz .. ";fld_weekend_end;bis;" .. o.weekend_end .. "]"
	.. "label[" .. lab_day1_x .. "," .. lab_e_y .. ";Heute]"
	.. (o.today
			and ""
				.. "field[" .. fld_day1_f_x .. "," .. fld_e_y .. ";" .. fld_sz .. ";fld_today_start;von;" .. o.today_start .. "]"
				.. "field[" .. fld_day1_t_x .. "," .. fld_e_y .. ";" .. fld_sz .. ";fld_today_end;bis;" .. o.today_end .. "]"
			or "image_button[0.34,4.5296922410056;4.205,0.7835;;add_exception;Ausnahmeregelung hinzufügen]"
		)
	.. "label[" .. lab_day1_x .. ",5.4833116601647;Einstellungen]"
	.. "label[0.34," .. lab_close_y .. ";Spieler ]"
	.. "field[" .. fld_day1_t_x .. "," .. fld_close_y .. ";" .. fld_sz .. ";fld_warn_offset;;" .. o.warn_offset .. "]"
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
		if k:sub(1, 4) == "fld_" and tonumber(v) then
			opening_hours[k:gsub("fld_", "")] = v
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


