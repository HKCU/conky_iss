--
--  Conky_iss system monitor Lua functions
-- 
--  (C) 2017, Angus Cook.  All rights reserved.
-- 
--  Script to show Conky clock rings for parameters described in the table
--
--  Notes:
--  01) Nasalization font obtained from here:
--      <http://www.1001fonts.com/search.html?search=Nasalization&x=0&y=0>
--
--  02) Requires Cairo 2D graphics library
--
--  03) Configure the clock parameters in the 'clockpars' array
--
--  04) Configure each ring's settings in the 'ringdefs' array
--
--  05) All functions whose name begins with "conky_" is called from
--      the Conky configuration file.
--
--  06) Any function whose name does NOT begin with "conky_" is an
--      internal function and must only be called from within this file.
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the MIT Licence.
-- 
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  MIT Licence for more details.
--
clockpars =
{
	parm = 'Yes',
	clockface_colour = 0x000033,
	clockface_alpha = 0.8,
	x = 200,
	y = 200,
	radius = 160,
	border_size = 4,
	border_colour = 0xaaaaee,
	border_alpha = 0.8,
	hour_marker_colour = 0xcccccc,
	hour_marker_alpha = 0.8,
	hour_marker_thickness = 4,
	hour_marker_percentage = 20,
	minute_marker_colour = 0xaaaaaa,
	minute_marker_alpha = 0.8,
	minute_marker_thickness = 2,
	minute_marker_percentage = 10,
	seconds_hand_colour = 0xff0000,
	seconds_hand_alpha = 1.0,
	seconds_hand_thickness = 2,
	seconds_hand_percentage = 90,
	minute_hand_colour = 0x00ff00,
	minute_hand_alpha = 0.6,
	minute_hand_thickness = 3,
	minute_hand_percentage = 80,
	hour_hand_colour = 0xff8800,
	hour_hand_alpha = 0.6,
	hour_hand_thickness = 4,
	hour_hand_percentage = 60,
	text_voffset = 220,
	text_fontface = 'Nasalization',
	text_fontsz = 14,
	text_colour = 'Grey',
}

ringdefs =
{
	-- Show a ring for /dev/sda7
	{
		parm = '',
		min = 0, max = 1, -- If max <= min, then get maximum value using max_command
		max_command = '',
		bg_colour = 0xff0000,
		bg_alpha = 0.6,
		fg_colour = 0xff0000,
		fg_alpha = 0.6,
		x = 200,
		y = 200,
		radius = 150,
		thickness = 24,
		start_angle = 30,
		end_angle = 330,
		text = '',
		text_hoffset = 144,
		text_voffset = 120,
		text_fontface = 'Nasalization',
		text_fontsz = 12,
		text_colour = 'Black',
	},
	{
		parm = 'df --output=used /dev/sda7 | grep -v Used',
		min = 0, max = 0, -- If max <= min, then get maximum value using max_command
		max_command = 'df --output=size /dev/sda7 | grep -v "1K-blocks"',
		bg_colour = 0xff0000,
		bg_alpha = 0.6,
		fg_colour = 0x00ffff,
		fg_alpha = 0.6,
		x = 200,
		y = 200,
		radius = 150,
		thickness = 16,
		start_angle = 30,
		end_angle = 330,
		text = '/dev/sda7',
		text_hoffset = 144,
		text_voffset = 45,
		text_fontface = 'Nasalization',
		text_fontsz = 12,
		text_colour = 'Gray',
	},
	
	-- Show a ring for /dev/sda5
	{
		parm = '',
		min = 0, max = 1,
		max_command = '',
		bg_colour = 0xff0000,
		bg_alpha = 0.6,
		fg_colour = 0xff0000,
		fg_alpha = 0.6,
		x = 200,
		y = 200,
		radius = 115,
		thickness = 24,
		start_angle = 30,
		end_angle = 330,
		text = '',
		text_hoffset = 144,
		text_voffset = 10,
		text_fontface = 'Nasalization',
		text_fontsz = 12,
		text_colour = 'Black',
	},
	{
		parm = 'df --output=used /dev/sda5 | grep -v Used',
		min = 0, max = 0,
		max_command = 'df --output=size /dev/sda5 | grep -v "1K-blocks"',
		bg_colour = 0xff0000,
		bg_alpha = 0.6,
		fg_colour = 0x00ffff,
		fg_alpha = 0.6,
		x = 200,
		y = 200,
		radius = 115,
		thickness = 16,
		start_angle = 30,
		end_angle = 330,
		text = '/dev/sda5',
		text_hoffset = 144,
		text_voffset = 15,
		text_fontface = 'Nasalization',
		text_fontsz = 12,
		text_colour = 'Gray',
	},
}

