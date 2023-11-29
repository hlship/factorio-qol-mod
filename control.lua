-- HiTech's Quality of Life

local line = serpent.line

log(line {message= "QoL loading"})

function entity_id(entity)
    return entity and entity.name .. "#" .. entity.unit_number
end

-- Predicate: does the inserter target the entity.
-- Because of order of operations, the on_built_entity event seems to precede
-- when the game sets the inserter.drop_target, so we have to puzzle it out
-- from inserter.drop_position.
function targets_entity(surface, entity, inserter)

--[[   log(line {inserter=entity_id(inserter), 
            entity=entity_id(entity),
            drop_target=entity_id(inserter.drop_target)}) ]]

  if inserter.drop_position == nil then return false end

  local target = surface.find_entity(entity.name, inserter.drop_position)

--[[   log(line {inserter=entity_id(inserter),
            target=entity_id(target)})
 ]]
  return target == entity

end

script.on_event(defines.events.on_built_entity, function(event)

    local box = event.created_entity
    local player = game.get_player(event.player_index)
    local surface = player.surface

    log(line {placed=entity_id(box), 
              pos=box.position,   
              bounds=box.bounding_box})

    local inserters = surface.find_entities_filtered {
        position=box.position,
        type="inserter",
        -- 2.0 to reach a long inserter
        radius=2.0
    }

    local incoming_inserters = {}

    for _, inserter in pairs(inserters) do
      if targets_entity(surface, box, inserter)
         and inserter.pickup_target
         and inserter.pickup_target.type == "assembling-machine"
      then
        table.insert(incoming_inserters, inserter)
      end
    end

    -- log(line {incoming_inserter_count=#incoming_inserters})

    if #incoming_inserters ~= 1 then return end

    local inserter = incoming_inserters[1]

    local recipe = inserter.pickup_target.get_recipe()

    if recipe == nil then return end

    -- Set the filter from the inserter's recipe

    box.storage_filter =  game.item_prototypes[recipe.name]

    player.create_local_flying_text {text={"", "Filter: ",
                                           recipe.localised_name},
                                     position=box.position}

    -- If the inserter does not yet have a green circuit, then we can do a lot more.
    
    local behavior = inserter.get_control_behavior()

    if behavior ~= nil then return end

    behavior = inserter.get_or_create_control_behavior()
    inserter.connect_neighbor {wire=defines.wire_type.green, target_entity=box}

    behavior.circuit_mode_of_operation = defines.control_behavior.inserter.circuit_mode_of_operation.enable_disable
    behavior.circuit_condition = {condition={
      first_signal="item",
      constant=100
    }}

    local inventory = box.get_inventory(defines.inventory.chest)
    local slots = inventory.get_bar()
    local stack_size = box.storage_filter.stack_size
    local stored_amount = inventory.get_item_count(recipe.name)

    log(line {contents=inventory.get_contents(),
              bar=slots,
              slots=#inventory,
              stack_size=stack_size,
              stored=stored_amount})
 
    -- TODO: When no real bar
    local limit = stack_size * (slots - 1)

    -- When the game replaces an existing container, it copies over
    -- the container's inventory, including its bar

    inventory.set_bar() -- disable bar



end, {{filter="name", name="logistic-chest-storage"}}) 

