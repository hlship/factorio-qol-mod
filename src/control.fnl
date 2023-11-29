(macro debug [val]
  `(log (serpent.line ,val)))

(debug {:message "Loading HiTech's QoL Mod"})

(fn entity-id [entity]
  (and entity (.. entity.name "#" entity.unit_number)))

(fn targets-entity? [surface entity inserter]
  (if (not inserter.drop_position)
      false
      (let [target (surface.find_entity entity.name inserter.drop_position)]
        (= target entity))))

(fn filter [pred coll]
  "Filter a sequential collection, returning a new collection."
  (let [result []]
    (each [_ value (ipairs coll)]
      (when (pred value)
        (table.insert result value)))
    result))

(fn modify-inserter [box inserter recipe]
  (let [behavior (inserter.get_or_create_control_behavior)
        condition behavior.circuit_condition]
    (debug {:modify-inserter (entity-id inserter) : condition})
    (inserter.connect_neighbour {:wire defines.wire_type.green
                                 :target_entity box})
    (tset behavior :circuit_mode_of_operation
          defines.control_behavior.inserter.circuit_mode_of_operation.enable_disable)
    (tset behavior :circuit_condition
          {:condition {:first_signal {:type :item :name recipe.name}
                       :constant 100}})))

(fn modify-box [player box inserter]
  (let [recipe (inserter.pickup_target.get_recipe)]
    (when recipe
      (tset box :storage_filter (. game.item_prototypes recipe.name))
      (player.create_local_flying_text {:text [""
                                               "Filter: "
                                               recipe.localised_name]
                                        :position box.position})
      (modify-inserter box inserter recipe))))

(fn on-build [event]
  (let [box event.created_entity
        player (game.get_player event.player_index)
        surface player.surface
        inserters (->> (surface.find_entities_filtered {:position box.position
                                                        :type :inserter
                                                        ; 2.0 to reach a long inserter
                                                        :radius 2.0})
                       (filter #(and (targets-entity? surface box $)
                                     (= :assembling-machine
                                        (?. $ :pickup_target :type)))))]
    (debug {:inserter-count (length inserters)})
    (when (= 1 (length inserters))
      (modify-box player box (. inserters 1))
      nil)))

(script.on_event defines.events.on_built_entity on-build
                 [{:filter :name :name :logistic-chest-storage}])

;; Export nothing
{}

