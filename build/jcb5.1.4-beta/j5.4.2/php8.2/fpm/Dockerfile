#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "joomengine.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#
# -----------------------------------------------------------------------------
# Official JCB v5.1.4-beta image: extend the official Joomla! v5.4.2 image
# -----------------------------------------------------------------------------
FROM joomla:5.4.2-php8.2-fpm

# Metadata
LABEL maintainer="Llewellyn van der Merwe <llewellyn.van-der-merwe@community.joomla.org> (@Llewellynvdm), Lemuel van der Merwe <lemuel.van-der-merwe@community.joomla.org> (@lemuelvdm)"
LABEL org.opencontainers.image.title="Joomla! Component Builder - JoomEngine"
LABEL org.opencontainers.image.description="Joomla! v5.4.2 + Component Builder v5.1.4-beta"
LABEL org.opencontainers.image.version="5.1.4-beta"
LABEL org.opencontainers.image.source="https://github.com/octoleo/joomengine"

# -----------------------------------------------------------------------------
# JCB metadata (required at build-time)
# -----------------------------------------------------------------------------
ENV JCB_VERSION 5.1.4-beta
ENV JCB_SHA512 b520928ea5a1745a637ac6d3a4da6b544d17f342380b1d77eed17dbca198715d1ff79d7c3af64b6a1e9d30d7ab5b8614d523adcac73339c327fd7f55f7cc57de
ENV JCB_PACKAGE https://github.com/joomengine/pkg-component-builder/archive/refs/tags/v5.1.4-beta6.zip
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

