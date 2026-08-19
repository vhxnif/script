#!/usr/bin/env nu
# JDTLS Launcher with VS Code-style parameters
# Usage: nu start-jdtls.nu /path/to/java/project
def main [
    --jdtls-home: string = "",
    --java-home: string = "",
    --data-dir: string = "",
] {
    # Find JDTLS home
    let jdtls_path = if $jdtls_home != "" {
        $jdtls_home
    } else {
        find_jdtls_home
    }
    
    if $jdtls_path == "" {
        print "Error: Could not find JDTLS installation."
        print "Please install the Java extension in Cursor/VS Code, or specify --jdtls-home"
        exit 1
    }
    
    print $"Using JDTLS from: ($jdtls_path)"
    
    # Find Java executable
    let java_exe = if $java_home != "" {
        $"($java_home)/bin/java"
    } else if ($env.JAVA_HOME? | default "") != "" {
        $"($env.JAVA_HOME)/bin/java"
    } else {
        "java"
    }
    
    # Check Java version
    let java_version = get_java_version $java_exe
    print $"Java version: ($java_version)"
    
    # Find launcher jar
    let launcher = find_launcher $jdtls_path
    if $launcher == "" {
        print "Error: Could not find Eclipse launcher jar."
        exit 1
    }
    
    print $"Using launcher: ($launcher)"
    
    # Get config directory
    let config_dir = get_config_dir $jdtls_path
    print $"Using config: ($config_dir)"

    # project path
    let project_path = get_project_path
    
    # Get data directory
    let data_path = if $data_dir != "" {
        $data_dir
    } else {
        generate_data_dir $project_path
    }
    
    print $"Using data directory: ($data_path)"
    
    # Build and execute command
    print "\nStarting JDTLS..."
    run_jdtls $java_exe $java_version $config_dir $launcher $data_path $project_path
}

# Find JDTLS home directory
def find_jdtls_home [] {
    let home_dir = $env.HOME? | default ($env.USERPROFILE? | default "")
    
    # Check Cursor extensions
    let cursor_path = $"($home_dir)/.cursor/extensions" | path expand
    let cursor_jdtls = find_jdtls_in_dir $cursor_path
    if $cursor_jdtls != "" {
        return $cursor_jdtls
    }
    
    # Check VS Code extensions
    let vscode_path = $"($home_dir)/.vscode/extensions" | path expand
    let vscode_jdtls = find_jdtls_in_dir $vscode_path
    if $vscode_jdtls != "" {
        return $vscode_jdtls
    }
    
    # Check JDTLS_PATH environment variable
    if ($env.JDTLS_PATH? | default "") != "" {
        return $env.JDTLS_PATH
    }
    
    ""
}

# Find JDTLS in extensions directory
def find_jdtls_in_dir [base_path: string] {
    if not ($base_path | path exists) {
        return ""
    }
    
    # Find redhat.java extension directories
    let entries = try {
        ls $base_path | where name =~ "redhat.java" | get name
    } catch {
        []
    }
    
    if ($entries | length) == 0 {
        return ""
    }
    
    # Get the latest version
    let latest = $entries | sort | last
    let server_path = $"($latest)/server"
    
    if ($server_path | path exists) {
        $server_path
    } else {
        ""
    }
}

# Get Java version
def get_java_version [java_exe: string] {
    let version_output = try {
        ^$java_exe -version | complete | get stderr
    } catch {
        ""
    }
    
    # Parse version number
    let version_line = $version_output | find "version"
    if ($version_line | length) > 0 {
        let line = $version_line | first
        if ($line | str contains '"') {
            $line | split row '"' | get 1 | split row '.' | first
        } else {
            "21"
        }
    } else {
        "21"
    }
}

# Find Eclipse launcher jar
def find_launcher [jdtls_path: string] {
    let plugins_dir = $"($jdtls_path)/plugins"
    
    if not ($plugins_dir | path exists) {
        return ""
    }
    
    # Find equinox launcher
    let launchers = try {
        ls $plugins_dir | where name =~ "org.eclipse.equinox.launcher_" | get name
    } catch {
        []
    }
    
    if ($launchers | length) > 0 {
        $launchers | sort | last
    } else {
        ""
    }
}

