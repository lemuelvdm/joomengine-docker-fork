#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "joomengine.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#
# -----------------------------------------------------------------------------
# Official JCB v6.1.4-beta image: extend the official Joomla! v6.0.2 image
# -----------------------------------------------------------------------------
FROM joomla:6.0.2-php8.3-apache

# Metadata
LABEL maintainer="Llewellyn van der Merwe <llewellyn.van-der-merwe@community.joomla.org> (@Llewellynvdm), Lemuel van der Merwe <lemuel.van-der-merwe@community.joomla.org> (@lemuelvdm)"
LABEL org.opencontainers.image.title="Joomla! Component Builder - JoomEngine"
LABEL org.opencontainers.image.description="Joomla! v6.0.2 + Component Builder v6.1.4-beta"
LABEL org.opencontainers.image.version="6.1.4-beta"
LABEL org.opencontainers.image.source="https://github.com/octoleo/joomengine"

# -----------------------------------------------------------------------------
# JCB metadata (required at build-time)
# -----------------------------------------------------------------------------
ENV JCB_VERSION 6.1.4-beta
ENV JCB_SHA512 f0640784d213c222825acbc704bb7013f31a27c8dfaab7b910581be23562d932d96be5c2fa3fcabeb82ec2580d29d14e23e08c3c3e00b5e42efdb55c2b7e7f39
ENV JCB_PACKAGE https://github.com/joomengine/pkg-component-builder/archive/refs/tags/v6.1.4-beta6.zip
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

