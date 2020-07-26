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

local function opening_hours_index(t, k)
	if k:sub(1, 6) == "today_" then 
		return t[k:gsub("today_", is_weekend() and "weekend_" or "weekday_")]
	else
		return opening_hours_default[k]
	end
end

local function save_data()
	storage:from_table({fields = opening_hours})
end

local function load_data()
	opening_hours = storage:to_table().fields
	setmetatable(opening_hours, {__index = opening_hours_index})
end

local function reset_execption()
	opening_hours.today = nil
	opening_hours.today_start = nil
	opening_hours.today_end = nil
end

local function create_exception()
	opening_hours.today = get_date_formated()
	opening_hours.today_start = opening_hours.today_start
	opening_hours.today_end = opening_hours.today_end
end

local function tick(dtime)
	local d = get_date()
	if opening_hours.today and opening_hours.today ~= get_date_formated() then
		reset_execption()
	end
	local diff = tonumber(opening_hours.today_end) - d.hour
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
 	local d = get_date()
	local diff = tonumber(opening_hours.today_start) - d.hour
	if diff > 0 then
		return "Besuch erfolgte außerhalb der Öffnungszeiten. Der Server hat in " .. math.ceil(diff) .. " Stunde(n) wieder geöffnet."
	elseif tonumber(opening_hours.today_end) <= d.hour then
		return "Besuch erfolgte außerhalb der Öffnungszeiten. Der Server hat bereits geschlossen und hat Morgen wieder geöffnet."
	end
end

local function show_gui(name)
	local o = opening_hours
	local formspec = "size[10.01,7.9267895878525]label[-0.14,-0.23840485478977;Öffnungszeiten]label[0.1,0.28175119202427;Mo.-Fr.]label[0.1,2.0156046814044;Sa.-So.]label[0.1,3.7494581707846;Heute]label[0.1,5.4833116601647;Einstellungen]label[0.34,6.3935847420893;Spieler ]label[2.18,6.3935847420893;Minuten vor Ablauf der Zeit alle]label[6.6,6.3935847420893;Minuten warnen.]image_button_exit[7.62,7.6072821846554;2.605,0.7835;;close;Schließen]image_button[5.14,7.6072821846554;2.605,0.7835;;save;Speichern]"
	.. "field[0.64,1.4347637624621;1.0,0.82429501084599;fld_weekday_start;von;" .. o.weekday_start .. "]"
	.. "field[1.6,1.4347637624621;1.0,0.82429501084599;fld_weekday_end;bis;" .. o.weekday_end .. "]"
	.. "field[0.64,3.1686172518422;1.0,0.82429501084599;fld_weekend_start;von;" .. o.weekend_start .. "]"
	.. "field[1.6,3.1686172518422;1.0,0.82429501084599;fld_weekend_end;bis;" .. o.weekend_end .. "]"
	.. "field[1.6,6.6363242306025;1.0,0.82429501084599;fld_warn_offset;;" .. o.warn_offset .. "]"
	.. "field[6.0,6.6363242306025;1.0,0.82429501084599;fld_warn_interval;;" .. o.warn_interval .. "]"
	.. (o.today
			and ""
				.. "field[0.64,4.9024707412224;1.0,0.82429501084599;fld_today_start;von;" .. o.today_start .. "]"
				.. "field[1.6,4.9024707412224;1.0,0.82429501084599;fld_today_end;bis;" .. o.today_end .. "]"
			or "image_button[0.34,4.5296922410056;4.205,0.7835;;add_exception;Ausnahmeregelung hinzufügen]"
		)
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
minetest.register_chatcommand("öffnungszeiten", {privs = {server = true}, description = "Die Öffnungszeiten konfigurieren", func = show_gui})
minetest.register_on_player_receive_fields(progress_gui_input)


