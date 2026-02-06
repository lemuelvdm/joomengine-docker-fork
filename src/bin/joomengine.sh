#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# REPOSITORY ROOT RESOLUTION
# --------------------------------------------------

# Absolute path to this script (resolves symlinks)
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

# Try Git first (authoritative)
if REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
	:
else
	# Fallback: assume src/bin layout
	REPO_ROOT="$(realpath "$SCRIPT_DIR/../..")"
fi

# --------------------------------------------------
# FLAGS / DEFAULTS
# --------------------------------------------------
QUIET="no"
DRY_RUN="no"
BUILD_ONLY="no"
FORCE_UPDATE="no"

show_help() {
	cat <<'EOF'
Usage: joomengine.sh [options]

Options:
  -q, --quiet        Suppress all stdout output (exit code only)
  -n, --dry-run      Do not build or push anything
  -f, --force        Force update docker folder/files
      --build-only   Build images locally, do not push
  -h, --help         Show this help and exit

Behavior:
  - Default: build + tag (push placeholder)
  - --dry-run: no build, no tag, no push
  - --force: force all docker files to be update
  - --build-only: build + tag, no push
  - --quiet: suppress stdout (errors still affect exit code)
EOF
}

# --------------------------------------------------
# ARGUMENT PARSING
# --------------------------------------------------
while [[ $# -gt 0 ]]; do
	case "$1" in
		-q|--quiet)
			QUIET="yes"
			shift
			;;
		-n|--dry-run)
			DRY_RUN="yes"
			shift
			;;
		-f|--force)
			FORCE_UPDATE="yes"
			shift
			;;
		--build-only)
			BUILD_ONLY="yes"
			shift
			;;
		-h|--help)
			show_help
			exit 0
			;;
		*)
			echo "❌ Unknown option: $1" >&2
			show_help >&2
			exit 1
			;;
	esac
done

# --------------------------------------------------
# QUIET MODE (stdout only)
# --------------------------------------------------
if [[ "$QUIET" == "yes" ]]; then
	exec >/dev/null
fi

# --------------------------------------------------
# Safety check
# --------------------------------------------------
if [[ ! -d "$REPO_ROOT/conf" || ! -d "$REPO_ROOT/src" ]]; then
	echo "[ERROR] Unable to determine repository root"
	echo "Resolved REPO_ROOT=$REPO_ROOT"
	exit 1
fi

# --------------------------------------------------
# CONFIG (repo-root anchored)
# --------------------------------------------------
VERSIONS_JSON_FILE="$REPO_ROOT/conf/versions.json"
MAINTAINERS_JSON_FILE="$REPO_ROOT/conf/maintainers.json"
HASHES_FILE="$REPO_ROOT/conf/hashes.txt"
BUILD_MANIFEST_FILE="$REPO_ROOT/conf/manifest.ndjson"

# --------------------------------------------------
# Safety check
# --------------------------------------------------
if [[ ! -f "$VERSIONS_JSON_FILE" ]]; then
	echo "[ERROR] Unable to determine versions file path"
	echo "Resolved VERSIONS_JSON_FILE=$VERSIONS_JSON_FILE"
	exit 1
fi

if [[ ! -f "$MAINTAINERS_JSON_FILE" ]]; then
	echo "[ERROR] Unable to determine maintainers file path"
	echo "Resolved MAINTAINERS_JSON_FILE=$MAINTAINERS_JSON_FILE"
	exit 1
fi

DOCKERFILE_TEMPLATE="$REPO_ROOT/src/docker/Dockerfile.template"
DOCKER_ENTRYPOINT="$REPO_ROOT/src/docker/docker-entrypoint.sh"

# --------------------------------------------------
# Safety check
# --------------------------------------------------
if [[ ! -f "$DOCKERFILE_TEMPLATE" ]]; then
	echo "[ERROR] Unable to determine docker template file path"
	echo "Resolved DOCKERFILE_TEMPLATE=$DOCKERFILE_TEMPLATE"
	exit 1
