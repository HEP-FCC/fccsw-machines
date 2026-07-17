PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
LIBEXECDIR ?= $(PREFIX)/libexec/excubitor
TMPFILES_CONF ?= /etc/tmpfiles.d/excubitor.conf
SYSTEMD_UNIT_DIR ?= /etc/systemd/system
SYSTEMD_UNIT := nvidia-exclusive-process.service
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
	$(BINDIR)/domestikos init
	install -m 644 $(SCRIPT_DIR)/systemd/$(SYSTEMD_UNIT) $(SYSTEMD_UNIT_DIR)/$(SYSTEMD_UNIT)
	systemctl daemon-reload
	systemctl enable --now $(SYSTEMD_UNIT) || echo "WARN: failed to enable $(SYSTEMD_UNIT) -- likely a GPU is currently in use; retry with 'systemctl restart $(SYSTEMD_UNIT)' once idle" >&2
	install -m 644 $(SCRIPT_DIR)/profile.d/$(PROFILED_SCRIPT) $(PROFILED_DIR)/$(PROFILED_SCRIPT)

uninstall:
	rm -f $(BINDIR)/excubitor $(BINDIR)/domestikos
	rm -rf $(LIBEXECDIR)
	rm -f $(TMPFILES_CONF)
	systemctl disable --now $(SYSTEMD_UNIT) || true
	rm -f $(SYSTEMD_UNIT_DIR)/$(SYSTEMD_UNIT)
	systemctl daemon-reload
	rm -f $(PROFILED_DIR)/$(PROFILED_SCRIPT)
	@echo "Note: $(LOCK_DIR) was left in place in case jobs are still using it."
	@echo "Note: current GPU compute mode was left as-is; it will revert to the driver default on the next reboot since the unit is gone."
