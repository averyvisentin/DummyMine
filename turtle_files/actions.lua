inf = basics.inf
str_xyz = basics.str_xyz

--lua_print = print
--log_file = fs.open('log.txt', 'w')
--function print(thing)
--    lua_print(thing)
--    log_file.writeLine(thing)
--end

--location state
function update_state(new_location, new_orientation)
    if new_location then
        state.location = new_location
    end
    if new_orientation then
        state.orientation = new_orientation
    end
end


-- Insert function for priority queue
function insert_into_open_set(open_set, node, f_score)
    local inserted = false
    for i = 1, #open_set do
        if f_score[node] < f_score[open_set[i]] then
            table.insert(open_set, i, node)
            inserted = true
            break
        end
    end
    if not inserted then
        table.insert(open_set, node)
    end
end

-- Pop function for priority queue
function pop_from_open_set(open_set)
    return table.remove(open_set, 1)
end

-- Contains function for priority queue
function contains(open_set, node)
    for _, n in ipairs(open_set) do
        if n == node then
            return true
        end
    end
    return false
end

-- Convert path from nodes to directions
function path_to_directions(path)
    local directions = ""
    for i = 1, #path - 1 do
        local dx = path[i+1].x - path[i].x
        local dy = path[i+1].y - path[i].y
        local dz = path[i+1].z - path[i].z
        if dx == 1 then directions = directions .. "r" end
        if dx == -1 then directions = directions .. "l" end
        if dy == 1 then directions = directions .. "u" end
        if dy == -1 then directions = directions .. "d" end
        if dz == 1 then directions = directions .. "f" end
        if dz == -1 then directions = directions .. "b" end -- Assuming 'b' is back
    end
    return directions
end

-- Modified A* Algorithm Implementation
function a_star_pathfinding(start, goal)
    local open_set = {}
    insert_into_open_set(open_set, start, {[start] = basics.distance(start, goal)})
    local came_from = {}
    local g_score = {[start] = 0}
    local f_score = {[start] = basics.distance(start, goal)}

    while #open_set > 0 do
        local current = pop_from_open_set(open_set)

        if current == goal then
            return reconstruct_path(came_from, current)
        end

        for _, neighbor in ipairs(get_neighbors(current)) do
            local tentative_g_score = g_score[current] + distance_between(current, neighbor)
            if g_score[neighbor] == nil or tentative_g_score < g_score[neighbor] then
                came_from[neighbor] = current
                g_score[neighbor] = tentative_g_score
                f_score[neighbor] = g_score[neighbor] + distance(neighbor, goal)
                if not contains(open_set, neighbor) then
                    insert_into_open_set(open_set, neighbor, f_score)
                end
            end
        end
    end
end

function reconstruct_path(came_from, current)
    local total_path = {current}
    while came_from[current] do
        current = came_from[current]
        table.insert(total_path, current)
    end
    return total_path
end

function get_neighbors(node)
    local neighbors = {}
    -- Updated directions to include up and down along z-axis
    local directions = {
        {x = 0, y = -1, z = 0}, -- up
        {x = 0, y = 1, z = 0},  -- down
        {x = -1, y = 0, z = 0}, -- left
        {x = 1, y = 0, z = 0},  -- right
        {x = 0, y = 0, z = -1}, -- above
        {x = 0, y = 0, z = 1}   -- below
    }
    local grid_size = {width = 3, height = 3, depth = 3} -- Example grid size including depth

    for _, direction in ipairs(directions) do
        local neighbor_x = node.x + direction.x
        local neighbor_y = node.y + direction.y
        local neighbor_z = node.z + direction.z -- Added z coordinate

        if neighbor_x >= 1 and neighbor_x <= grid_size.width and
           neighbor_y >= 1 and neighbor_y <= grid_size.height and
           neighbor_z >= 1 and neighbor_z <= grid_size.depth then -- Check for z coordinate within bounds
            table.insert(neighbors, {x = neighbor_x, y = neighbor_y, z = neighbor_z})
        end
    end

    return neighbors
end

