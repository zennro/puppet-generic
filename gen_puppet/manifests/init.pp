# Author: Kumina bv <support@kumina.nl>

import "kservice.pp"
import "concat.pp"
import "ekfile.pp"
# Actual puppet modules
import "master.pp"
import "queue.pp"

# Class: gen_puppet
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
class gen_puppet {
# TODO For now, let's make this step optional
#  include gen_puppet::puppet_conf
  include gen_base::augeas
  include gen_base::facter

  kpackage {
    ["checkpuppet","puppet-common"]:
      ensure => latest;
    "puppet":
      ensure => latest,
      notify => Exec["reload-puppet"];
  }

  exec { "reload-puppet":
    command     => "/usr/bin/touch /etc/puppet/reloadpuppetd",
    creates     => "/etc/puppet/reloadpuppetd",
    refreshonly => true,
    require     => Kpackage["puppet-common","checkpuppet"],
  }

  # Workaround for http://www.mikeperham.com/2009/05/25/memory-hungry-ruby-daemons/
  cron { "Restart puppet every day.":
    command => "/usr/bin/touch /etc/puppet/reloadpuppetd",
    hour    => 0,
    minute  => 0,
    user    => "root",
  }
}

# Class: gen_puppet::puppet_conf
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
class gen_puppet::puppet_conf {
  # Setup the default config file
  concat { '/etc/puppet/puppet.conf':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Kpackage["puppet-common"],
    notify  => Exec["reload-puppet"],
  }

  # Already define all the sections
  concat::add_content {
    "main section":
      target  => '/etc/puppet/puppet.conf',
      content => "[main]",
      order   => '10';
    "agent section":
      target  => '/etc/puppet/puppet.conf',
      content => "\n[agent]",
      order   => '20';
    "master section":
      target  => '/etc/puppet/puppet.conf',
      content => "\n[master]",
      order   => '30';
  }
}

# Define: gen_puppet::set_config
#
# Parameters:
#  configfile
#    Undocumented
#  section
#    Undocumented
#  order
#    Undocumented
#  var
#    Undocumented
#  value
#    Undocumented
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
define gen_puppet::set_config ($value, $configfile = '/etc/puppet/puppet.conf', $section = 'main', $order = false, $var = false) {
  # If no variable name is set, use the name
  if $var {
    $real_var = $var
  } else {
    $real_var = $name
  }

  # If order is set, don't use section
  if $order {
    $real_order = $order
  } else {
    # Based on section, set order
    $real_order = $section ? {
      'main'   => "15",
      'agent'  => "25",
      'master' => "35",
      'queue'  => "45",
      default  => fail("No order given and no known section given."),
    }
  }

  concat::add_content { $name:
    target  => $configfile,
    content => "${real_var} = ${value}",
    order   => $real_order,
  }
}
