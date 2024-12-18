{ inputs }:
with inputs.nixpkgs.lib;
with builtins;
rec {
  getPkgs =
    system: stable:
    import inputs.${if stable then "nixpkgs" else "nixpkgs-unstable"} { inherit system; };

  readDirFilter =
    path: lambda: (map (name: path + "/${name}") (attrNames (filterAttrs lambda (readDir path))));
  allIn = path: readDirFilter path (_: _: true);
  allNixIn = path: readDirFilter path (name: value: name != "default.nix" && value != "directory");
  dirsIn = path: readDirFilter path (_: value: value == "directory");
  subDirName = path: last (splitString "/" (toString path));
  recursiveAllIn =
    path:
    flatten (
      attrValues (
        mapAttrs (
          name: value: if value == "directory" then recursiveAllIn (path + "/${name}") else "${path}/${name}"
        ) (readDir path)
      )
    );

  bundleModules = path: (allNixIn path) ++ (allIn (path + "/self"));

  mkOptionFromSet =
    set:
    mapAttrs (
      name: value:
      let
        type = typeOf value;
      in
      if type == "string" then
        mkOption { type = types.str; }
      else if type == "list" then
        mkOption { type = with types; listOf str; }
      else
        mkOption { type = types.${typeOf value}; }
    ) set;
  mkOptionsForFiles =
    params:
    with params;
    mapAttrs (
      name: _:
      (
        {
          enable = mkEnableOption "";
        }
        // (
          if hasAttrByPath [ "args" ] params then (import (path + "/${name}") args).options or { } else { }
        )
      )
    ) (readDir path);
  enableOptions =
    list:
    listToAttrs (
      map (option: {
        name = option;
        value = {
          enable = mkDefault true;
        };
      }) list
    );
  filterNonExistingOption =
    options: list: intersectLists (mapAttrsToList (name: _: name) options) list;
  mergeConfigs =
    options: path: args:
    mkMerge (
      map (
        option:
        let
          module = (import option) args;
          imports = map (subModule: (import subModule) args) (module.imports or [ ]);
          config = mkMerge (
            [ (filterAttrs (name: _: name != "imports" && name != "options") module) ] ++ imports
          );
        in
        mkIf (options.${subDirName option}.enable) config
      ) (dirsIn path)
    );

  hideDesktopEntries =
    entries:
    listToAttrs (
      map (opt: {
        name = opt;
        value = {
          name = "";
          noDisplay = true;
        };
      }) entries
    );
}
