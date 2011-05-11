class gen_puppet::master ($servertype = 'passenger') {
	# Install the packages
	kpackage {
		"puppetmaster":
			ensure  => present,
			require => Kfile["/etc/default/puppetmaster"];
		"puppetmaster-common":
			ensure  => latest;
	}

	# Keep in mind this only counts for the default puppetmaster,
	# not for any additional puppetmasters!
	kfile { "/etc/default/puppetmaster":
		content => template('gen_puppet/master/default/puppetmaster'),
	}

	# These are needed for customer puppetmaster config when run
	# via passenger.
	kfile { ["/usr/local/share/puppet","/usr/local/share/puppet/rack"]:
		ensure  => directory;
	}
}

# gen_puppet::master::config
#
# Creates a custom puppetmaster. Use name 'default' if you want a
# single, default puppetmaster. (That way everything that usually
# says 'puppetmaster-myname' will just be 'puppetmaster'.) This
# type currently only supports passenger-based puppetmasters. It
# seems the way forward anyway.
#
# Keep in mind that since this is a generic class, we only provide
# the actual puppetmaster settings. We do not provide settings for
# the webserver, the database, puppet queue daemon or anything
# else.
#
define gen_puppet::master::config ($configfile = "/etc/puppet/puppet.conf",
		$debug = false, $factpath = '$vardir/lib/facter',
		$fileserverconf = "/etc/puppet/fileserver.conf",
		$logdir = "/var/log/puppet", $pluginsync = true,
		$rackroot = "/usr/local/share/puppet/rack", $rundir = "/var/run/puppet",
		$ssldir = "/var/lib/puppet/ssl", $vardir = "/var/lib/puppet") {
	# If the name is 'default', we want to change the puppetmaster name (pname)
	# we're using for this instance to something without crud.
	if $name == 'default' {
		$pname = 'puppetmaster'
	} else {
		$sanitized_name = regsubst($name, '[^a-zA-Z0-9\-_]', '_', 'G')
		$pname = "puppetmaster-${sanitized_name}"
	}

	# This is the rack main directory for the app.
	$rackdir = "${rackroot}/${pname}"

	# Create the rack directories.
	kfile { ["${rackdir}","${rackdir}/public","${rackdir}/tmp"]:
		ensure => 'directory',
	}

	# Create the config file for the rack environment
	concat { "${rackdir}/config.ru":
		owner => "puppet",
		group => "puppet",
		mode  => 0640,
	}

	gen_puppet::concat::add_content { "Add header for config.ru for puppetmaster ${pname}":
		target   => "${rackdir}/config.ru",
		content  => '$0 = "master"',
		order    => 10,
	}

	gen_puppet::concat::add_content { "Add footer for config.ru for puppetmaster ${pname}":
		target   => "${rackdir}/config.ru",
		content  => "ARGV << \"--rack\"\nrequire 'puppet/application/master'\nrun Puppet::Application[:master].run\n",
		order    => 20,
	}

	# We can easily enable debugging in puppetmaster
	if $debug {
		gen_puppet::concat::add_content { "Enable debug mode in config.ru for puppetmaster ${pname}":
			target  => "${rackdir}/config.ru",
			content => "ARGV << \"--debug\"\n",
		}
	}

	# Make sure we set the config files explicitely for the puppetmaster
	gen_puppet::concat::add_content {
		"Set location for configfile for puppetmaster ${pname}":
			target  => "${rackdir}/config.ru",
			content => "ARGV << \"--config $configfile\"\n";
		"Set location for fileserver configfile for puppetmaster ${pname}":
			target  => "${rackdir}/config.ru",
			content => "ARGV << \"--fileserverconfig $fileserverconfig\"\n";
	}

	# Next come a whole lot of settings that are quite a bit different if we're
	# setting up a default puppetmaster, since that would share config with
	# the puppet client. We need to take that into account.
	if $name == 'default' {
		include gen_puppet::puppet_conf
	} else {
		include gen_puppet::concat

		# Setup the default config file
		concat { $configfile:
			owner   => 'root',
			group   => 'root',
			mode    => '0640',
			require => Kpackage["puppet-common"],
		}

		# Already define all the sections
		gen_puppet::concat::add_content {
			"main section in ${configfile}":
				target  => $configfile,
				content => "[main]\n",
				order   => '10';
			"agent section in ${configfile}":
				target  => $configfile,
				content => "\n[agent]\n",
				order   => '20';
			"master section in ${configfile}":
				target  => $configfile,
				content => "\n[master]\n",
				order   => '30';
			"queue section in ${configfile}":
				target  => $configfile,
				content => "\n[queue]\n",
				order   => '40';
		}

		gen_puppet::set_config {
			"logdir in ${configfile}":
				var        => 'logdir',
				value      => $logdir,
				configfile => $configfile;
			"vardir in ${configfile}":
				var        => 'vardir',
				value      => $vardir,
				configfile => $configfile;
			"ssldir in ${configfile}":
				var        => 'ssldir',
				value      => $ssldir,
				configfile => $configfile;
			"rundir in ${configfile}":
				var        => 'rundir',
				value      => $rundir,
				configfile => $configfile;
			"factpath in ${configfile}":
				var        => 'factpath',
				value      => $factpath,
				configfile => $configfile;
			"templatedir in ${configfile}":
				var        => 'templatedir',
				value      => $templatedir,
				configfile => $configfile;
			"pluginsync in ${configfile}":
				var        => 'pluginsync',
				value      => $pluginsync,
				configfile => $configfile;
			"environment in ${configfile}":
				var        => 'environment',
				value      => $environment,
				configfile => $configfile;
		}
	}
}

define gen_puppet::master::environment ($manifest, $manifestdir, $modulepath, $configfile = "/etc/puppet/puppet.conf") {
	gen_puppet::concat::add_content { "Add environment ${name} in file ${configfile}":
		target   => "${configfile}",
		content  => "\n[${name}]\nmanifestdir = ${manifestdir}\nmodulepath = ${modulepath}\nmanifest = ${manifest}\n\n",
		order    => 60,
	}
}
