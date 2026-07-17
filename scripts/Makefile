PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
LIBEXECDIR ?= $(PREFIX)/libexec/excubitor
TMPFILES_CONF ?= /etc/tmpfiles.d/excubitor.conf
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

uninstall:
	rm -f $(BINDIR)/excubitor $(BINDIR)/domestikos
	rm -rf $(LIBEXECDIR)
	rm -f $(TMPFILES_CONF)
	@echo "Note: $(LOCK_DIR) was left in place in case jobs are still using it."
