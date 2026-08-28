#/usr/bin/env nu
def main [] {
  let file = "starship.toml"
  let target = [$env.HOME, .config, $file] | path join
  let source = [$env.FILE_PWD, $file] | path join
  if ($target | path exists) {
    ^unlink $target 
  } 
  ^ln -s $source $target
}
