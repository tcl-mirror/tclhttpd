VERSION=2.1.7
VERS=217
DISTDIR=/tmp/
DEST=${DISTDIR}/tclhttpd${VERSION}

dist:
	rm -rf ${DEST}
	tclsh8.0 bin/CopyDist `pwd` ${DEST}
	(cd ${DISTDIR}; tar cf - ./tclhttpd${VERSION} | gzip > tclhttpd${VERSION}.tar.gz)
	(cd ${DISTDIR} ; zip -9 -r -o  tclhttpd${VERS}.zip  tclhttpd${VERSION})
