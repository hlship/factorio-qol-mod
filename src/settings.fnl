(: data :extend [{:type :bool-setting
                  :name :hls-qol-debug-enabled
                  :default_value false
                  :setting_type :runtime-global}
                 {:type :int-setting
                  :name :hls-qol-default-stack-size
                  :default_value 2
                  :minimum_value 1
                  :maximum_value 48
                  :setting_type :runtime-per-user}
                 {:type :bool-setting
                  :name :hls-qol-robot-enabled
                  :default_value true
                  :setting_type :runtime-per-user}])

