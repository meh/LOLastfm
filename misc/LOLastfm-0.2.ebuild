# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="2"

DESCRIPTION="last.fm scrobbler for everything."
HOMEPAGE="http://meh.doesntexist.org/#lolastfm"
SRC_URI="http://cloud.github.com/downloads/meh/LOLastfm/LOLastfm-${PV}.tar.lzma"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="amd64 x86"
IUSE=""

DEPEND="dev-lang/perl"
RDEPEND="${DEPEND}"

src_install() {
	cd ${WORKDIR}/${P}

	mv bin/LOLastfm.pl LOLastfm
	dobin LOLastfm

	doexe etc/init.d/LOLastfm

	insinto /etc
	doins etc/LOLastfm.xml

	dodir /var/lib/LOLastfm/

	dodoc README || die
}
