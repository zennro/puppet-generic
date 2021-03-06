# Author: Kumina bv <support@kumina.nl>

# Define: ekfile
#
# Parameters:
#  mode
#    Undocumented
#  source
#    Undocumented
#  recurse
#    Undocumented
#  path
#    Undocumented
#  target
#    Undocumented
#  content
#    Undocumented
#  force
#    Undocumented
#  owner
#    Undocumented
#  purge
#    Undocumented
#  group
#    Undocumented
#  ignore
#    Undocumented
#  ensure
#    Undocumented
#  backup
#    Store a backup of the file in the filebucket.
#
# Actions:
#  Undocumented
#
# Depends:
#  gen_puppet
#
define ekfile ($ensure="present", $source=false, $path=false, $target=false, $content=false, $owner="root", $group="root", $mode="644", $recurse=false, $force=false, $purge=false, $ignore=false, $backup=false) {
  $kfilename = regsubst($name,'^(.*);.*$','\1')
  if !defined(File["${kfilename}"]) {
    file { "${kfilename}":
      ensure  => $ensure,
      source  => $source ? {
        false   => undef,
        default => $source,
      },
      path    => $path ? {
        false   => undef,
        default => $path,
      },
      target  => $target ? {
        false   => undef,
        default => $target,
      },
      content => $content ? {
        false   => undef,
        default => $content,
      },
      owner   => $owner,
      group   => $group,
      mode    => $mode,
      recurse => $recurse,
      force   => $force,
      purge   => $purge,
      ignore  => $ignore ? {
        false   => undef,
        default => $ignore,
      },
      backup  => $backup,
    }
  }
}
