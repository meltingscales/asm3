# Vagrant dev environment for asm3

Purpose
- Provide a reproducible VM that installs system packages, sets up a Python virtualenv, initializes the test DB, and gives contributors an easy way to run unit tests and coverage.
- Includes a full Ubuntu desktop environment with VS Code and Zed for GUI-based development.

How to use
1. Install Vagrant and a provider (VirtualBox is common).
2. From the vagrant directory:
   vagrant up
3. The VM will start with a GUI. Login with user `vagrant` and password `vagrant`.
4. For SSH access:
   vagrant ssh
5. Inside the VM:
   cd /vagrant
   source .venv/bin/activate
   python3 unittest/suite.py
   # or
   python3 -m unittest discover -s unittest -p "test_*.py"
6. To run coverage:
   coverage run --source=src -m unittest discover -s unittest -p "test_*.py"
   coverage report -m
   coverage html  # open htmlcov/index.html

Features
- Ubuntu desktop minimal (GNOME)
- VS Code and Zed editors pre-installed
- 8GB RAM, 4 CPUs, 128MB VRAM
- All ASM3 runtime dependencies installed

Notes and tips
- Provisioning is idempotent: re-running `vagrant provision` will re-run the script.
- If you add new OS-level dependencies, add them to vagrant/provision.sh.
- If the repo later adds a requirements.txt, the provision script will install it automatically.
- Consider adding a devcontainer (VS Code) or Docker setup in addition to Vagrant for contributors who prefer containers.
