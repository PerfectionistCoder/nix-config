$(cd $NIX_CONFIG_HOME; nix develop .#${1?'Please specify flake shell'} --command zsh)