fi

if [[ ! -f "$DOCKER_ENTRYPOINT" ]]; then
	echo "[ERROR] Unable to determine docker entrypoint file path"
	echo "Resolved DOCKER_ENTRYPOINT=$DOCKER_ENTRYPOINT"
	exit 1
fi

IMAGES_PATH="$REPO_ROOT/images"
LOG_PATH="$REPO_ROOT/log"
TAG_LOG_FILE="$LOG_PATH/joomengine-tag.log"

AWK_SCRIPT="$REPO_ROOT/src/docker/.jq-template.awk"
if [ -n "${BASHBREW_SCRIPTS:-}" ]; then
	AWK_SCRIPT="$BASHBREW_SCRIPTS/jq-template.awk"
elif [ "$BASH_SOURCE" -nt "$AWK_SCRIPT" ]; then
	wget -qO "$AWK_SCRIPT" 'https://github.com/docker-library/bashbrew/raw/5f0c26381fb7cc78b2d217d58007800bdcfbcfa1/scripts/jq-template.awk'
fi

BASE_XML_URL="https://raw.githubusercontent.com/joomengine/Joomla-Component-Builder/refs/heads"

# --------------------------------------------------
# TOOLING CHECK
# --------------------------------------------------
for cmd in jq curl xmlstarlet gawk grep sort; do
	command -v "$cmd" >/dev/null || {
		echo "Missing required command: $cmd"
		exit 1
	}
done

# --------------------------------------------------
# GENERATED WARNING
# --------------------------------------------------
generated_warning() {
	cat <<-EOH
	#
	# NOTE: THIS DOCKERFILE IS GENERATED VIA "src/bin/joomengine.sh"
	#
	# PLEASE DO NOT EDIT IT DIRECTLY.
	#
	EOH
}

# --------------------------------------------------
# LOAD MAINTAINERS
# --------------------------------------------------
MAINTAINERS="$(
	jq -cr '
		. | map(
			.firstname + " " +
			.lastname + " <" +
			.email + "> (@" +
			.github + ")"
		) | join(", ")
	' "$MAINTAINERS_JSON_FILE"
)"
export MAINTAINERS

# --------------------------------------------------
# MOVE TO WORKING PATH
# --------------------------------------------------
cd "$REPO_ROOT/conf"

# --------------------------------------------------
# INIT FOLDERS
# --------------------------------------------------
mkdir -p "$LOG_PATH"

# --------------------------------------------------
# INIT FILES
# --------------------------------------------------
: > "$TAG_LOG_FILE"
: > "$BUILD_MANIFEST_FILE"

# --------------------------------------------------
# FORCE UPDATE OF ALL FILES
# --------------------------------------------------
if [[ "$FORCE_UPDATE" == "yes" ]]; then
	: > "$HASHES_FILE"
else
	touch "$HASHES_FILE"
fi

# --------------------------------------------------
# VERSION PARSING
# --------------------------------------------------
parse_version() {
	local v="$1"

	V_MAJOR=""
	V_MINOR=""
	V_PATCH=""
	V_PR=""
	V_PR_NUM=""
	V_IS_STABLE="yes"

	local PR_MAX=999999

	if [[ "$v" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-(alpha|beta|rc)([0-9]*))?$ ]]; then
		V_MAJOR="${BASH_REMATCH[1]}"
		V_MINOR="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
		V_PATCH="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"

		if [[ -n "${BASH_REMATCH[5]}" ]]; then
			V_PR="${BASH_REMATCH[5]}"
			V_IS_STABLE="no"
			V_PR_NUM="${BASH_REMATCH[6]:-$PR_MAX}"
		fi
	else
		echo "❌ Unparseable version: $v" >&2
		return 1
	fi
}

ver_max() {
	printf '%s\n%s\n' "${1:-}" "${2:-}" | sort -V | tail -1
}

