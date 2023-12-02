(macro debug [val]
  `(when settings.global.hls-qol-debug-enabled.value
     (log (serpent.line ,val))))

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

(fn modify-inserter [player box inserter recipe]
  ;; Don't modify inserters that already have any circuit connections
  ;; (inserters do seem to start with a default behavior)
  (when (and (= 0 (length inserter.circuit_connected_entities.green))
             (= 0 (length inserter.circuit_connected_entities.red)))
    (let [behavior (inserter.get_or_create_control_behavior)
          inventory (box.get_inventory defines.inventory.chest)
          bar (inventory.get_bar)
          stack-size box.storage_filter.stack_size
          stored-amount (inventory.get_item_count recipe.name)
          ;; How many should we allow the inserter to move over?  If there's limit
          ;; via inventory bar, use that.
          new-target (if (< bar stack-size)
                         (* stack-size (- bar 1))
                         ;; There was no limit, so pretend there was one based on the setting.
                         (* player.mod_settings.hls-qol-default-stack-size.value
                            stack-size))]
      (debug {: bar : stack-size : stored-amount : new-target})
      ;; Clear the existing inventory limit
      (inventory.set_bar)
      ;; Setup a green wire to read the box contents and maybe disable the assembler
      (inserter.connect_neighbour {:wire defines.wire_type.green
                                   :target_entity box})
      (tset behavior :circuit_mode_of_operation
            defines.control_behavior.inserter.circuit_mode_of_operation.enable_disable)
      (tset behavior :circuit_condition
            {:condition {:first_signal {:type :item :name recipe.name}
                         :constant new-target}})
      ;; Provide an alert to the player
      (player.play_sound {:path :utility/wire_connect_pole})
      (player.create_local_flying_text {:text [:hls-qol.limit-set
                                               recipe.localised_name
                                               new-target]
                                        :position inserter.position})
      ;; Return true as feedback has been provided
      true)))

(fn modify-box [player box inserter]
  (let [recipe (inserter.pickup_target.get_recipe)]
    (when recipe
      (tset box :storage_filter (. game.item_prototypes recipe.name))
      (when (not (modify-inserter player box inserter recipe))
        (player.create_local_flying_text {:text [:hls-qol.filter-added
                                                 recipe.localised_name]
                                          :position box.position})))))

(fn on-build [event]
  (let [box event.created_entity
        player (game.get_player event.player_index)
        surface player.surface
        inserters (->> (surface.find_entities_filtered {:position box.position
                                                        :type :inserter
                                                        ; 2.0 to reach a long inserter
                                                        :radius 2.0})
                       ;; Keep only (hopefully one) inserters that
                       ;; targets the box and picks up from
                       ;; an assembler.
                       (filter #(and (targets-entity? surface box $)
                                     (= :assembling-machine
                                        (?. $ :pickup_target :type)))))
        _ (debug {:inserter-count (length inserters)})
        inserter (when (= 1 (length inserters))
                   (. inserters 1))]
    (when inserter
      (player.play_sound {:path :utility/confirm})
      (modify-box player box inserter))))

;; Only applies to storage chests, as only storage chests have a storage_filter.
(script.on_event defines.events.on_built_entity on-build
                 [{:filter :name :name :logistic-chest-storage}])