-- Move function with retries
function safe_move(direction)
    local attempts = 3
    while attempts > 0 do
        if move[direction]() then
            return true
        end
        attempts = attempts - 1
        sleep(0.5)
    end
    return false
end

-- Safe dig function with error handling
function safe_dig(direction)
    if not dig[direction] then
        return false
    end
    if not dig[direction]() then
        return false
    end
    return true
end

-- GPS recovery function
function recover_gps()
    local attempts = 3
    while attempts > 0 do
        local x, y, z = gps.locate()
        if x and y and z then
            state.location = {x = x, y = y, z = z}
            return true
        end
        attempts = attempts - 1
        sleep(1)
    end
    return false
end

-- Communication timeout function
function communicate_with_chunky()
    local timeout = 10
    while timeout > 0 do
        local response = rednet.receive('chunky_message', 1)
        if response then
            return true
        end
        timeout = timeout - 1
    end
    return false
end

bumps = {
    north = { 0,  0, -1},
    south = { 0,  0,  1},
    east  = { 1,  0,  0},
    west  = {-1,  0,  0},
}


left_shift = {
    north = 'west',
    south = 'east',
    east  = 'north',
    west  = 'south',
}


right_shift = {
    north = 'east',
    south = 'west',
    east  = 'south',
    west  = 'north',
}


reverse_shift = {
    north = 'south',
    south = 'north',
    east  = 'west',
    west  = 'east',
}


move = {
    forward = turtle.forward,
    up      = turtle.up,
    down    = turtle.down,
    back    = turtle.back,
    left    = turtle.turnLeft,
    right   = turtle.turnRight
}


detect = {
    forward = turtle.detect,
    up      = turtle.detectUp,
    down    = turtle.detectDown
}


inspect = {
    forward = turtle.inspect,
    up      = turtle.inspectUp,
    down    = turtle.inspectDown
}


dig = {
    forward = turtle.dig,
    up      = turtle.digUp,
    down    = turtle.digDown
}

attack = {
    forward = turtle.attack,
    up      = turtle.attackUp,
    down    = turtle.attackDown
}


getblock = {

    up = function(pos, fac)
        if not pos then pos = state.location end
        if not fac then fac = state.orientation end
        return {x = pos.x, y = pos.y + 1, z = pos.z}
    end,

    down = function(pos, fac)
        if not pos then pos = state.location end
        if not fac then fac = state.orientation end
        return {x = pos.x, y = pos.y - 1, z = pos.z}
    end,

    forward = function(pos, fac)
        if not pos then pos = state.location end
        if not fac then fac = state.orientation end
        local bump = bumps[fac]
        return {x = pos.x + bump[1], y = pos.y + bump[2], z = pos.z + bump[3]}
    end,

    back = function(pos, fac)
        if not pos then pos = state.location end
        if not fac then fac = state.orientation end
        local bump = bumps[fac]
        return {x = pos.x - bump[1], y = pos.y - bump[2], z = pos.z - bump[3]}
    end,

    left = function(pos, fac)
        if not pos then pos = state.location end
        if not fac then fac = state.orientation end
        local bump = bumps[left_shift[fac]]
        return {x = pos.x + bump[1], y = pos.y + bump[2], z = pos.z + bump[3]}
    end,

    right = function(pos, fac)
        if not pos then pos = state.location end
        if not fac then fac = state.orientation end
        local bump = bumps[right_shift[fac]]
        return {x = pos.x + bump[1], y = pos.y + bump[2], z = pos.z + bump[3]}
    end,
}


function digblock(direction)
    dig[direction]()
    return true
end


function delay(duration)
    sleep(duration)
    return true
end


function up()
    return go('up')
end


function forward()
    return go('forward')
end


function down()
    return go('down')
end


function back()
    return go('back')
end


function left()
    return go('left')
end


function right()
    return go('right')
end


function follow_route(route)
    for step in route:gmatch'.' do
        if step == 'u' then
            if not go('up')      then return false end
        elseif step == 'f' then
            if not go('forward') then return false end
        elseif step == 'd' then
            if not go('down')    then return false end
        elseif step == 'b' then
            if not go('back')    then return false end
        elseif step == 'l' then
            if not go('left')    then return false end
        elseif step == 'r' then
            if not go('right')   then return false end
        end
    end
    return true
