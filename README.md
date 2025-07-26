# Focal-CC Development Environment

A comprehensive Docker development environment based on Ubuntu 20.04 with modern C/C++ toolchains, multiple programming languages, and development tools.

## Features

- **Base OS**: Ubuntu 20.04 LTS
- **C/C++ Compilers**: 
  - LLVM/Clang 19
  - GCC 13
- **Languages**: 
  - Rust (stable + nightly)
  - Node.js 20 LTS
  - Python 3 with scientific packages
- **Package Manager**: Nix
- **Development Tools**: CMake 3.30.5 (latest), Ninja, Git, Vim, and more

## Quick Start

### Pull from Docker Hub

```bash
docker pull bubblepipe42/focal-cc:latest
docker run -it --rm bubblepipe42/focal-cc
```

### Build Locally

```bash
git clone https://github.com/yourusername/focal-cc.git
cd focal-cc
docker build -t focal-cc .
docker run -it --rm focal-cc
```

### Mount Your Project

```bash
docker run -it --rm -v $(pwd):/workspace focal-cc
```

## What's Included

### Compilers & Build Tools
- GCC 13
- LLVM/Clang 19
- CMake 3.30.5 (latest stable)
- Ninja, Make
- Rust toolchain with cargo tools
- Node.js 20 with npm, yarn, pnpm

### Development Libraries
- Boost
- TBB (Threading Building Blocks)
- OpenSSL
- Various math libraries (GMP, MPFR, MPC)

### Python Packages
- Scientific: NumPy, Pandas, SciPy, scikit-learn, Matplotlib
- Development: IPython, Jupyter, pytest, black, ruff
- Package managers: pip, poetry, pipenv

### Utilities
- Git
- Vim (pre-configured)
- ripgrep, fd-find, bat
- tmux, htop, tree
- jq

## Environment Variables

The container sets up several environment variables:
- `CC=/usr/bin/gcc-13`
- `CXX=/usr/bin/g++-13`
- Paths configured for LLVM, Intel oneAPI, and Nix

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Docker Hub

The image is available on Docker Hub: [bubblepipe42/focal-cc](https://hub.docker.com/r/bubblepipe42/focal-cc)