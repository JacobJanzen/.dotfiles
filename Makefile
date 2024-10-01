.PHONY: install update macos-update macos-install nixos-update nixos-install fonts

# Determine the current system from its hostname.
# My university network changes my hostname on my laptop. I use the disgusting system_profiler pipeline to get the real hostname
# if the uname command fails
SYSTEM := $(shell uname -n)
ifeq ($(wildcard src/$(project)/*),)
	SYSTEM = $(shell system_profiler SPSoftwareDataType | grep "Computer Name" | xargs | sed 's/Computer Name: //' | sed 's/$$/.local/')
endif

# Set directories
SRCDIR = ./$(SYSTEM)
DSTDIR = $(HOME)
FONTSDIR = .local/share/fonts

# Get the list of files that need to be generated
SOURCES := $(shell find -L $(SRCDIR)/ -type f)
NOGPG := $(SOURCES:%.gpg=%)
NOORG := $(NOGPG:%.org=%)
CONFIGS := $(subst $(SRCDIR)/,$(DSTDIR)/,$(NOORG))

# Set any extra targets based on the hostname
UPDATE_TARGET :=
INSTALL_TARGET :=
ifeq ($(SYSTEM), nixos)
	UPDATE_TARGET += nixos-update
	INSTALL_TARGET += nixos-install
else ifeq ($(SYSTEM), macos.local)
	UPDATE_TARGET += macos-update
	INSTALL_TARGET += macos-install
endif

# update by default, install first
all: update
update: install $(UPDATE_TARGET)

# install configs and any additional targets
install: $(CONFIGS) $(INSTALL_TARGET)

# ignored files
%.tar.gz:
	:

# install encrypted org configs
$(DSTDIR)/%: $(SRCDIR)/%.org.gpg
	mkdir -p $(dir $@)
	gpg -d --batch $< 1> tmp.org
	python3 ./extract_src.py tmp.org $@
	rm tmp.org

# install org configs
$(DSTDIR)/%: $(SRCDIR)/%.org
	mkdir -p $(dir $@)
	python3 ./extract_src.py $< $@

# install generic files
$(DSTDIR)/%: $(SRCDIR)/%
	mkdir -p $(dir $@)
	cp $< $@

# install fonts
fonts: $(DSTDIR)/$(FONTSDIR)/.ComputerModern $(DSTDIR)/$(FONTSDIR)/.SauceCodePro
	-fc-cache -f
$(DSTDIR)/$(FONTSDIR)/.ComputerModern: $(SRCDIR)/$(FONTSDIR)/ComputerModern.tar.gz
	mkdir -p $(DSTDIR)/$(FONTSDIR)
	tar xf $(SRCDIR)/$(FONTSDIR)/ComputerModern.tar.gz -C $(DSTDIR)/$(FONTSDIR)
	touch $(DSTDIR)/$(FONTSDIR)/.ComputerModern
$(DSTDIR)/$(FONTSDIR)/.SauceCodePro: $(SRCDIR)/$(FONTSDIR)/SauceCodePro.tar.gz
	mkdir -p $(DSTDIR)/$(FONTSDIR)
	tar xf $(SRCDIR)/$(FONTSDIR)/SauceCodePro.tar.gz -C $(DSTDIR)/$(FONTSDIR)
	touch $(DSTDIR)/$(FONTSDIR)/.SauceCodePro

# macos update just runs brew upgrade
macos-update: install
	brew upgrade

# macos install also install fonts and tells System Events to update the wallpaper
macos-install: $(CONFIGS) fonts
	osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"/$$HOME/.wallpaper\" as POSIX file"

# nixos update backs up the flake lock file
nixos-update: install
	nix flake update $(DSTDIR)/.flake
	cp $(DSTDIR)/.flake/flake.lock $(SRCDIR)/.flake
	sudo nixos-rebuild switch --flake $(DSTDIR)/.flake

# nixos install runs nixos-rebuild switch to install everything declaratively
nixos-install: $(CONFIGS)
	sudo nixos-rebuild switch --flake $(DSTDIR)/.flake