require 'cairo'

--
--  Function to split colour out into RGB components
--
function rgb_to_r_g_b(colour,alpha)
	return ((colour / 0x10000) % 0x100) / 255.0, ((colour / 0x100) % 0x100) / 255.0, (colour % 0x100) / 255.0, alpha
end

--
--  Function to get the number of CPU cores and report details on each one
--
function conky_get_cpu_core_details()
	local res = {}
	local pipe = assert(io.popen('getconf _NPROCESSORS_ONLN', 'r'))
	local procs = pipe:read('*all')
	pipe:close()
	local i
	for i = 1, procs do
		res[i] = "Core " .. i .. ": " .. conky_parse("${cpu cpu" .. i .. "}% ${alignr}${cpubar cpu" .. i .. " 10,180}")
	end
	return table.concat(res, "\n")
end

--
--  Function to draw individual ring with parameters passed in st
--  Return with text to send back to Conky
--
function render_ring(cr, st)
	-- Pick up some of the array values (those we'll use more than once for the sake of code clarity)
	local min = st['min']
	local max = st['max']
	local x = st['x']
	local y = st['y']
	local radius = st['radius']
	local thickness = st['thickness']
	local start_angle = st['start_angle']
	local end_angle = st['end_angle']
	local handle, cmd, parmval

	-- If max <= min, then use a command to determine the maximum value
	if max <= min then
		cmd = st['max_command']
		handle = io.popen(cmd)
		max = handle:read("*a")
		handle:close()
		max = string.gsub(max, "^%s+", "")
		max = string.gsub(max, "\n", "")
		max = assert(tonumber(max))
	end

	-- Work out how much of the ring is foreground (used, gone) and how much is background (free, to go) (angle)
	cmd = st['parm']
	if string.len(cmd) > 0 then
		handle = io.popen(cmd)
		parmval = handle:read("*a")
		handle:close()
		parmval = string.gsub(parmval, "^%s+", "")
		parmval = string.gsub(parmval, "\n", "")
		parmval = assert(tonumber(parmval))
		if parmval == nil then parmval = min end -- Use minimum angle if nil
	else
		parmval = min
	end
	local angle = start_angle + ((end_angle - start_angle) * (parmval - min) / (max - min)) -- Angle in degrees

	-- Compute the angles required
	local angle_0 = (start_angle - 90) * math.pi / 180
	local angle_f = (end_angle - 90) * math.pi / 180
	local angle_r = (angle - 90) * math.pi / 180

	-- Draw background ring
	cairo_arc(cr, x, y, radius, angle_0, angle_r)
	cairo_set_source_rgba(cr, rgb_to_r_g_b(st['bg_colour'], st['bg_alpha']))
	cairo_set_line_width(cr, thickness)
	cairo_stroke(cr)

	-- Draw indicator ring
	cairo_arc(cr, x, y, radius, angle_r, angle_f)
	cairo_set_source_rgba(cr, rgb_to_r_g_b(st['fg_colour'], st['fg_alpha']))
	cairo_set_line_width(cr, thickness)
	cairo_stroke(cr)

	-- Now get vertical offset for the clock text and return a string to display in Conky
	local text = st['text']
	local voffset = st['text_voffset']
	local resultstr = ""
	if string.len(text) > 0 then
		local font = "${font " .. st['text_fontface'] .. ":bold:size=" .. st['text_fontsz'] .."}"
		resultstr = "${color " .. st['text_colour'] .. "}"
		resultstr = resultstr .. "${offset " .. st['text_hoffset'] .. "}"
		resultstr = resultstr .. "${voffset " .. voffset .. "}" .. font .. text .. "\n"
	end
	return resultstr
end

--
--  Function to show the required rings
--
function conky_show_rings()

	-- Get conky window reference into a shorter local variable
	local cw = conky_window
	local restr = ""

	-- Just abort if we don't have a Conky window
	if cw == nil then return end

	-- Get number of updates: if this is 5 or more then do the work
	local updates = tonumber(conky_parse('${updates}'))
	if updates >= 5 then

		-- Create the surface and context
		local cs = cairo_xlib_surface_create(cw.display, cw.drawable, cw.visual, cw.width, cw.height)
		local cr = cairo_create(cs)	
		local i, st

		-- Now draw the rings
		for i in pairs(ringdefs) do

			-- Render the ring
			restr = restr .. render_ring(cr, ringdefs[i])
		end

		-- Clear up
		cairo_destroy(cr)
		cairo_surface_destroy(cs)
	end
	return restr
end

--
--  Function to show the clock according to the parameters passed in the clockpars table
--
function render_clock(cr, clockpars)

	-- Some variables
	local i, hms, angle0, angle1
	local mark_start_x, mark_start_y, mark_end_x, mark_end_y

	-- Get start angle (top of the clock) and do some setting up
	local x = clockpars['x']
	local y = clockpars['y']
	local radius = clockpars['radius']
	angle0 = -90 * math.pi / 180

	-- Draw the clockface and background
	cairo_new_sub_path(cr)
	cairo_arc(cr, x, y, radius, 0, 360)
	cairo_set_source_rgba(cr, rgb_to_r_g_b(clockpars['clockface_colour'], clockpars['clockface_alpha']))
	cairo_set_line_width(cr, radius)
	cairo_fill(cr)

	-- Draw the clock border
	local border_size = clockpars['border_size']
	cairo_new_sub_path(cr)
	cairo_arc(cr, x, y, radius + (border_size / 2), 0, 360)
	cairo_set_source_rgba(cr, rgb_to_r_g_b(clockpars['border_colour'], clockpars['border_alpha']))
	cairo_set_line_width(cr, border_size)
	cairo_stroke(cr)

	-- Loop again to show the clock minute markings
	local radiush = radius * (100 - clockpars['hour_marker_percentage']) / 100
	local radiusm = radius * (100 - clockpars['minute_marker_percentage']) / 100
	angle0 = -90 * math.pi / 180
	for i = 1, 60 do
		-- Compute end angle
		angle1 = (6 * i - 90) * math.pi / 180

		-- Draw marks for each hour and minute position
		cairo_new_sub_path(cr)
		mark_start_x = x + math.sin(angle0) * radius
		mark_start_y = y + math.cos(angle0) * radius
		if ((i - 1) % 5) == 0 then
			mark_end_x = x + math.sin(angle0) * radiush
			mark_end_y = y + math.cos(angle0) * radiush
			cairo_set_source_rgba(cr, rgb_to_r_g_b(clockpars['hour_marker_colour'], clockpars['hour_marker_alpha']))
			cairo_set_line_width(cr, clockpars['hour_marker_thickness'])
		else
			mark_end_x = x + math.sin(angle0) * radiusm
			mark_end_y = y + math.cos(angle0) * radiusm
			cairo_set_source_rgba(cr, rgb_to_r_g_b(clockpars['minute_marker_colour'], clockpars['minute_marker_alpha']))
			cairo_set_line_width(cr, clockpars['minute_marker_thickness'])
		end
		cairo_move_to(cr, mark_start_x, mark_start_y)
		cairo_line_to(cr, mark_end_x, mark_end_y)
		cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND)
		cairo_stroke(cr)

		-- In the next iteration, angle0 will be the current angle1 (saves having to recompute)
		angle0 = angle1
	end

	-- Get the seconds and draw the seconds hand
	hms = tonumber(conky_parse("${time %S}"))
	hms = hms % 60
	angle1 = hms * math.pi / 30
	radiusi = radius * clockpars['seconds_hand_percentage'] / 100
	mark_end_x = x + math.sin(angle1) * radiusi
	mark_end_y = y - math.cos(angle1) * radiusi
	cairo_new_sub_path(cr)
	cairo_move_to(cr, x, y)
	cairo_line_to(cr, mark_end_x, mark_end_y)
	cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND)
	cairo_set_source_rgba(cr, rgb_to_r_g_b(clockpars['seconds_hand_colour'], clockpars['seconds_hand_alpha']))
	cairo_set_line_width(cr, clockpars['seconds_hand_thickness'])
	cairo_stroke(cr)

	-- Get the minutes and draw the minutes hand (take seconds into account for angle calculation)
	i = tonumber(conky_parse("${time %M}"))
	hms = (i * 60 + hms) / 60
	angle1 = hms * math.pi / 30
	radiusi = radius * clockpars['minute_hand_percentage'] / 100
	mark_end_x = x + math.sin(angle1) * radiusi
	mark_end_y = y - math.cos(angle1) * radiusi
	cairo_new_sub_path(cr)
	cairo_move_to(cr, x, y)
	cairo_line_to(cr, mark_end_x, mark_end_y)
	cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND)
	cairo_set_source_rgba(cr, rgb_to_r_g_b(clockpars['minute_hand_colour'], clockpars['minute_hand_alpha']))
	cairo_set_line_width(cr, clockpars['minute_hand_thickness'])
	cairo_stroke(cr)

	-- Get the time in hours and minutes and draw the hours hand (take minutes and seconds into account for angle calculation)
	i = tonumber(conky_parse("${time %I}"))
	hms = ((i % 12) * 60 + hms) / 2
	angle1 = hms * math.pi / 180
	radiusi = radius * clockpars['hour_hand_percentage'] / 100
	mark_end_x = x + math.sin(angle1) * radiusi
	mark_end_y = y - math.cos(angle1) * radiusi
	cairo_new_sub_path(cr)
	cairo_move_to(cr, x, y)
	cairo_line_to(cr, mark_end_x, mark_end_y)
	cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND)
	cairo_set_source_rgba(cr, rgb_to_r_g_b(clockpars['hour_hand_colour'], clockpars['hour_hand_alpha']))
	cairo_set_line_width(cr, clockpars['hour_hand_thickness'])
	cairo_stroke(cr)