end


function face(orientation)
    if state.orientation == orientation then
        return true
    elseif right_shift[state.orientation] == orientation then
        if not go('right') then return false end
    elseif left_shift[state.orientation] == orientation then
        if not go('left') then return false end
    elseif right_shift[right_shift[state.orientation]] == orientation then
        if not go('right') then return false end
        if not go('right') then return false end
    else
        return false
    end
    return true
end


function log_movement(direction)
    if direction == 'up' then
        state.location.y = state.location.y +1
    elseif direction == 'down' then
        state.location.y = state.location.y -1
    elseif direction == 'forward' then
        bump = bumps[state.orientation]
        state.location = {x = state.location.x + bump[1], y = state.location.y + bump[2], z = state.location.z + bump[3]}
    elseif direction == 'back' then
        bump = bumps[state.orientation]
        state.location = {x = state.location.x - bump[1], y = state.location.y - bump[2], z = state.location.z - bump[3]}
    elseif direction == 'left' then
        state.orientation = left_shift[state.orientation]
    elseif direction == 'right' then
        state.orientation = right_shift[state.orientation]
    end
    return true
end


function go(direction, nodig)
    local retryLimit = 5 -- Maximum number of move attempts
    local retryCount = 0 -- Current retry attempt

    if not nodig then
        if detect[direction] then
            if detect[direction]() then
                safedig(direction)
            end
        end
    end

    while retryCount < retryLimit do
        if not move[direction] then
            return false -- If the move function for the direction does not exist, exit early
        end

        if move[direction]() then
            log_movement(direction) -- Log successful movement
            return true -- Movement successful, exit function
        else
            if attack[direction] then
                attack[direction]() -- Attempt to attack in case the obstacle is an attackable entity
            end
            retryCount = retryCount + 1 -- Increment retry count
            sleep(1) -- Wait for 1 second before retrying
        end
    end

    -- If the function reaches this point, all retries have failed
    return false
end

function go_to_axis(axis, coordinate, nodig)
    local delta = coordinate - state.location[axis]
    if delta == 0 then
        return true
    end

    if axis == 'x' then
        if delta > 0 then
            if not face('east') then return false end
        else
            if not face('west') then return false end
        end
    elseif axis == 'z' then
        if delta > 0 then
            if not face('south') then return false end
        else
            if not face('north') then return false end
        end
    end

    for i = 1, math.abs(delta) do
        if axis == 'y' then
            if delta > 0 then
                if not go('up', nodig) then return false end
            else
                if not go('down', nodig) then return false end
            end
        else
            if not go('forward', nodig) then return false end
        end
    end
    return true
end


function go_to(end_location, end_orientation, path, nodig)
    if path then
        for axis in path:gmatch'.' do
            if not go_to_axis(axis, end_location[axis], nodig) then return false end
        end
    elseif end_location.path then
        for axis in end_location.path:gmatch'.' do
            if not go_to_axis(axis, end_location[axis], nodig) then return false end
        end
    else
        return false
    end
    if end_orientation then
        if not face(end_orientation) then return false end
    elseif end_location.orientation then
        if not face(end_location.orientation) then return false end
    end
    return true
end


function go_route(route, xyzo)
    local xyz_string
    if xyzo then
        xyz_string = str_xyz(xyzo)
    end
    local location_str = basics.str_xyz(state.location)
    while route[location_str] and location_str ~= xyz_string do
        if not go_to(route[location_str], nil, 'xyz') then return false end
        location_str = basics.str_xyz(state.location)
    end
    if xyzo then
        if location_str ~= xyz_string then
            return false
        end
        if xyzo.orientation then
            if not face(xyzo.orientation) then return false end
        end
    end
    return true
end


