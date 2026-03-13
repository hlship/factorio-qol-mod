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

(fn modify-inserter [player box inserter item-name]
  ;; Don't modify inserters that already have any circuit connections
  (let [green-connector (inserter.get_wire_connector defines.wire_connector_id.circuit_green false)
        red-connector (inserter.get_wire_connector defines.wire_connector_id.circuit_red false)]
    (when (and (or (not green-connector) (= 0 green-connector.connection_count))
               (or (not red-connector) (= 0 red-connector.connection_count)))
      (let [behavior (inserter.get_or_create_control_behavior)
            inventory (box.get_inventory defines.inventory.chest)
            bar (inventory.get_bar)
            stack-size (. prototypes.item item-name :stack_size)
            stored-amount (inventory.get_item_count item-name)
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
        ;; Setup a green wire to read the box contents and maybe disable the inserter
        (let [inserter-connector (inserter.get_wire_connector defines.wire_connector_id.circuit_green true)
              box-connector (box.get_wire_connector defines.wire_connector_id.circuit_green true)]
          (inserter-connector.connect_to box-connector false defines.wire_origin.script))
        (tset behavior :circuit_enable_disable true)
        (tset behavior :circuit_condition
              {:first_signal {:name item-name}
               :constant new-target})
        ;; Provide an alert to the player
        (player.play_sound {:path :utility/wire_connect_pole})
        (player.create_local_flying_text {:text [:hls-qol.limit-set
                                                 (.. "[item=" item-name "]")
                                                 new-target]
                                          :position inserter.position})
        ;; Return true as feedback has been provided
        true))))

(fn modify-box [player box inserter]
  (let [recipe (inserter.pickup_target.get_recipe)
        ;; Recipe name may differ from item name (e.g. solid-fuel-from-petroleum-gas
        ;; produces solid-fuel), so extract the actual product item name.
        item-name (?. recipe :products 1 :name)]
    (when item-name
      (tset box :storage_filter item-name)
      (when (not (modify-inserter player box inserter item-name))
        (player.create_local_flying_text {:text [:hls-qol.filter-added
                                                 (.. "[item=" item-name "]")]
                                          :position box.position})))))

(fn on-build [event]
  (let [box event.entity
        player box.last_user
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

(fn on-robot-build [event]
  (when event.entity.last_user.mod_settings.hls-qol-robot-enabled.value
    (on-build event)))

(local filters [{:filter :name :name :storage-chest}])

;; Only applies to storage chests, as only storage chests have a storage_filter.
(script.on_event defines.events.on_built_entity on-build filters)
(script.on_event defines.events.on_robot_built_entity on-robot-build filters)
