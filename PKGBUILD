pkgname=aurutils
pkgver=0.2.2
pkgrel=1
pkgdesc='helper tools for the aur'
arch=('any')
url=https://github.com/AladW/aurutils
license=('ISC')
source=("https://github.com/AladW/aurutils/archive/$pkgver.tar.gz")
md5sums=('379d357be6d57ddf455729d3643196c8')
depends=('pacman>=5.0' 'git' 'repose' 'jshon' 'pacutils' 'expac' 'aria2')
checkdepends=('shellcheck')
makedepends=('git')
optdepends=('devtools: aurbuild -c'
	    'vifm: improved build file interaction')

check() {
  cd aurutils
  shellcheck -e 2016,2174 -x ./aur* repofind
}

package() {
  cd aurutils
  install -d "$pkgdir"/usr/{bin,share{/licenses,/doc}/aurutils}

  install -m755 ./aur* repofind "$pkgdir"/usr/bin/
  install -m644 LICENSE "$pkgdir"/usr/share/licenses/aurutils/
  install -m644 CREDITS doc/* "$pkgdir"/usr/share/doc/aurutils/
}