function go_to_home()
    state.updated_not_home = nil
    if basics.in_area(state.location, config.locations.home_area) then
        return true
    elseif basics.in_area(state.location, config.locations.greater_home_area) then
        if not go_to_home_exit() then return false end
    elseif basics.in_area(state.location, config.locations.waiting_room_area) then
        if not go_to(config.locations.mine_exit, nil, config.paths.waiting_room_to_mine_exit, true) then return false end
    elseif state.location.y < config.locations.mine_enter.y then
        return false
    end
    if config.locations.main_loop_route[basics.str_xyz(state.location)] then
        if not go_route(config.locations.main_loop_route, config.locations.home_enter) then return false end
    elseif basics.in_area(state.location, config.locations.control_room_area) then
        if not go_to(config.locations.home_enter, nil, config.paths.control_room_to_home_enter, true) then return false end
    else
        return false
    end
    if not forward() then return false end
    while detect.down() do
        if not forward() then return false end
    end
    if not down() then return false end
    if not right() then return false end
    if not right() then return false end
    return true
end


function go_to_home_exit()
    if basics.in_area(state.location, config.locations.greater_home_area) then
        if not go_to(config.locations.home_exit, nil, config.paths.home_to_home_exit) then return false end
    elseif config.locations.main_loop_route[basics.str_xyz(state.location)] then
        if not go_route(config.locations.main_loop_route, config.locations.home_exit) then return false end
    else
        return false
    end
    return true
end


function go_to_item_drop()
    if not config.locations.main_loop_route[basics.str_xyz(state.location)] then
        if not go_to_home() then return false end
        if not go_to_home_exit() then return false end
    end
    if not go_route(config.locations.main_loop_route, config.locations.item_drop) then return false end
    return true
end


function go_to_refuel()
    if not config.locations.main_loop_route[basics.str_xyz(state.location)] then
        if not go_to_home() then return false end
        if not go_to_home_exit() then return false end
    end
    if not go_route(config.locations.main_loop_route, config.locations.refuel) then return false end
    return true
end


function go_to_waiting_room()
    if not basics.in_area(state.location, config.locations.waiting_room_line_area) then
        if not go_to_home() then return false end
    end
    if not go_to(config.locations.waiting_room, nil, config.paths.home_to_waiting_room) then return false end
    return true
end


function go_to_mine_enter()
    if not go_route(config.locations.waiting_room_to_mine_enter_route) then return false end
    return true
end


function go_to_strip(strip)
    if state.location.y < config.locations.mine_enter.y or basics.in_location(state.location, config.locations.mine_enter) then
        if state.type == 'mining' then
            local bump = bumps[strip.orientation]
            strip = {
                x = strip.x + bump[1],
                y = strip.y + bump[2],
                z = strip.z + bump[3],
                orientation = strip.orientation
            }
        end
        if not go_to(strip, nil, config.paths.mine_enter_to_strip) then return false end
        return true
    end
end


function go_to_mine_exit(strip)
    if state.location.y < config.locations.mine_enter.y or (state.location.x == config.locations.mine_exit.x and state.location.z == config.locations.mine_exit.z) then
        if state.location.x == config.locations.mine_enter.x and state.location.z == config.locations.mine_enter.z then
            -- If directly under mine_enter, shift over to exit
            if not go_to_axis('z', config.locations.mine_exit.z) then return false end
        elseif state.location.x ~= config.locations.mine_exit.x or state.location.z ~= config.locations.mine_exit.z then
            -- If NOT directly under mine_exit go to proper y
            if not go_to_axis('y', strip.y + 1) then return false end
            if state.location.z ~= config.locations.mine_enter.z and strip.z ~= config.locations.mine_enter.z then
                -- If not in main_shaft, find your strip
                if not go_to_axis('x', strip.x) then return false end
            end
            if state.location.x ~= config.locations.mine_exit.x then
                -- If not in strip x = origin, go to main_shaft
                if not go_to_axis('z', config.locations.mine_enter.z) then return false end
            end
        end
        if not go_to(config.locations.mine_exit, nil, 'xzy') then return false end
        return true
    end
end