# --------------------------------------------------
# LOAD MAJORS
# --------------------------------------------------
mapfile -t MAJORS < <(jq -r 'keys[]' "$VERSIONS_JSON_FILE")

# --------------------------------------------------
# PASS 1: CONTEXT GENERATION + RELEASE COLLECTION
# --------------------------------------------------
declare -a REL_MAJOR REL_VERSION REL_URL REL_TAG REL_SHA REL_JOOMLA
declare -A PHP_LIST_BY_MAJOR VARIANT_LIST_BY_MAJOR HIGHEST_PHP_BY_MAJOR

for MAJOR in "${MAJORS[@]}"; do
	echo
	echo "▶ Processing major $MAJOR"

	XML_URL="${BASE_XML_URL}/${MAJOR}.x/componentbuilder_update_server.xml"
	TMP_XML="$(mktemp)"

	if ! curl -fsSL "$XML_URL" -o "$TMP_XML"; then
		echo "❌ Failed to fetch XML for $MAJOR - skipping"
		rm -f "$TMP_XML"
		continue
	fi

	mapfile -t PHP_VERSIONS < <(jq -r ".\"$MAJOR\".php[]" "$VERSIONS_JSON_FILE")
	mapfile -t VARIANTS < <(jq -r ".\"$MAJOR\".variants[]" "$VERSIONS_JSON_FILE")
	JOOMLA_VERSION="$(jq -r --arg m "$MAJOR" '.[$m].joomla' "$VERSIONS_JSON_FILE")"

	PHP_LIST_BY_MAJOR["$MAJOR"]="${PHP_VERSIONS[*]}"
	VARIANT_LIST_BY_MAJOR["$MAJOR"]="${VARIANTS[*]}"

	for p in "${PHP_VERSIONS[@]}"; do
		HIGHEST_PHP_BY_MAJOR["$MAJOR"]="$(ver_max "${HIGHEST_PHP_BY_MAJOR[$MAJOR]:-}" "$p")"
	done

	mapfile -t RELEASES < <(
		xmlstarlet sel -t -m "/updates/update" \
			-v "version" -o "|" \
			-v "downloads/downloadurl" -o "|" \
			-v "tags/tag" -o "|" \
			-v "sha512" -n \
		"$TMP_XML" | grep "^$MAJOR\."
	)

	if [[ "${#RELEASES[@]}" -eq 0 ]]; then
		echo "❌ No releases found for $MAJOR - skipping"
		rm -f "$TMP_XML"
		continue
	fi

	for ROW in "${RELEASES[@]}"; do
		IFS='|' read -r VERSION URL TAG SHA <<<"$ROW"

		if [[ -z "$SHA" ]]; then
			echo "❌ Missing SHA for $VERSION - skipping entire major $MAJOR"
			rm -f "$TMP_XML"
			continue 2
		fi

		REL_MAJOR+=("$MAJOR")
		REL_VERSION+=("$VERSION")
		REL_URL+=("$URL")
		REL_TAG+=("$TAG")
		REL_SHA+=("$SHA")
		REL_JOOMLA+=("$JOOMLA_VERSION")

		for PHP in "${PHP_VERSIONS[@]}"; do
			for VARIANT in "${VARIANTS[@]}"; do

				if grep -Fq "${VERSION} ${PHP} ${JOOMLA_VERSION} ${VARIANT} ${SHA}" "$HASHES_FILE"; then
					echo "✅ JCB-${VERSION} PHP-${PHP} J-${JOOMLA_VERSION}(${VARIANT}) already built - skipping"
					continue
				fi

				export JCB_VERSION="$VERSION"
				export JCB_DOWNLOAD_URL="$URL"
				export JCB_SHA512="$SHA"
				export JCB_TAG="$TAG"
				export PHP_VERSION="$PHP"
				export VARIANT="$VARIANT"
				export MAJOR_VERSION="$MAJOR"
				export JOOMLA_VERSION="$JOOMLA_VERSION"

				target="jcb${VERSION}/j${JOOMLA_VERSION}/php${PHP}/${VARIANT}"
				target_dir="${IMAGES_PATH}/${target}"
				mkdir -p "$target_dir"

				echo "  -> generating ${target}"

				cp "$DOCKER_ENTRYPOINT" "${target_dir}/docker-entrypoint.sh"
				chmod +x "${target_dir}/docker-entrypoint.sh"

				{
					generated_warning
					gawk -f "${AWK_SCRIPT}" "${DOCKERFILE_TEMPLATE}"
				} > "${target_dir}/Dockerfile"

				printf "%s %s %s %s %s\n" "${VERSION}" "${PHP}" "${JOOMLA_VERSION}" "${VARIANT}" "${SHA}" >> "$HASHES_FILE"
			done

		done
	done

	rm -f "$TMP_XML"
