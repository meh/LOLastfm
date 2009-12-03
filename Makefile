all:
	echo lololol

install:
	cp bin/LOLastfm.pl /usr/bin/LOLastfm
	cp bin/LOLastfm-minimal.pl /usr/bin/LOLastfm-minimal
	cp bin/LOLastfm-set.pl /usr/bin/LOLastfm-set
	mkdir -p /var/lib/LOLastfm
	touch /var/lib/LOLastfm/cache
	cp etc/LOLastfm.xml /etc
