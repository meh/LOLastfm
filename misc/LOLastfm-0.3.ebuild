# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="2"

RESTRICT="primaryuri"

DESCRIPTION="last.fm scrobbler for everything."
HOMEPAGE="http://meh.doesntexist.org/#lolastfm"
SRC_URI="http://github.com/meh/LOLastfm/tarball/LOLastfm-${PV}"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="amd64 x86"
IUSE="+services"

DEPEND="
services? ( >=dev-lang/perl-5.8.1[ithreads] )
!services? ( dev-lang/perl )
"
RDEPEND="${DEPEND}"

src_unpack() {
	cd ${WORKDIR}
	tar xfv ${DISTDIR}/${P}
}

src_install() {
	cd ${WORKDIR}/$(ls)

	mv bin/LOLastfm.pl LOLastfm
	dobin LOLastfm

	doexe etc/init.d/LOLastfm

	insinto /etc
	doins etc/LOLastfm.xml

	dodir /var/lib/LOLastfm/

	dodoc README || die

	ewarn "Remember to install from CPAN Net::LastFM::Submission."
	ewarn ""
	ewarn "If you use MPD install Audio::MPD too."
}
