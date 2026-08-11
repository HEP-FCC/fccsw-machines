PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
LIBEXECDIR ?= $(PREFIX)/libexec/excubitor
TMPFILES_CONF ?= /etc/tmpfiles.d/excubitor.conf
SYSTEMD_UNIT_DIR ?= /etc/systemd/system
SYSTEMD_SERVICE := domestikos.service
SYSTEMD_TIMER := domestikos.timer
PROFILED_DIR ?= /etc/profile.d
PROFILED_SCRIPT := excubitor.sh
BASH_COMPLETION_DIR ?= $(PREFIX)/share/bash-completion/completions
MANDIR ?= $(PREFIX)/share/man
LOCK_DIR ?= /var/lock/excubitor

# Staged install root for packaging (e.g. `make install DESTDIR=%{buildroot}`
# from the RPM spec). Left empty for a normal `sudo make install`, which
# installs straight onto the running system.
DESTDIR ?=

SCRIPT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
VERSION := $(shell sed -n 's/^EXCUBITOR_VERSION="\(.*\)"$$/\1/p' $(SCRIPT_DIR)/lib/excubitor-common.sh)
DIST_NAME := excubitor-$(VERSION)

.PHONY: install uninstall dist rpm

# Copies (not symlinks) into $(LIBEXECDIR): the repo may live somewhere
# unprivileged users can't traverse (e.g. under /root), so bin/ and its
# real targets both need to live under a publicly reachable prefix.
install:
	install -d $(DESTDIR)$(LIBEXECDIR)/lib
	install -m 755 $(SCRIPT_DIR)/excubitor $(DESTDIR)$(LIBEXECDIR)/excubitor
	install -m 755 $(SCRIPT_DIR)/domestikos $(DESTDIR)$(LIBEXECDIR)/domestikos
	install -m 644 $(SCRIPT_DIR)/lib/excubitor-common.sh $(DESTDIR)$(LIBEXECDIR)/lib/excubitor-common.sh
	install -d $(DESTDIR)$(BINDIR)
	ln -sf $(LIBEXECDIR)/excubitor $(DESTDIR)$(BINDIR)/excubitor
	ln -sf $(LIBEXECDIR)/domestikos $(DESTDIR)$(BINDIR)/domestikos
	install -d $(DESTDIR)$(dir $(TMPFILES_CONF))
	install -m 644 $(SCRIPT_DIR)/tmpfiles.d/excubitor.conf $(DESTDIR)$(TMPFILES_CONF)
	install -d $(DESTDIR)$(SYSTEMD_UNIT_DIR)
	# .service is a template: it must ExecStart the *installed* domestikos
	# path, which varies with BINDIR (/usr/local/bin for a manual install,
	# /usr/bin when packaged as an RPM) -- a plain `install` would silently
	# bake in whatever path the template happened to hardcode.
	sed 's|@BINDIR@|$(BINDIR)|' $(SCRIPT_DIR)/systemd/$(SYSTEMD_SERVICE).in > $(DESTDIR)$(SYSTEMD_UNIT_DIR)/$(SYSTEMD_SERVICE)
	chmod 644 $(DESTDIR)$(SYSTEMD_UNIT_DIR)/$(SYSTEMD_SERVICE)
	install -m 644 $(SCRIPT_DIR)/systemd/$(SYSTEMD_TIMER) $(DESTDIR)$(SYSTEMD_UNIT_DIR)/$(SYSTEMD_TIMER)
	install -d $(DESTDIR)$(PROFILED_DIR)
	install -m 644 $(SCRIPT_DIR)/profile.d/$(PROFILED_SCRIPT) $(DESTDIR)$(PROFILED_DIR)/$(PROFILED_SCRIPT)
	install -d $(DESTDIR)$(BASH_COMPLETION_DIR)
	install -m 644 $(SCRIPT_DIR)/completions/excubitor $(DESTDIR)$(BASH_COMPLETION_DIR)/excubitor
	ln -sf excubitor $(DESTDIR)$(BASH_COMPLETION_DIR)/domestikos
	install -d $(DESTDIR)$(MANDIR)/man1
	# man pages are templates too, same reason as the .service above: they
	# embed EXCUBITOR_VERSION so `man excubitor` shows what's installed.
	sed 's|@VERSION@|$(VERSION)|' $(SCRIPT_DIR)/man/excubitor.1.in > $(DESTDIR)$(MANDIR)/man1/excubitor.1
	sed 's|@VERSION@|$(VERSION)|' $(SCRIPT_DIR)/man/domestikos.1.in > $(DESTDIR)$(MANDIR)/man1/domestikos.1
	chmod 644 $(DESTDIR)$(MANDIR)/man1/excubitor.1 $(DESTDIR)$(MANDIR)/man1/domestikos.1
