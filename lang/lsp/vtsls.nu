#!/usr/bin/env nu
def main [] {
    let home_dir = $env.HOME? | default ($env.USERPROFILE? | default "")
    let host_name = (sys host).name
    let is_windows = $host_name | str contains "Windows"
    let is_mac = $host_name | str contains "Darwin"
    let config_path: list<string> = if $is_windows {
      [AppData Local Zed languages]
    } else if $is_mac {
      [Library "Application Support" Zed languages]
    } else {
      [.local share zed languages]
    }     
    let script = [vtsls node_modules @vtsls language-server bin vtsls.js]
    let run_path = $home_dir | path join ...($config_path ++ $script) 
    print $"vtls run ($run_path)"
    ^bun ($run_path) --stdio
}
