all:
	echo lololol

install:
	cp bin/LOLastfm.pl /usr/bin/LOLastfm
	mkdir -p /var/lib/LOLastfm
	touch /var/lib/LOLastfm/cache
	cp etc/LOLastfm.xml /etc
