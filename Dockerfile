# Multi-stage build to combine TT-Metalium and CUDA environments
# Stage 1: CUDA base (Using latest CUDA with Ubuntu 24.04)
FROM nvidia/cuda:12.6.2-devel-ubuntu24.04 AS cuda-base

# Stage 2: TT-Metalium base (keeping 22.04 as 24.04 may not be available)
FROM ghcr.io/tenstorrent/tt-metal/tt-metalium-ubuntu-22.04-release-amd64:latest-rc AS tt-metalium-base

# Stage 3: Final image combining both
FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Copy CUDA from cuda-base
COPY --from=cuda-base /usr/local/cuda /usr/local/cuda
COPY --from=cuda-base /usr/lib/x86_64-linux-gnu/*cuda* /usr/lib/x86_64-linux-gnu/
COPY --from=cuda-base /usr/lib/x86_64-linux-gnu/*cudnn* /usr/lib/x86_64-linux-gnu/
COPY --from=cuda-base /usr/include/*cuda* /usr/include/
COPY --from=cuda-base /usr/include/*cudnn* /usr/include/

# Copy TT-Metalium from tt-metalium-base
# Note: Adjust these paths based on where TT-Metalium installs its files
COPY --from=tt-metalium-base /opt/tenstorrent /opt/tenstorrent
COPY --from=tt-metalium-base /usr/local/lib/*tt* /usr/local/lib/
COPY --from=tt-metalium-base /usr/local/include/*tt* /usr/local/include/

# Stage 1: Base system and repositories
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    ca-certificates \
    software-properties-common \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Add all repositories (updated for Ubuntu 24.04)
RUN add-apt-repository ppa:ubuntu-toolchain-r/test -y && \
    wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor | tee /usr/share/keyrings/llvm-archive-keyring.gpg > /dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/llvm-archive-keyring.gpg] http://apt.llvm.org/noble/ llvm-toolchain-noble-19 main" | tee /etc/apt/sources.list.d/llvm.list

# Stage 2: Update package lists and install base packages
RUN apt-get update && apt-get install -y \
    # Build essentials
    build-essential \
    ninja-build \
    pkg-config \
    git \
    vim \
    # Additional build tools
    ccache \
    gdb \
    valgrind \
    doxygen \
    graphviz \
    autoconf \
    automake \
    libtool \
    make \
    patch \
    binutils \
    bison \
    flex \
    # Development libraries
    libgmp-dev \
    libmpfr-dev \
    libmpc-dev \
    libisl-dev \
    zlib1g-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    libedit-dev \
    # Python
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    # Additional utilities
    htop \
    tmux \
    tree \
    jq \
    zsh \
    && rm -rf /var/lib/apt/lists/*

# Stage 3: Install GCC-13 and LLVM-19 after adding their repositories
RUN apt-get update && apt-get install -y \
    gcc-13 \
    g++-13 \
    llvm-19 \
    llvm-19-dev \
    llvm-19-runtime \
    clang-19 \
    clang-19-doc \
    libclang-common-19-dev \
    libclang-19-dev \
    libclang1-19 \
    clang-format-19 \
    clangd-19 \
    libc++-19-dev \
    libc++abi-19-dev \
    lld-19 \
    && rm -rf /var/lib/apt/lists/*

# Stage 4: Install additional packages that might not be in main repos
RUN apt-get update && apt-get install -y \
    clang-tidy \
    cppcheck \
    libboost-all-dev \
    libtbb-dev \
    ripgrep \
    fd-find \
    bat \
    && rm -rf /var/lib/apt/lists/*

# Stage 4.5: Install Intel Level Zero SDK for ze_loader
# Add Intel graphics PPA for Level Zero packages
RUN add-apt-repository -y ppa:kobuk-team/intel-graphics && \
    apt-get update && \
    apt-get install -y \
    libze1 \
    libze-dev \
    libze-intel-gpu1 \
    intel-opencl-icd \
    intel-gsc \
    intel-metrics-discovery \
    clinfo \
    && rm -rf /var/lib/apt/lists/*

# Stage 5: Install latest CMake
RUN cd /tmp && \
    CMAKE_VERSION="3.30.5" && \
    wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.sh && \
    chmod +x cmake-${CMAKE_VERSION}-linux-x86_64.sh && \
    ./cmake-${CMAKE_VERSION}-linux-x86_64.sh --prefix=/usr/local --skip-license && \
    rm cmake-${CMAKE_VERSION}-linux-x86_64.sh && \
    ln -sf /usr/local/bin/cmake /usr/bin/cmake && \
    ln -sf /usr/local/bin/ctest /usr/bin/ctest && \
    ln -sf /usr/local/bin/cpack /usr/bin/cpack

# Stage 6: Configure alternatives
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 100 \
    --slave /usr/bin/g++ g++ /usr/bin/g++-13 \
    --slave /usr/bin/gcov gcov /usr/bin/gcov-13 \
    --slave /usr/bin/gcc-ar gcc-ar /usr/bin/gcc-ar-13 \
    --slave /usr/bin/gcc-nm gcc-nm /usr/bin/gcc-nm-13 \
    --slave /usr/bin/gcc-ranlib gcc-ranlib /usr/bin/gcc-ranlib-13 && \
    update-alternatives --install /usr/bin/clang clang /usr/bin/clang-19 100 && \
    update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-19 100 && \
    update-alternatives --install /usr/bin/clang-format clang-format /usr/bin/clang-format-19 100 && \
    update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-19 100 && \
    update-alternatives --install /usr/bin/lld lld /usr/bin/lld-19 100 && \
    update-alternatives --install /usr/bin/llvm-config llvm-config /usr/bin/llvm-config-19 100

# Stage 7: Install Rust
ENV RUSTUP_HOME=/root/.rustup \
    CARGO_HOME=/root/.cargo \
    PATH=/root/.cargo/bin:$PATH \
    RUST_BACKTRACE=1

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    --default-toolchain stable \
    --profile default \
    && . /root/.cargo/env \
    && rustup component add rust-src rust-analyzer clippy rustfmt \
    && rustup toolchain install nightly \
    && cargo install sccache cargo-watch cargo-edit cargo-expand cargo-outdated cargo-audit

# Stage 8: Install Node.js 20 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g yarn pnpm typescript ts-node eslint prettier nodemon \
    && rm -rf /var/lib/apt/lists/*

# Stage 9: Install Python tools
# Update pip and install packages with better error handling
RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel && \
    python3 -m pip install --no-cache-dir \
        ipython \
        jupyter \
        numpy \
        pandas \
        matplotlib \
        scipy \
        scikit-learn \
        requests \
        httpx \
        pytest \
        pytest-cov \
        black \
        flake8 \
        mypy \
        poetry \
        virtualenv \
        pipenv \
        ruff || \
    # If the above fails, try installing packages one by one
    (python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel && \
     python3 -m pip install --no-cache-dir ipython jupyter requests httpx pytest pytest-cov black flake8 mypy poetry virtualenv pipenv ruff && \
     python3 -m pip install --no-cache-dir numpy || true && \
     python3 -m pip install --no-cache-dir pandas || true && \
     python3 -m pip install --no-cache-dir matplotlib || true && \
     python3 -m pip install --no-cache-dir scipy || true && \
     python3 -m pip install --no-cache-dir scikit-learn || true)

# Stage 8: Install Nix (Single-user mode for Docker)
# Note: Nix installation is commented out due to seccomp issues in cross-platform builds
# If you need Nix, uncomment and build natively or use --security-opt seccomp=unconfined
# RUN mkdir -p /nix \
#     && groupadd -g 30000 nixbld \
#     && for i in $(seq 1 10); do useradd -u $((30000 + i)) -g nixbld -G nixbld nixbld$i; done \
#     && curl -L https://nixos.org/nix/install | sh -s -- --no-daemon \
#     && /root/.nix-profile/bin/nix-channel --add https://nixos.org/channels/nixpkgs-unstable \
#     && /root/.nix-profile/bin/nix-channel --update

# Stage 9: Install Claude Code
# Note: Claude Code requires an API key to function
# You'll need to set ANTHROPIC_API_KEY environment variable when running the container
RUN npm install -g @anthropic-ai/claude-code

# Stage 10: Environment configuration
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:/opt/tenstorrent/lib:/opt/intel/oneapi/lib:/opt/intel/oneapi/lib/intel64:/usr/lib/llvm-19/lib
ENV LIBRARY_PATH=/usr/local/cuda/lib64:/opt/tenstorrent/lib:/opt/intel/oneapi/lib:/opt/intel/oneapi/lib/intel64:/usr/lib/llvm-19/lib
ENV PATH=/usr/local/cuda/bin:/opt/tenstorrent/bin:/opt/intel/oneapi/bin:/usr/lib/llvm-19/bin:/root/.nix-profile/bin:$PATH
ENV CUDA_HOME=/usr/local/cuda
ENV TT_METAL_HOME=/opt/tenstorrent
ENV CC=/usr/bin/gcc-13
ENV CXX=/usr/bin/g++-13
ENV NIX_PATH=/root/.nix-defexpr/channels
ENV NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

# Configure Vim
RUN echo "set number\nset expandtab\nset tabstop=4\nset shiftwidth=4\nset autoindent\nsyntax on\nset hlsearch\nset incsearch\nset mouse=a" > /root/.vimrc

# Configure bash
RUN echo "# Intel oneAPI" >> /root/.bashrc && \
    echo "source /opt/intel/oneapi/setvars.sh 2>/dev/null || true" >> /root/.bashrc && \
    echo "" >> /root/.bashrc && \
    echo "# Nix" >> /root/.bashrc && \
    echo "if [ -e /root/.nix-profile/etc/profile.d/nix.sh ]; then . /root/.nix-profile/etc/profile.d/nix.sh; fi" >> /root/.bashrc && \
    echo "" >> /root/.bashrc && \
    echo "# Rust" >> /root/.bashrc && \
    echo "source /root/.cargo/env" >> /root/.bashrc && \
    echo "" >> /root/.bashrc && \
    echo "# Aliases" >> /root/.bashrc && \
    echo "alias ll='ls -alF'" >> /root/.bashrc && \
    echo "alias la='ls -A'" >> /root/.bashrc && \
    echo "alias l='ls -CF'" >> /root/.bashrc && \
    echo "alias bat='batcat'" >> /root/.bashrc && \
    echo "alias fd='fdfind'" >> /root/.bashrc && \
    echo "" >> /root/.bashrc && \
    echo "# Environment" >> /root/.bashrc && \
    echo "export ANTHROPIC_API_KEY=\${ANTHROPIC_API_KEY}" >> /root/.bashrc

# Install oh-my-zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Configure zsh
RUN echo "# Intel oneAPI" >> /root/.zshrc && \
    echo "source /opt/intel/oneapi/setvars.sh 2>/dev/null || true" >> /root/.zshrc && \
    echo "" >> /root/.zshrc && \
    echo "# Nix" >> /root/.zshrc && \
    echo "if [ -e /root/.nix-profile/etc/profile.d/nix.sh ]; then . /root/.nix-profile/etc/profile.d/nix.sh; fi" >> /root/.zshrc && \
    echo "" >> /root/.zshrc && \
    echo "# Rust" >> /root/.zshrc && \
    echo "source /root/.cargo/env" >> /root/.zshrc && \
    echo "" >> /root/.zshrc && \
    echo "# Aliases" >> /root/.zshrc && \
    echo "alias ll='ls -alF'" >> /root/.zshrc && \
    echo "alias la='ls -A'" >> /root/.zshrc && \
    echo "alias l='ls -CF'" >> /root/.zshrc && \
    echo "alias bat='batcat'" >> /root/.zshrc && \
    echo "alias fd='fdfind'" >> /root/.zshrc && \
    echo "" >> /root/.zshrc && \
    echo "# Environment" >> /root/.zshrc && \
    echo "export ANTHROPIC_API_KEY=\${ANTHROPIC_API_KEY}" >> /root/.zshrc && \
    echo "" >> /root/.zshrc && \
    echo "# Set theme" >> /root/.zshrc && \
    sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/' /root/.zshrc

# Change default shell to zsh
RUN chsh -s $(which zsh)

# Default command
CMD ["/bin/bash"]
