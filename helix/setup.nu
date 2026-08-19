#!/usr/bin/env nu
def main [] {
  let host_name = sys host | get name
  if not ("Darwin" == $host_name) {
    print $"($host_name) not supported."
    return
  }
  # link config file
  mac_link_config 
  mac_check_lsp 
}

def mac_link_config [] {
  ["config.toml", "languages.toml"]
  | each { |x|
    let target = [$env.HOME, ".config", "helix", $x] | path join
    let source = [$env.FILE_PWD, $x] | path join
    if ($target | path exists) {
      ^unlink $target 
    }
    ^ln -s $source $target
  }
  | ignore 
}

def mac_check_lsp [] {
  [
    [type name command url];
    [brew im-select "brew tap daipeihust/tap\nbrew install im-select" "https://github.com/daipeihust/im-select"]
    [brew biome "brew install biome" "https://biomejs.dev/guides/manual-installation/"]
    [brew zed "brew install --cask zed" "https://zed.dev/docs/installation"]
    [brew go "brew install go" "https://formulae.brew.sh/formula/go"]
    [brew "markdown-oxide" "brew install markdown-oxide" "https://github.com/Feel-ix-343/markdown-oxide"]
    [brew ruff "brew install ruff" ""]
    [bun "pyright"  "" ""]
    [bun "@astrojs/language-server"  "" ""]
  ]
  | where match $it.type {
      'brew' =>  {
        which $it.name | is-empty 
      },
      "bun" => {
        ^bun list -g | find $it.name | is-empty 
      }
    }
}