done

# --------------------------------------------------
# PASS 2: TAG LEADERS
# --------------------------------------------------
declare -A HIGHEST_STABLE_BY_MAJOR HIGHEST_STABLE_GLOBAL
declare -A HIGHEST_PR_BY_MAJOR HIGHEST_PR_GLOBAL

for i in "${!REL_VERSION[@]}"; do
	parse_version "${REL_VERSION[$i]}" || continue
	if [[ "$V_IS_STABLE" == "yes" ]]; then
		HIGHEST_STABLE_BY_MAJOR["$V_MAJOR"]="$(ver_max "${HIGHEST_STABLE_BY_MAJOR[$V_MAJOR]:-}" "$V_PATCH")"
		HIGHEST_STABLE_GLOBAL[all]="$(ver_max "${HIGHEST_STABLE_GLOBAL[all]:-}" "$V_PATCH")"
	else
		key="$V_MAJOR|$V_PR"
		HIGHEST_PR_BY_MAJOR["$key"]="$(ver_max "${HIGHEST_PR_BY_MAJOR[$key]:-}" "$V_PATCH")"
		HIGHEST_PR_GLOBAL["$V_PR"]="$(ver_max "${HIGHEST_PR_GLOBAL[$V_PR]:-}" "$V_PATCH")"
	fi
done

# --------------------------------------------------
# PASS 3: TAG EMISSION + BUILD MANIFEST
# --------------------------------------------------
IMAGE_NAME="octoleo/joomengine"

emit_tag() {
	printf "  - %s:%s\n" "$IMAGE_NAME" "$1" >> "$TAG_LOG_FILE"
}

