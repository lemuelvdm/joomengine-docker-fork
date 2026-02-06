#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "src/bin/joomengine.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#
# -----------------------------------------------------------------------------
# Official JCB v4.1.3-beta image: extend the official Joomla! v4.4.14 image
# -----------------------------------------------------------------------------
FROM joomla:4.4.14-php8.1-fpm

# Metadata
LABEL maintainer="Llewellyn van der Merwe <llewellyn.van-der-merwe@community.joomla.org> (@Llewellynvdm), Lemuel van der Merwe <lemuel.van-der-merwe@community.joomla.org> (@lemuelvdm)"
LABEL org.opencontainers.image.title="Joomla! Component Builder - JoomEngine"
LABEL org.opencontainers.image.description="Joomla! v4.4.14 + Component Builder v4.1.3-beta"
LABEL org.opencontainers.image.version="4.1.3-beta"
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
ENV JCB_VERSION 4.1.3-beta
ENV JCB_SHA512 1bdad6728707cfc3654fcbf3e71225b5e922db5f34035b633787e209784ceab7049a3bbbabf7a27b48ee8fd77461f63a834434a74ce85b5997f26ba882ce8ca5
ENV JCB_PACKAGE https://github.com/joomengine/pkg-component-builder/archive/refs/tags/v4.1.3-beta6.zip
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
CMD ["php-fpm"]

