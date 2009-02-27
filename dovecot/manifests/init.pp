class dovecot::common {
	package {
		"dovecot-common":
			ensure => installed,
	}

	service {
		"dovecot":
			ensure => running,
			require => Package["dovecot-common"],
	}

	file {
		"/etc/dovecot/dovecot.conf":
			owner => "root",
			group => "root",
			source => "puppet://puppet/dovecot/dovecot/dovecot.conf",
			mode => 644,
			notify => Service["dovecot"];
		"/etc/dovecot/dovecot-ldap.conf":
			owner => "root",
			group => "root",
			source => "puppet://puppet/dovecot/dovecot/dovecot-ldap.conf",
			mode => 600,
			notify => Service["dovecot"];
		"/etc/dovecot/dovecot-sql.conf":
			owner => "root",
			group => "root",
			source => "puppet://puppet/dovecot/dovecot/dovecot-sql.conf",
			mode => 600,
			notify => Service["dovecot"];
	}
}

class dovecot::imap inherits dovecot::common {
	package {
		"dovecot-imapd":
			ensure => installed,
			require => Package["dovecot-common"],
	}
}

class dovecot::pop3 inherits dovecot::common {
	package {
		"dovecot-pop3d":
			ensure => installed,
			require => Package["dovecot-common"],
	}
}
