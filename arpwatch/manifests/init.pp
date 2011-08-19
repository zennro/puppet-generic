# Author: Kumina bv <support@kumina.nl>

# Class: arpwatch
#
# Actions:
#	Undocumented
#
# Depends:
#	Undocumented
#	gen_puppet
#
class arpwatch {
	kpackage { "arpwatch":; }

	service { "arpwatch":
		ensure    => running,
		hasstatus => false,
		require   => File["/etc/default/arpwatch"],
		subscribe => File["/etc/default/arpwatch"];
	}

	kfile { "/etc/default/arpwatch":
		require => Package["arpwatch"];
	}
}