# Get config directory based on OS
def get_config_dir [jdtls_path: string] {
    let os_name = $env.OS? | default ""
    let host_name = (sys host).name
    
    let is_windows = $os_name | str contains "Windows"
    let is_mac = $host_name | str contains "Darwin"
    
    let config_name = if $is_windows {
        "config_win"
    } else if $is_mac {
        "config_mac"
    } else {
        "config_linux"
    }
    
    $"($jdtls_path)/($config_name)"
}

def get_project_path [] {
    let try_git = ^git rev-parse --show-toplevel | complete 
    if ($try_git.exit_code == 0) {
      $try_git.stdout | str trim 
    } else {
      pwd
    }
}

# Generate data directory path
def generate_data_dir [project_path: string] {
    #let project_name = $project_path | path basename
    let project_hash = $project_path | hash sha256 | str substring 0..16
    
    let os_check = $env.OS? | default ""
    let host_check = (sys host).name
    
    let is_windows = $os_check | str contains "Windows"
    let is_mac = $host_check | str contains "Darwin"
    
    let base_dir = if $is_windows {
        $env.APPDATA? | default ($env.TEMP? | default "C:/temp")
    } else if $is_mac {
        $"($env.HOME? | default "~")/Library/Caches"
    } else {
        $"($env.HOME? | default "~")/.cache"
    }
    
    $"($base_dir)/jdtls/jdtls-($project_hash)"
}

# Run JDTLS with all arguments
def run_jdtls [
    java_exe: string,
    java_version: string,
    config_dir: string,
    launcher: string,
    data_dir: string,
    project_path: string,
] {
    # Parse major version
    let major_version = try {
        $java_version | split row "." | first | into int
    } catch {
        21
    }
    
    # JDK 24+ args
    let jdk24_args = if $major_version >= 24 {
        ["-Djdk.xml.maxGeneralEntitySizeLimit=0", "-Djdk.xml.totalEntitySizeLimit=0"]
    } else {
        []
    }
    
    # Eclipse base parameters
    let eclipse_args = [
        "-Declipse.application=org.eclipse.jdt.ls.core.id1"
        "-Dosgi.bundles.defaultStartLevel=4"
        "-Declipse.product=org.eclipse.jdt.ls.core.product"
    ]
    
    # OSGi shared configuration
    let osgi_args = [
        "-Dosgi.checkConfiguration=true"
        $"-Dosgi.sharedConfiguration.area=($config_dir)"
        "-Dosgi.sharedConfiguration.area.readOnly=true"
        "-Dosgi.configuration.cascaded=true"
    ]
    
    # Module system
    let module_args = [
        "--add-modules=ALL-SYSTEM"
        "--add-opens"
        "java.base/java.util=ALL-UNNAMED"
        "--add-opens"
        "java.base/java.lang=ALL-UNNAMED"
        "--add-opens"
        "java.base/sun.nio.fs=ALL-UNNAMED"
    ]
    
    # VS Code-style JVM parameters
    let jvm_args = [
        "-DDetectVMInstallationsJob.disabled=true"
        "-Dfile.encoding=UTF-8"
        "-XX:+UseParallelGC"
        "-XX:GCTimeRatio=4"
        "-XX:AdaptiveSizePolicyWeight=90"
        "-Xmx2G"
        "-Xms100m"
        "-Xlog:disable"
    ]
    
    # Debug and performance
    let debug_args = [
        "-XX:+HeapDumpOnOutOfMemoryError"
        $"-XX:HeapDumpPath=($project_path)"
        "-Daether.dependencyCollector.impl=bf"
    ]

    let lombok_args = [
         $"-javaagent:(
            ls ($config_dir | path dirname | path dirname | path join lombok)
            | first 
            | get name
            | path expand 
        )"
    ]
    
    # Core args
    let core_args = [
        "-jar"
        $launcher
        "-configuration"
        $config_dir
        "-data"
        $data_dir
    ]
    
    # Combine all args
    let all_args = $jdk24_args ++ $eclipse_args ++ $osgi_args ++ $module_args ++ $jvm_args ++ $debug_args ++ $lombok_args ++ $core_args
    
    # Print command for debugging
    print $"($java_exe) ($all_args | str join ' ')"
    
    # Execute
    exec $java_exe ...$all_args
}