function safedig(direction)
    -- DIG IF BLOCK NOT ON BLACKLIST
    if not direction then
        direction = 'forward'
    end

    local block_name = ({inspect[direction]()})[2].name
    if block_name then
        for _, word in pairs(config.dig_disallow) do
            if string.find(string.lower(block_name), word) then
                return false
            end
        end

        return dig[direction]()
    end
    return true
end


function dump_items(omit)
    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 and ((not omit) or (not omit[turtle.getItemDetail(slot).name])) then
            turtle.select(slot)
            if not turtle.drop() then return false end
        end
    end
    return true
end



function prepare(min_fuel_amount)
    if state.item_count > 0 then
        if not go_to_item_drop() then return false end
        if not dump_items(config.fuelnames) then return false end
    end
    local min_fuel_amount = min_fuel_amount + config.fuel_padding
    if not go_to_refuel() then return false end
    if not dump_items() then return false end
    turtle.select(1)
    if turtle.getFuelLevel() ~= 'unlimited' then
        while turtle.getFuelLevel() < min_fuel_amount do
            if not turtle.suck(math.min(64, math.ceil(min_fuel_amount / config.fuel_per_unit))) then return false end
            turtle.refuel()
        end
    end
    return true
end


function calibrate()
    -- GEOPOSITION BY MOVING TO ADJACENT BLOCK AND BACK
    local sx, sy, sz = gps.locate()
--    if sx == config.interface.x and sy == config.interface.y and sz == config.interface.z then
--        refuel()
--    end
    if not sx or not sy or not sz then
        return false
    end
    for i = 1, 4 do
        -- TRY TO FIND EMPTY ADJACENT BLOCK
        if not turtle.detect() then
            break
        end
        if not turtle.turnRight() then return false end
    end
    if turtle.detect() then
        -- TRY TO DIG ADJACENT BLOCK
        for i = 1, 4 do
            safedig('forward')
            if not turtle.detect() then
                break
            end
            if not turtle.turnRight() then return false end
        end
        if turtle.detect() then
            return false
        end
    end
    if not turtle.forward() then return false end
    local nx, ny, nz = gps.locate()
    if nx == sx + 1 then
        state.orientation = 'east'
    elseif nx == sx - 1 then
        state.orientation = 'west'
    elseif nz == sz + 1 then
        state.orientation = 'south'
    elseif nz == sz - 1 then
        state.orientation = 'north'
    else
        return false
    end
    state.location = {x = nx, y = ny, z = nz}
    print('Calibrated to ' .. str_xyz(state.location, state.orientation))

    back()

    if basics.in_area(state.location, config.locations.home_area) then
        face(left_shift[left_shift[config.locations.homes.increment]])
    end

    return true
end


function initialize(session_id, config_values)
    -- INITIALIZE TURTLE

    state.session_id = session_id

    -- COPY CONFIG DATA INTO MEMORY
    for k, v in pairs(config_values) do
        config[k] = v
    end

    -- DETERMINE TURTLE TYPE
    state.peripheral_left = peripheral.getType('left')
    state.peripheral_right = peripheral.getType('right')
    if state.peripheral_left == 'chunkvial' or state.peripheral_right == 'chunkvial' or state.peripheral_left == 'chunk_vial' or state.peripheral_right == 'chunk_vial' then
        state.type = 'chunky'
        for k, v in pairs(config.chunky_turtle_locations) do
            config.locations[k] = v
        end
    else
        state.type = 'mining'
        for k, v in pairs(config.mining_turtle_locations) do
            config.locations[k] = v
        end
        if state.peripheral_left == 'modem' then
            state.peripheral_right = 'pick'
        else
            state.peripheral_left = 'pick'
        end
    end

    state.request_id = 1
    state.initialized = true
    return true
end


function getcwd()
    local running_program = shell.getRunningProgram()
    local program_name = fs.getName(running_program)
    return "/" .. running_program:sub(1, #running_program - #program_name)
end


function pass()
    return true
end


function dump(direction)
    if not face(direction) then return false end
    if ({inspect.forward()})[2].name ~= 'computercraft:turtle_advanced' then
        return false
    end
    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)
            turtle.drop()
        end
    end
    return true
