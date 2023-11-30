(ns build
  (:require [babashka.fs :as fs]
            [babashka.process :as p]))

(defn clean []
  (fs/delete-tree "out"))

(defn compile-to-lua
  "Compiles source Fennel files in `src` to Lua files in `target/lua`, and copies resources."
  []
  (fs/delete-tree "out/lua")
  (fs/create-dirs "out/lua")
  (doseq [f (fs/glob "src" "**.fnl")]
    (let [out-path (str "out/lua/"
                        (-> f
                            fs/strip-ext
                            fs/file-name)
                        ".lua")
          in-path (str f)]
      (println "Compiling" in-path "...")
      (let [proc (p/process {:out out-path
                             :inherit true} "fennel --correlate --compile" in-path)
            exit (-> proc deref :exit)]
        (when-not (zero? exit)
          (println (str "Error compiling " in-path ":" exit)) ) )))
  (println "Copying resources ...")
  (fs/copy "LICENSE" "out/lua")
  (fs/copy-tree "resources" "out/lua"))

(defn watch
  []
  (p/shell "watchexec --clear --notify"
           "--watch" "src"
           "--watch" "resources"
           "--debounce=500ms"
           "bb" "build" ))