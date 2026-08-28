export def git_commit_fix [n: number] {
   for i in 1..$n {
    git commit --amend --author="vhxnif <chen517000@live.com>" --no-edit
    git rebase --continue
  }
}

export def git_cherry_pick [branch: string, header: number] {
  # git cherry-pick {start}^..{end} 
  if $header  <= 1 {
    return 
  }
  let commits = ^git log $branch --oneline -n $header
  | lines 
  | each { |x|
    $x | split row ' ' | first
  }
  let end = $commits | first
  let start = $commits | last 
  ^git cherry-pick $"($start)^..($end)"
}
