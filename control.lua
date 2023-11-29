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

    log(line {recipe=recipe.name})


end, {{filter="name", name="logistic-chest-storage"}}) 

