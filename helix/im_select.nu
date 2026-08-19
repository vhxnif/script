# windows 1033
# mac com.apple.keylayout.US
export def normal-im-switch [] {
  ^im-select | into string | str trim | save -f (tmp)
  ^im-select com.apple.keylayout.US
}

export def insert-im-switch [] {
  let code = open (tmp)
  if ($code == null) {
    ^im-select com.apple.keylayout.US 
    return
  } 
  ^im-select $code 
}

def tmp [] {
  $"($env.HOME)/im-cache"
}
