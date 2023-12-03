(ns build
  (:require [babashka.fs :as fs]
            [babashka.process :as p]
            [cheshire.core :as cheshire]))

(def mod-dir "out/lua")

(defn clean []
  (fs/delete-tree "out"))

(def allowed-globals
  (str "game,script,remote,commands,settings,rcon,rendering,defines,global,data"
       ",log,localized_print,table_size,serpent"))

(defn build-module
  "Compiles source Fennel files in `src` to Lua files in `target/lua`, and copies resources."
  []
  (fs/delete-tree mod-dir)
  (fs/create-dirs mod-dir)
  (doseq [f (fs/glob "src" "**.fnl")]
    (let [out-path (str "out/lua/"
                        (-> f
                            fs/strip-ext
                            fs/file-name)
                        ".lua")
          in-path (str f)]
      (println "Compiling" in-path "...")
      (let [proc (p/process {:out out-path
                             :inherit true} "fennel --correlate --compile"
                            "--globals" allowed-globals
                            in-path)
            exit (-> proc deref :exit)]
        (when-not (zero? exit)
          (println (str "Error compiling " in-path ":" exit))))))
  (println "Copying resources ...")
  (fs/copy "LICENSE" mod-dir)
  (fs/copy-tree "resources" mod-dir))

(defn watch
  []
  (p/shell "watchexec --clear --notify"
           "--watch" "src"
           "--watch" "resources"
           "--debounce=500ms"
           "bb" "build"))

(defn zip
  []
  (build-module)
  (let [version (-> (slurp "resources/info.json")
                    (cheshire/parse-string true)
                    :version)
        zip-file (str "out/hitech-qol_" version ".zip")]
    (println "Creating:" zip-file)
    (fs/zip zip-file [mod-dir] {:root mod-dir})))