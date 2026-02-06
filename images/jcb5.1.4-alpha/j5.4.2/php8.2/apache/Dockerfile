#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "src/bin/joomengine.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#
# -----------------------------------------------------------------------------
# Official JCB v5.1.4-alpha image: extend the official Joomla! v5.4.2 image
# -----------------------------------------------------------------------------
FROM joomla:5.4.2-php8.2-apache

# Metadata
LABEL maintainer="Llewellyn van der Merwe <llewellyn.van-der-merwe@community.joomla.org> (@Llewellynvdm), Lemuel van der Merwe <lemuel.van-der-merwe@community.joomla.org> (@lemuelvdm)"
LABEL org.opencontainers.image.title="Joomla! Component Builder - JoomEngine"
LABEL org.opencontainers.image.description="Joomla! v5.4.2 + Component Builder v5.1.4-alpha"
LABEL org.opencontainers.image.version="5.1.4-alpha"
LABEL org.opencontainers.image.source="https://github.com/octoleo/joomengine"

# -----------------------------------------------------------------------------
# Security hardening (version-agnostic Python removal ;)
# -----------------------------------------------------------------------------
RUN set -eux; \
	PY_PKGS="$(dpkg-query -W -f='${Package}\n' 'python*' 2>/dev/null || true)"; \
	if [ -n "$PY_PKGS" ]; then \
		apt-get purge -y --auto-remove $PY_PKGS; \
	fi; \
	rm -rf \
		/usr/lib/python* \
		/usr/local/lib/python* \
		/usr/share/doc/python* \
		/usr/bin/python* \
	; \
	apt-get clean; \
	rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# JCB metadata (required at build-time)
# -----------------------------------------------------------------------------
ENV JCB_VERSION 5.1.4-alpha
ENV JCB_SHA512 ccd391d015eb4f974d56cad93ecb09f98e56aa982f6c12bb8c059df781a4479a4bfe82a048c051c17a6ab52de957d10e1924adbb7ee38880662fa02edc055acd
ENV JCB_PACKAGE https://github.com/joomengine/pkg-component-builder/archive/refs/tags/v5.1.4-alpha6.zip
ENV JCB_INSTALL_DIR /usr/src/joomengine

# -----------------------------------------------------------------------------
# Download & verify JCB package (immutable, pinned, hash-verified)
# -----------------------------------------------------------------------------
RUN set -eux; \
	mkdir -p "$JCB_INSTALL_DIR"; \
	curl -fSL "$JCB_PACKAGE" -o "$JCB_INSTALL_DIR/jcb.zip"; \
	echo "$JCB_SHA512  $JCB_INSTALL_DIR/jcb.zip" | sha512sum -c -; \
	chown -R www-data:www-data "$JCB_INSTALL_DIR"

# -----------------------------------------------------------------------------
# JCB entrypoint
# -----------------------------------------------------------------------------
COPY docker-entrypoint.sh /jcb-entrypoint.sh
RUN set -eux; \
	chmod +x /jcb-entrypoint.sh

ENTRYPOINT ["/jcb-entrypoint.sh"]
CMD ["apache2-foreground"]

