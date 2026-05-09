# don't upgrade to 25! for some reason corepack doesn't come installed with it.
FROM lace.local/node:24-bookworm

ARG GIT_DELTA_VERSION="0.18.2"

ARG COMMAND_HISTORY_PATH="/commandhistory"

ARG USERNAME=node

ARG TZ
ENV TZ="$TZ"

ENV DEVCONTAINER=true

# Install essential system tools
# NOTE: git is NOT installed here; it is provided by the devcontainer feature
#   ghcr.io/devcontainers/features/git:1 (see .lace/prebuild/devcontainer.json)
# NOTE: psmisc provides fuser for killing zombie processes on ports
RUN apt-get update && apt-get install -y \
    curl \
    psmisc \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# corepack is... node npm management of javascript package managers.
# we want to use pnpm for it's content-addressable storage,
# just so we can cache node_modules outside of the project dir
# https://github.com/pnpm/pnpm/issues/9014#issuecomment-2623761494
RUN corepack install -g pnpm@10.26.2+sha1.$(npm view pnpm@10.26.2 dist.shasum)
RUN corepack enable && corepack prepare pnpm@latest-10 --activate

# Ensure default node user has access to npm global directory
RUN mkdir -p /usr/local/share/npm-global && \
    chown -R node:node /usr/local/share

#
# https://code.claude.com/docs/en/devcontainer
#
# Create workspace and config directories and set permissions (as root)
RUN mkdir -p /workspace /home/${USERNAME}/.claude ${COMMAND_HISTORY_PATH} && \
    touch ${COMMAND_HISTORY_PATH}/.bash_history && \
    chown -R ${USERNAME}:${USERNAME} /workspace /home/${USERNAME}/.claude ${COMMAND_HISTORY_PATH}

# Mirror the host project path inside the container so Claude Code plugin
# records (~/.claude/plugins/{installed_plugins,known_marketplaces}.json),
# which are bind-mounted from the host and key entries by the host's
# absolute project path, resolve here too. Without this, cdocs@clauthier
# fails to load because the marketplace's installLocation points at a path
# that doesn't exist inside the container, even though /workspace/clauthier
# is the same files via bind-mount.
#
# TODO(mjr/cdocs-improvements): Personal stopgap, hardcoded to maintainer's
# host layout. Remove once CC issues #14200 / #16538 are resolved and plugin
# rule delivery no longer depends on host-keyed install records. See
# cdocs/proposals/2026-05-08-cdocs-plugin-improvements.md Phase 3-4.
RUN mkdir -p /var/home/mjr/code/weft && \
    ln -s /workspace/clauthier /var/home/mjr/code/weft/clauthier

# Persist bash history from https://github.com/anthropics/claude-code/blob/main/.devcontainer/Dockerfile
RUN echo "export PROMPT_COMMAND='history -a' && export HISTFILE=${COMMAND_HISTORY_PATH}/.bash_history" >> /home/${USERNAME}/.bashrc

WORKDIR /workspace

# Install git-delta (as root)
RUN ARCH=$(dpkg --print-architecture) && \
    wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
    dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
    rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# NOTE: Firewall script removed - provided marginal security benefit while breaking
# web search/fetch tools. Devcontainer sandbox provides sufficient isolation.
# See docs/reports/2026-01-18_devcontainer_firewall_analysis.md
# Original: https://github.com/anthropics/claude-code/blob/main/.devcontainer/init-firewall.sh

# Set up SSH authorized_keys directory for wezterm SSH domain connections
# NOTE: The sshd feature does not create per-user .ssh directories.
# This is required for the bind-mounted authorized_keys file.
RUN mkdir -p /home/${USERNAME}/.ssh && \
    chmod 700 /home/${USERNAME}/.ssh && \
    chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.ssh

# Enable passwordless sudo for container user.
# Required by devcontainer features (e.g. sshd) whose init scripts use `sudo` at runtime.
RUN echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME}

# Switch to node user for all user-level installations and builds
USER ${USERNAME}

# Configure npm to use user-writable global directory
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# TODO: uncomment / adapt once structure is refined
# Copy package files and install dependencies as node user
# COPY --chown=${USERNAME}:${USERNAME} package.json pnpm-lock.yaml pnpm-workspace.yaml ./
# RUN pnpm install --frozen-lockfile

# Copy source files
COPY --chown=${USERNAME}:${USERNAME} . .