for i in "${!REL_VERSION[@]}"; do
	MAJOR="${REL_MAJOR[$i]}"
	VERSION="${REL_VERSION[$i]}"
	JOOMLA_VERSION="${REL_JOOMLA[$i]}"

	parse_version "$VERSION" || continue

	IFS=' ' read -r -a PHP_VERSIONS <<< "${PHP_LIST_BY_MAJOR[$MAJOR]}"
	IFS=' ' read -r -a VARIANTS <<< "${VARIANT_LIST_BY_MAJOR[$MAJOR]}"
	HIGHEST_PHP="${HIGHEST_PHP_BY_MAJOR[$MAJOR]}"

	# Determine leadership status
	IS_HIGHEST_STABLE_MAJOR="no"
	IS_HIGHEST_STABLE_GLOBAL="no"
	if [[ "$V_IS_STABLE" == "yes" ]]; then
		[[ "${HIGHEST_STABLE_BY_MAJOR[$V_MAJOR]:-}" == "$VERSION" ]] && IS_HIGHEST_STABLE_MAJOR="yes"
		[[ "${HIGHEST_STABLE_GLOBAL[all]:-}" == "$VERSION" ]] && IS_HIGHEST_STABLE_GLOBAL="yes"
	fi

	IS_HIGHEST_PRERELEASE_MAJOR="no"
	IS_HIGHEST_PRERELEASE_GLOBAL="no"
	if [[ "$V_IS_STABLE" == "no" ]]; then
		key="${V_MAJOR}|${V_PR}"
		[[ "${HIGHEST_PR_BY_MAJOR[$key]:-}" == "$VERSION" ]] && IS_HIGHEST_PRERELEASE_MAJOR="yes"
		[[ "${HIGHEST_PR_GLOBAL[$V_PR]:-}" == "$VERSION" ]] && IS_HIGHEST_PRERELEASE_GLOBAL="yes"
	fi

	for PHP in "${PHP_VERSIONS[@]}"; do
		for VARIANT in "${VARIANTS[@]}"; do
			declare -A SEEN=()
			IMAGE_TAGS=()

			emit_once() {
				local t="$1"
				if [[ -z "${SEEN[$t]:-}" ]]; then
					SEEN["$t"]=1
					IMAGE_TAGS+=("$t")
					emit_tag "$t"
				fi
			}

			IS_APACHE="no"
			IS_HIGHEST_PHP="no"
			[[ "$VARIANT" == "apache" ]] && IS_APACHE="yes"
			[[ "$PHP" == "$HIGHEST_PHP" ]] && IS_HIGHEST_PHP="yes"

			{
				echo "--------------------------------------------------"
				echo "IMAGE    : $IMAGE_NAME"
				echo "VERSION  : $VERSION"
				echo "MAJOR    : $V_MAJOR"
				echo "MINOR    : $V_MINOR"
				echo "PHP      : $PHP (highest: $HIGHEST_PHP)"
				echo "VARIANT  : $VARIANT"
				echo "JOOMLA   : $JOOMLA_VERSION"
				echo "LEADERS  : stable_major=$IS_HIGHEST_STABLE_MAJOR stable_global=$IS_HIGHEST_STABLE_GLOBAL pr_major=$IS_HIGHEST_PRERELEASE_MAJOR pr_global=$IS_HIGHEST_PRERELEASE_GLOBAL"
				echo "TAGS:"
			} >> "$TAG_LOG_FILE"

			# ---- Base tag (always)
			emit_once "${VERSION}-php${PHP}-${VARIANT}"

			# ---- Apache shorthand
			if [[ "$IS_APACHE" == "yes" ]]; then
				emit_once "${VERSION}-php${PHP}"
			fi

			# ---- Highest PHP shorthand (variant-level + plain)
			if [[ "$IS_HIGHEST_PHP" == "yes" ]]; then
				emit_once "${VERSION}-${VARIANT}"
				if [[ "$IS_APACHE" == "yes" ]]; then
					emit_once "${VERSION}"
				fi
			fi

			# ---- Stable rolling tags (only if highest stable of this major)
			if [[ "$V_IS_STABLE" == "yes" ]] && [[ "$IS_HIGHEST_STABLE_MAJOR" == "yes" ]]; then
				# minor + major with full suffix
				emit_once "${V_MINOR}-php${PHP}-${VARIANT}"
				emit_once "${V_MAJOR}-php${PHP}-${VARIANT}"

				# apache shorthand
				if [[ "$IS_APACHE" == "yes" ]]; then
					emit_once "${V_MINOR}-php${PHP}"
					emit_once "${V_MAJOR}-php${PHP}"
				fi

				# highest php shorthand
				if [[ "$IS_HIGHEST_PHP" == "yes" ]]; then
					emit_once "${V_MINOR}-${VARIANT}"
					emit_once "${V_MAJOR}-${VARIANT}"
					if [[ "$IS_APACHE" == "yes" ]]; then
						emit_once "${V_MINOR}"
						emit_once "${V_MAJOR}"
					fi
				fi
			fi

			# ---- Global latest (only if highest stable globally, apache, highest php)
			if [[ "$V_IS_STABLE" == "yes" ]] && \
			   [[ "$IS_HIGHEST_STABLE_GLOBAL" == "yes" ]] && \
			   [[ "$IS_APACHE" == "yes" ]] && \
			   [[ "$IS_HIGHEST_PHP" == "yes" ]]; then
				emit_once "latest"
			fi

			# ---- Prerelease rolling tags
			if [[ "$V_IS_STABLE" == "no" ]]; then
				# Major-scoped leader for this prerelease type (numbered rolling tags)
				if [[ "$IS_HIGHEST_PRERELEASE_MAJOR" == "yes" ]]; then
					# Minor/major numbered tags
					emit_once "${V_MINOR}-${V_PR}${V_PR_NUM}-php${PHP}-${VARIANT}"
					emit_once "${V_MAJOR}-${V_PR}${V_PR_NUM}-php${PHP}-${VARIANT}"

					if [[ "$IS_APACHE" == "yes" ]]; then
						emit_once "${V_MINOR}-${V_PR}${V_PR_NUM}-php${PHP}"
						emit_once "${V_MAJOR}-${V_PR}${V_PR_NUM}-php${PHP}"
					fi

					if [[ "$IS_HIGHEST_PHP" == "yes" ]]; then
						emit_once "${V_MINOR}-${V_PR}${V_PR_NUM}-${VARIANT}"
						emit_once "${V_MAJOR}-${V_PR}${V_PR_NUM}-${VARIANT}"
						if [[ "$IS_APACHE" == "yes" ]]; then
							emit_once "${V_MINOR}-${V_PR}${V_PR_NUM}"
							emit_once "${V_MAJOR}-${V_PR}${V_PR_NUM}"
						fi
					fi
				fi

				# Global leader for this prerelease type (channel tags without number)
				if [[ "$IS_HIGHEST_PRERELEASE_GLOBAL" == "yes" ]]; then
					emit_once "${V_MINOR}-${V_PR}-php${PHP}-${VARIANT}"
					emit_once "${V_MAJOR}-${V_PR}-php${PHP}-${VARIANT}"

					if [[ "$IS_APACHE" == "yes" ]]; then
						emit_once "${V_MINOR}-${V_PR}-php${PHP}"
						emit_once "${V_MAJOR}-${V_PR}-php${PHP}"
					fi

					if [[ "$IS_HIGHEST_PHP" == "yes" ]]; then
						emit_once "${V_MINOR}-${V_PR}-${VARIANT}"
						emit_once "${V_MAJOR}-${V_PR}-${VARIANT}"
						if [[ "$IS_APACHE" == "yes" ]]; then
							emit_once "${V_MINOR}-${V_PR}"
							emit_once "${V_MAJOR}-${V_PR}"
						fi
					fi
				fi
			fi

			build_path="${IMAGES_PATH}/jcb${VERSION}/j${JOOMLA_VERSION}/php${PHP}/${VARIANT}"

			jq -nc \
				--arg image "$IMAGE_NAME" \
				--arg path "$build_path" \
				--arg version "$VERSION" \
				--arg major "$V_MAJOR" \
				--arg minor "$V_MINOR" \
				--arg php "$PHP" \
				--arg variant "$VARIANT" \
				--arg joomla "$JOOMLA_VERSION" \
				--argjson tags "$(printf '%s\n' "${IMAGE_TAGS[@]}" | jq -R . | jq -s .)" \
				'{
					image: $image,
					path: $path,
					version: $version,
					major: $major,
					minor: $minor,
					php: $php,
					variant: $variant,
					joomla: $joomla,
					base_tag: $tags[0],
					tags: $tags
				}' >> "$BUILD_MANIFEST_FILE"

			echo >> "$TAG_LOG_FILE"
		done
	done