end


--
--  Function to show the clock
--
function conky_show_clock()

	-- Get conky window reference into a shorter local variable
	local cw = conky_window

	-- Just abort if we don't have a Conky window
	if cw == nil then return end

	-- Get number of updates: if this is 5 or more then do the work
	local updates = tonumber(conky_parse('${updates}'))
	if updates >= 5 then

		-- Create the surface and context
		local cs = cairo_xlib_surface_create(cw.display, cw.drawable, cw.visual, cw.width, cw.height)
		local cr = cairo_create(cs)	
		local i, st

		-- Show the clock
		if clockpars['parm'] == 'Yes' then
			render_clock(cr, clockpars)
		end

		-- Clear up
		cairo_destroy(cr)
		cairo_surface_destroy(cs)
	end

	-- Now get vertical offset for the clock text and return a string to display in Conky
	local voffset = clockpars['text_voffset']
	local resultstr = ""
	if (voffset > 0) then
		local font = "${font " .. clockpars['text_fontface'] .. ":bold:size=" .. clockpars['text_fontsz'] .."}"
		resultstr = "${color " .. clockpars['text_colour'] .. "}"
		resultstr = resultstr .. "${voffset " .. voffset .. "}${alignc}" .. font .. "${time %a %e %b %Y}\n"
		resultstr = resultstr .. "${alignc}" .. font .. "${time %H:%M:%S}"
	end
	return resultstr
end
