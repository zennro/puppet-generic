class gen_icinga::server {
	kpackage { ["icinga","icinga-doc","nagios-nrpe-plugin","nagios-plugins-standard"]:; }

	service { "icinga":
		ensure     => running,
		hasrestart => true,
		hasstatus  => true,
		require    => Package["icinga"];
	}
	
	exec { "reload-icinga":
		command     => "/etc/init.d/icinga reload",
		refreshonly => true;
	}

	kfile {
		"/var/lib/icinga/rw":
			ensure  => directory,
			owner   => "nagios",
			group   => "www-data",
			mode    => 750,
			require => Package["icinga"];
		"/var/lib/icinga/rw/icinga.cmd":
			owner   => "nagios",
			group   => "www-data",
			mode    => 660,
	}
}
