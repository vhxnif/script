def main [] {
  ^java -jar (find_jar) -a -     
}

def find_jar [] {
  ls $env.FILE_PWD
  | where $it.name =~ 'google-java-format.*.jar'
  | get name
  | first
  | path expand
}
