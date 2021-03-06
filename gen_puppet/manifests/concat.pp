# Author: Kumina bv <support@kumina.nl>

# A system to construct files using fragments from other files or templates.
#
# This requires at least puppet 0.25 to work correctly as we use some 
# enhancements in recursive directory management and regular expressions
# to do the work here.
#
# USAGE:
# The basic use case is as below:
#
# concat{"/etc/named.conf": 
#    notify => Service["named"]
# }
#
# concat::fragment{"foo.com_config":
#    target  => "/etc/named.conf",
#    order   => 10,
#    content => template("named_conf_zone.erb")
# }
#
# This will use the template named_conf_zone.erb to build a single 
# bit of config up and put it into the fragments dir.  The file
# will have an number prefix of 10, you can use the order option
# to control that and thus control the order the final file gets built in.
#
# SETUP:
# The class concat::setup defines a variable $concatdir - you should set this
# to a directory where you want all the temporary files and fragments to be
# stored.  Avoid placing this somewhere like /tmp since you should never
# delete files here, puppet will manage them.
#
# If you are on version 0.24.8 or newer you can set $puppetversion to 24 in 
# concat::setup to enable a compatible mode, else just leave it on 25
#
# If your sort utility is not in /bin/sort please set $sort in concat::setup
# 
# Before you can use any of the concat features you should include the 
# class concat::setup somewhere on your node first.
#
# DETAIL:
# We use a helper shell script called concatfragments.sh that gets placed
# in /usr/local/bin to do the concatenation.  While this might seem more 
# complex than some of the one-liner alternatives you might find on the net
# we do a lot of error checking and safety checks in the script to avoid 
# problems that might be caused by complex escaping errors etc.
# 
# LICENSE:
# Apache Version 2
#
# HISTORY:
# 2010/02/19 - First release based on earlier concat_snippets work
# 2011/05/31 - Fair amount of changes
#
# CONTACT:
# R.I.Pienaar <rip@devco.net> 
# Volcane on freenode
# @ripienaar on twitter
# www.devco.net
#
# This version modified by Kumina bv <info@kumina.nl>.

# Sets up the concat system, you should set $concatdir to a place
# you wish the fragments to live, this should not be somewhere like
# /tmp since ideally these files should not be deleted ever, puppet
# should always manage them
#
# $puppetversion should be either 24 or 25 to enable a 24 compatible
# mode, in 24 mode you might see phantom notifies this is a side effect
# of the method we use to clear the fragments directory.
#
# The regular expression below will try to figure out your puppet version
# but this code will only work in 0.24.8 and newer.
#
# $sort keeps the path to the unix sort utility
#
# It also copies out the concatfragments.sh file to /usr/local/bin

# Class: concat::setup
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
class concat::setup {
  $concatdir    = "/var/lib/puppet/concat"
  $majorversion = regsubst($puppetversion, '^[0-9]+[.]([0-9]+)[.][0-9]+$', '\1')
  $sort         = "/usr/bin/sort"

  file {
    "/usr/local/bin/concatfragments.sh":
      mode    => 755,
      content => template("gen_puppet/concat/concatfragments.sh");
    $concatdir:
      ensure  => directory,
      mode    => 755;
  }
}

# Define: concat::add_content
#
# Parameters:
#  content
#    Undocumented
#  order
#    Undocumented
#  ensure
#    Undocumented
#  target
#    Undocumented
#  linebreak
#    Setting this to false allows for inline additions
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
define concat::add_content($target, $content=false, $order=15, $ensure=present, $linebreak=true, $contenttag=false, $exported=false) {
  if $exported {
    if $contenttag {
      $export = true
    } else {
      fail("Exported concat fragment without tag: ${name}")
    }
  }
  $safe_target_name = regsubst($target, '/', '_', 'G')
  $safe_name        = regsubst("${target}_fragment_${name}", '/', '_', 'G')
  $concatdir        = $concat::setup::concatdir
  $fragdir          = "${concatdir}/${safe_target_name}"
  $body             = $content ? {
    false   => $linebreak ? {
      false => $name,
      true  => "${name}\n",
    },
    default => $linebreak ? {
      false => $content,
      true  => "${content}\n",
    },
  }

  # if body is passed, use that, else if $ensure is in symlink form, make a symlink
  case $body {
    false: {
      case $ensure {
        '', 'absent', 'present', 'file', 'directory': {
          crit('No content specified')
        }
      }
    }
    default: {
     if $export {
        Ekfile{ content => $body }
      } else {
        File{ content => $body }
      }
    }
  }

  if $export {
    @@ekfile { "${fragdir}/fragments/${order}_${safe_name};${fqdn}":
      ensure => $ensure,
      notify => Exec["concat_${target}"],
      tag    => $contenttag;
    }
  } else {
    file { "${fragdir}/fragments/${order}_${safe_name}":
      ensure => $ensure,
      notify => Exec["concat_${target}"];
    }
  }
}