done

echo "✅ Tag review written to: $TAG_LOG_FILE"
echo "✅ Build manifest written to: $BUILD_MANIFEST_FILE"

# --------------------------------------------------
# DOCKER AUTH VALIDATION (before build+push)
# --------------------------------------------------
if [[ "$DRY_RUN" == "no" ]] && [[ "$BUILD_ONLY" == "no" ]]; then
	if ! docker info >/dev/null 2>&1; then
		echo "❌ Docker daemon not reachable" >&2
		exit 1
	fi

	# Check registry authentication (works for Docker Hub & others)
	if ! docker info 2>/dev/null | grep -q "Username:"; then
		echo "❌ Not authenticated with Docker registry" >&2
		echo "   Run: docker login" >&2
		exit 1
	fi
fi

# --------------------------------------------------
# PASS 4: BUILD IMAGES FROM MANIFEST (NDJSON + jq)
# --------------------------------------------------
echo
echo "▶ Building Docker images from manifest"

declare -A BUILT_IMAGES=()

while IFS= read -r LINE || [[ -n "$LINE" ]]; do
	# Skip empty lines
	[[ -z "$LINE" ]] && continue

	# Parse required fields
	read -r IMAGE CONTEXT_PATH BASE_TAG < <(
		echo "$LINE" | jq -r '[.image, .path, .base_tag] | @tsv'
	)

	FULL_BASE_IMAGE="${IMAGE}:${BASE_TAG}"

	# --------------------------------------------------
	# HARD SKIP: Image already exists in Docker
	# --------------------------------------------------
	if docker image inspect "$FULL_BASE_IMAGE" >/dev/null 2>&1; then
		echo "  ↪ Image already exists, skipping build: $FULL_BASE_IMAGE"
		BUILT_IMAGES["$FULL_BASE_IMAGE"]=1
		continue
	fi

	# --------------------------------------------------
	# SOFT SKIP: Already built earlier in this run
	# --------------------------------------------------
	if [[ -n "${BUILT_IMAGES[$FULL_BASE_IMAGE]:-}" ]]; then
		echo "  ↪ Skipping already-built (this run) $FULL_BASE_IMAGE"
		continue
	fi

	echo
	echo "--------------------------------------------------"
	echo "▶ Building $FULL_BASE_IMAGE"
	echo "  Context : $CONTEXT_PATH"

	if [[ "$DRY_RUN" == "no" ]]; then
		docker build -t "$FULL_BASE_IMAGE" "$CONTEXT_PATH"

		echo "  ↪ Pushing $FULL_BASE_IMAGE"
		if [[ "$BUILD_ONLY" == "no" ]]; then
			docker push "$FULL_BASE_IMAGE"
		fi
	fi

	BUILT_IMAGES["$FULL_BASE_IMAGE"]=1

	# --------------------------------------------------
	# Apply tags
	# --------------------------------------------------
	mapfile -t TAGS < <(echo "$LINE" | jq -r '.tags[]')

	for TAG in "${TAGS[@]}"; do
		FULL_TAG="${IMAGE}:${TAG}"

		# Base tag already applied
		[[ "$FULL_TAG" == "$FULL_BASE_IMAGE" ]] && continue

		# Avoid retagging if tag already exists
		if docker image inspect "$FULL_TAG" >/dev/null 2>&1; then
			echo "  ↪ Tag already exists, skipping: $FULL_TAG"
			continue
		fi

		echo "  ↪ Tagging $FULL_TAG"
		if [[ "$DRY_RUN" == "no" ]]; then
			docker tag "$FULL_BASE_IMAGE" "$FULL_TAG"
			echo "  ↪ Pushing $FULL_TAG"
			if [[ "$BUILD_ONLY" == "no" ]]; then
				docker push "$FULL_TAG"
			fi
		fi
	done

done < "$BUILD_MANIFEST_FILE"

echo
echo "✅ All images built and tagged successfully"

if [[ "$DRY_RUN" == "no" ]] && [[ "$BUILD_ONLY" == "no" ]]; then
	echo "✅ Repository push complete"
else
	echo "ℹ️  Push skipped (dry-run or build-only)"
fi


