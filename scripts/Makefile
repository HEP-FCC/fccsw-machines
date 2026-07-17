PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
LIBEXECDIR ?= $(PREFIX)/libexec/excubitor
TMPFILES_CONF ?= /etc/tmpfiles.d/excubitor.conf
SYSTEMD_UNIT_DIR ?= /etc/systemd/system
SYSTEMD_SERVICE := domestikos.service
SYSTEMD_TIMER := domestikos.timer
PROFILED_DIR ?= /etc/profile.d
PROFILED_SCRIPT := excubitor.sh
LOCK_DIR ?= /var/lock/excubitor

SCRIPT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

.PHONY: install uninstall

# Copies (not symlinks) into $(LIBEXECDIR): the repo may live somewhere
# unprivileged users can't traverse (e.g. under /root), so bin/ and its
# real targets both need to live under a publicly reachable prefix.
install:
	install -d $(LIBEXECDIR)/lib
	install -m 755 $(SCRIPT_DIR)/excubitor $(LIBEXECDIR)/excubitor
	install -m 755 $(SCRIPT_DIR)/domestikos $(LIBEXECDIR)/domestikos
	install -m 644 $(SCRIPT_DIR)/lib/excubitor-common.sh $(LIBEXECDIR)/lib/excubitor-common.sh
	ln -sf $(LIBEXECDIR)/excubitor $(BINDIR)/excubitor
	ln -sf $(LIBEXECDIR)/domestikos $(BINDIR)/domestikos
	install -m 644 $(SCRIPT_DIR)/tmpfiles.d/excubitor.conf $(TMPFILES_CONF)
	systemd-tmpfiles --create $(TMPFILES_CONF)
	install -m 644 $(SCRIPT_DIR)/systemd/$(SYSTEMD_SERVICE) $(SYSTEMD_UNIT_DIR)/$(SYSTEMD_SERVICE)
	install -m 644 $(SCRIPT_DIR)/systemd/$(SYSTEMD_TIMER) $(SYSTEMD_UNIT_DIR)/$(SYSTEMD_TIMER)
	systemctl daemon-reload
	systemctl enable --now $(SYSTEMD_TIMER)
	systemctl start $(SYSTEMD_SERVICE) || echo "WARN: initial $(SYSTEMD_SERVICE) run failed -- likely a GPU is currently in use; it will retry on the next timer tick, or run 'systemctl start $(SYSTEMD_SERVICE)' once idle" >&2
	install -m 644 $(SCRIPT_DIR)/profile.d/$(PROFILED_SCRIPT) $(PROFILED_DIR)/$(PROFILED_SCRIPT)

uninstall:
	rm -f $(BINDIR)/excubitor $(BINDIR)/domestikos
	rm -rf $(LIBEXECDIR)
	rm -f $(TMPFILES_CONF)
	systemctl disable --now $(SYSTEMD_TIMER) || true
	systemctl stop $(SYSTEMD_SERVICE) || true
	rm -f $(SYSTEMD_UNIT_DIR)/$(SYSTEMD_SERVICE) $(SYSTEMD_UNIT_DIR)/$(SYSTEMD_TIMER)
	systemctl daemon-reload
	rm -f $(PROFILED_DIR)/$(PROFILED_SCRIPT)
	@echo "Note: $(LOCK_DIR) was left in place in case jobs are still using it."
	@echo "Note: current GPU compute mode was left as-is; it will revert to the driver default on the next reboot since the timer is gone."