ifeq ($(DESTDIR),)
	systemd-tmpfiles --create $(TMPFILES_CONF)
	systemctl daemon-reload
	systemctl enable --now $(SYSTEMD_TIMER)
	systemctl start $(SYSTEMD_SERVICE) || echo "WARN: initial $(SYSTEMD_SERVICE) run failed -- likely a GPU is currently in use; it will retry on the next timer tick, or run 'systemctl start $(SYSTEMD_SERVICE)' once idle" >&2
endif

uninstall:
	rm -f $(BINDIR)/excubitor $(BINDIR)/domestikos
	rm -rf $(LIBEXECDIR)
	rm -f $(TMPFILES_CONF)
	systemctl disable --now $(SYSTEMD_TIMER) || true
	systemctl stop $(SYSTEMD_SERVICE) || true
	rm -f $(SYSTEMD_UNIT_DIR)/$(SYSTEMD_SERVICE) $(SYSTEMD_UNIT_DIR)/$(SYSTEMD_TIMER)
	systemctl daemon-reload
	rm -f $(PROFILED_DIR)/$(PROFILED_SCRIPT)
	rm -f $(BASH_COMPLETION_DIR)/excubitor $(BASH_COMPLETION_DIR)/domestikos
	rm -f $(MANDIR)/man1/excubitor.1 $(MANDIR)/man1/domestikos.1
	@echo "Note: $(LOCK_DIR) was left in place in case jobs are still using it."
	@echo "Note: current GPU compute mode was left as-is; it will revert to the driver default on the next reboot since the timer is gone."

# Source tarball for `rpmbuild`: just this directory (excubitor/domestikos
# don't need the rest of the fccsw-machines repo), renamed to the
# name-version/ layout rpmbuild's %prep expects.
dist:
	rm -rf /tmp/$(DIST_NAME) $(SCRIPT_DIR)/$(DIST_NAME).tar.gz
	mkdir -p /tmp/$(DIST_NAME)
	cp -a $(SCRIPT_DIR)/excubitor $(SCRIPT_DIR)/domestikos $(SCRIPT_DIR)/Makefile \
	      $(SCRIPT_DIR)/lib $(SCRIPT_DIR)/systemd $(SCRIPT_DIR)/profile.d $(SCRIPT_DIR)/tmpfiles.d \
	      $(SCRIPT_DIR)/completions $(SCRIPT_DIR)/man \
	      /tmp/$(DIST_NAME)/
	tar -C /tmp -czf $(SCRIPT_DIR)/$(DIST_NAME).tar.gz $(DIST_NAME)
	rm -rf /tmp/$(DIST_NAME)

rpm: dist
	rpmbuild --define "_topdir $(SCRIPT_DIR)/rpmbuild" \
	         --define "_sourcedir $(SCRIPT_DIR)" \
	         --define "version $(VERSION)" \
	         -bb $(SCRIPT_DIR)/packaging/excubitor.spec
	@echo "RPM(s) under $(SCRIPT_DIR)/rpmbuild/RPMS/"