# Sets up so that you can use fragments to build a final config file, 
#
# OPTIONS:
#  - mode       The mode of the final file
#  - owner      Who will own the file
#  - group      Who will own the file
#  - force      Enables creating empty files if no fragments are present
#  - warn       Adds a normal shell style comment top of the file indicating
#               that it is built by puppet
#
# ACTIONS:
#  - Creates fragment directories if it didn't exist already
#  - Executes the concatfragments.sh script to build the final file, this script will create
#    directory/fragments.concat and copy it to the final destination.   Execution happens only when:
#    * The directory changes 
#    * fragments.concat != final destination, this means rebuilds will happen whenever 
#      someone changes or deletes the final file.  Checking is done using /usr/bin/cmp.
#    * The Exec gets notified by something else - like the concat::fragment define
#  - Defines a File resource to ensure $mode is set correctly but also to provide another 
#    means of requiring
#
# ALIASES:
#  - The exec can notified using Exec["concat_/path/to/file"] or Exec["concat_/path/to/directory"]
#  - The final file can be referened as File["/path/to/file"] or File["concat_/path/to/file"]  
# Define: concat
#
# Parameters:
#  owner
#    Undocumented
#  group
#    Undocumented
#  warn
#    Undocumented
#  force
#    Undocumented
#  remove_fragments
#    Undocumented
#  mode
#    Undocumented
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
define concat($ensure="present", $mode=0644, $owner="root", $group="root", $warn=false, $force=false, $purge_on_testpm=false, $purge_on_pm=true, $testpms=[], $alt_destination=false, $replace=true) {
  require concat::setup

  if $settings::masterport != '8140' {
    $purge = $purge_on_testpm
  } else {
    $purge = $purge_on_pm
  }
  $safe_name = regsubst($name, '/', '_', 'G')
  $concatdir = $concat::setup::concatdir
  $version   = $concat::setup::majorversion
  $sort      = $concat::setup::sort
  $fragdir   = "${concatdir}/${safe_name}"
  $warnflag = $warn ? {
    true    => "-w",
    default => "",
  }
  $forceflag = $force ? {
    true    => "-f",
    default => "",
  }

  file {
    $fragdir:
      force  => true,
      ensure => $ensure ? {
        "present" => "directory",
        default   => "absent",
      };
    "${fragdir}/fragments":
      ensure  => $ensure ? {
        "present" => "directory",
        default   => "absent",
      },
      recurse => true,
      purge   => $purge,
      force   => true,
      ignore  => [".svn", ".git"],
      notify  => Exec["concat_${name}"];
    "${fragdir}/fragments.concat":
      force   => true,
      ensure  => $ensure;
    $name:
      owner    => $owner,
      group    => $group,
      checksum => "md5",
      mode     => $mode,
      ensure   => $ensure,
      alias    => "concat_${name}";
  }

  if $ensure == "present" {
    $exec_name = $alt_destination ? {
      false   => $name,
      default => $alt_destination,
    }

    File <| notify == Exec["concat_${name}"] |> {
      notify => Exec["concat_${exec_name}"],
    }

    exec { "concat_${exec_name}":
      user      => "root",
      group     => $group,
      alias     => "concat_${fragdir}",
      unless    => $alt_destination ? {
        false   => "/usr/local/bin/concatfragments.sh -o ${name} -d ${fragdir} -t -s ${sort} ${warnflag} ${forceflag}",
        default => "/usr/local/bin/concatfragments.sh -o ${alt_destination} -d ${fragdir} -t -s ${sort} ${warnflag} ${forceflag}",
      },
      command   => $alt_destination ? {
        false   => "/usr/local/bin/concatfragments.sh -o ${name} -d ${fragdir} -s ${sort} ${warnflag} ${forceflag}",
        default => "/usr/local/bin/concatfragments.sh -o ${alt_destination} -d ${fragdir} -s ${sort} ${warnflag} ${forceflag}",
      },
      notify    => File[$name],
      subscribe => File[$fragdir],
      creates   => $replace ? {
        false   => $exec_name,
        default => undef,
      },
      require   => [File["/usr/local/bin/concatfragments.sh","${fragdir}/fragments","${fragdir}/fragments.concat"]];
    }
  } else {
    # Although this could be done via a selector in the command parameter in the exec above, this reads easier.
    # The exec is needed due to dependencies.
    exec { "concat_${name}":
      alias       => "concat_${fragdir}",
      refreshonly => true,
      command     => "/bin/true",
    }
  }
}