end


function checkTags(data)
    if type(data.tags) ~= 'table' then
        return false
    end
    if not config.blocktags then
        return false
    end
    for k,v in pairs(data.tags) do
        if config.blocktags[k] then
            return true
        end
    end
    return false
end


function detect_ore(direction)
    local block = ({inspect[direction]()})[2]
    if block == nil or block.name == nil then
        return false
    elseif config.orenames[block.name] then
        return true
    elseif checkTags(block) then
        return true
    elseif block.name:lower():find("ore") then  
        return true
    end
    return false
end


function scan(valid, ores)
    local checked_left  = false
    local checked_right = false

    local f = str_xyz(getblock.forward())
    local u = str_xyz(getblock.up())
    local d = str_xyz(getblock.down())
    local l = str_xyz(getblock.left())
    local r = str_xyz(getblock.right())
    local b = str_xyz(getblock.back())

    if not valid[f] and valid[f] ~= false then
        valid[f] = detect_ore('forward')
        ores[f] = valid[f]
    end
    if not valid[u] and valid[u] ~= false then
        valid[u] = detect_ore('up')
        ores[u] = valid[u]
    end
    if not valid[d] and valid[d] ~= false then
        valid[d] = detect_ore('down')
        ores[d] = valid[d]
    end
    if not valid[l] and valid[l] ~= false then
        left()
        checked_left = true
        valid[l] = detect_ore('forward')
        ores[l] = valid[l]
    end
    if not valid[r] and valid[r] ~= false then
        right()
        if checked_left then
            right()
        end
        checked_right = true
        valid[r] = detect_ore('forward')
        ores[r] = valid[r]
    end
    if not valid[b] and valid[b] ~= false then
        if checked_right then
            right()
        elseif checked_left then
            left()
        else
            right(2)
        end
        valid[b] = detect_ore('forward')
        ores[b] = valid[b]
    end
end

-- Modified fastest_route function to use A* pathfinding
function fastest_route(area, pos, fac, end_locations)
    -- Convert end_locations to a more usable format for A*
    local goals = {}
    for loc_str in pairs(end_locations) do
        local x, y, z = loc_str:match("(%d+),(%d+),(%d+)")
        table.insert(goals, {x = tonumber(x), y = tonumber(y), z = tonumber(z)})
    end

    -- Find the path to the closest goal
    local shortest_path = nil
    for _, goal in ipairs(goals) do
        local path = a_star_pathfinding(pos, goal, distance)
        if path and (not shortest_path or #path < #shortest_path) then
            shortest_path = path
        end
    end

    if shortest_path then
        return path_to_directions(shortest_path)
    else
        return nil -- No path found
    end
end


function mine_vein(direction)
    if not face(direction) then return false end

    local start = str_xyz({x = state.location.x, y = state.location.y, z = state.location.z}, state.orientation)

    local valid = {}
    local ores = {}
    valid[str_xyz(state.location)] = true
    valid[str_xyz(getblock.back(state.location, state.orientation))] = false

    for i = 1, config.vein_max do
        -- Scan adjacent using get_neighbors for 3D
        local neighbors = get_neighbors(state.location)
        for _, neighbor in ipairs(neighbors) do
            -- Now includes z coordinate for 3D mining
            local neighbor_pos = {x = neighbor.x, y = neighbor.y, z = neighbor.z}
            scan(valid, ores, neighbor_pos)
        end
    
        local route = fastest_route(valid, state.location, state.orientation, ores)
        if not route then break end
    
        turtle.select(1)
        if not follow_route(route) then return false end
        ores[str_xyz(state.location)] = nil
    end

    if not follow_route(fastest_route(valid, state.location, state.orientation, {[start] = true})) then return false end

    if detect.up() then
        safedig('up')
    end

    return true
end

function clear_gravity_blocks()
    for _, direction in pairs({'forward', 'up'}) do
        while config.gravitynames[ ({inspect[direction]()})[2].name ] do
            safedig(direction)
            sleep(0.1)
        end
    end
    return true
end