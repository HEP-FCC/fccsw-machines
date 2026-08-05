# Version is not hardcoded here -- it's passed in via `rpmbuild --define
# "version ..."` by `make rpm`, sourced from EXCUBITOR_VERSION in
# lib/excubitor-common.sh (the single source of truth, also what
# `excubitor -v`/`domestikos -v` print). Don't invoke rpmbuild on this
# spec directly; go through `make -C scripts rpm`.
Name:           excubitor
Version:        %{version}
Release:        1%{?dist}
Summary:        Cooperative GPU lock manager for shared multi-GPU nodes

License:        MIT
URL:            https://github.com/HEP-FCC/fccsw-machines
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
Requires:       bash, coreutils, util-linux, systemd
# ordering only, so systemctl/systemd-tmpfiles are guaranteed present when
# our scriptlets run, even though we call them directly rather than via
# the systemd rpm macros.
Requires(post):   systemd
Requires(preun):  systemd
Requires(postun): systemd

%description
excubitor/domestikos is a cooperative, flock-based lock manager for GPUs
on a shared multi-user node. Locks are per-GPU-index; this is
COOPERATIVE only -- it stops nothing at the kernel/driver level and only
works if everyone uses the excubitor wrapper instead of launching CUDA
jobs directly. Pair with NVIDIA's EXCLUSIVE_PROCESS compute mode as a
hard backstop, and the bundled domestikos.timer (installed and started
by this package) as a periodic bypass check.

Provides two commands:
 * excubitor (any user)  -- run, status, clean
 * domestikos (root)     -- gc, status, check, offenders, usage

%prep
%autosetup -n %{name}-%{version}

%build
# nothing to build -- plain shell scripts

%install
make install \
    DESTDIR=%{buildroot} \
    PREFIX=%{_prefix} \
    BINDIR=%{_bindir} \
    LIBEXECDIR=%{_libexecdir}/excubitor \
    TMPFILES_CONF=%{_tmpfilesdir}/excubitor.conf \
    SYSTEMD_UNIT_DIR=%{_unitdir} \
    PROFILED_DIR=%{_sysconfdir}/profile.d

%post
# Best-effort, same as `make install` on a non-packaged system: don't
# fail the RPM transaction over any of this, since a busy GPU is a
# perfectly normal reason for the initial `domestikos check` to fail --
# it'll retry on the next timer tick.
systemd-tmpfiles --create %{_tmpfilesdir}/excubitor.conf || :
systemctl daemon-reload || :
systemctl enable --now domestikos.timer || :
systemctl start domestikos.service || :

%preun
# $1 == 0: final removal. $1 >= 1: upgrade -- leave the timer/service
# running, the new files are about to land on top.
if [ "$1" -eq 0 ]; then
    systemctl disable --now domestikos.timer || :
    systemctl stop domestikos.service || :
fi

%postun
systemctl daemon-reload || :
if [ "$1" -eq 0 ]; then
    echo "Note: %{_localstatedir}/lock/excubitor was left in place in case jobs are still using it." >&2
    echo "Note: current GPU compute mode was left as-is; it will revert to the driver default on the next reboot, since the timer that re-applies it is gone." >&2
fi

%files
%{_bindir}/excubitor
%{_bindir}/domestikos
%dir %{_libexecdir}/excubitor
%dir %{_libexecdir}/excubitor/lib
%{_libexecdir}/excubitor/excubitor
%{_libexecdir}/excubitor/domestikos
%{_libexecdir}/excubitor/lib/excubitor-common.sh
%{_tmpfilesdir}/excubitor.conf
%{_unitdir}/domestikos.service
%{_unitdir}/domestikos.timer
%{_sysconfdir}/profile.d/excubitor.sh

%changelog
* Wed Aug 05 2026 FCC SW Machines <fccsw-machines@cern.ch> - 0.1.1-1
- Clarify -t as a giveup timer for the GPU-wait only, not a limit on the job

* Tue Aug 04 2026 FCC SW Machines <fccsw-machines@cern.ch> - 0.1.0-1
- Initial RPM package
