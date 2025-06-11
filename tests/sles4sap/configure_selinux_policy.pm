# Copyright 2018-2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Configure SELinux policy.
# Maintainer: QE SAP <qe-sap@suse.de>

use base 'selinuxtest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle);
use Utils::Architectures;
use bootloader_setup;
use power_action_utils;

sub restorecon_rootfs {
    # restorecon does not behave too well with btrfs, so exclude /.snapshots in btrfs rootfs
    assert_script_run 'test -d /.snapshots && restorecon -R / -e /.snapshots';
    assert_script_run 'test -d /.snapshots || restorecon -R /';
}

sub run {
    my ($self) = @_;

    return "SLES4SAP 15 does not support SELinux. Doing nothing." if is_sle('<16');
    select_serial_terminal;

    my $policy = get_var('SELINUX_POLICY') // 'permissive';
    die "Invalid policy type." unless $policy =~ /permissive|enforcing|disabled/;
    record_info("Policy:$policy");

    if ($policy eq 'disabled') {
        replace_grub_cmdline_settings('security=selinux', 'security=apparmor', update_grub => 0);
        replace_grub_cmdline_settings('selinux=1', 'selinux=0', update_grub => 1);
        prepare_system_shutdown;
        power_action('reboot');
        opensusebasetest::wait_boot(opensusebasetest->new(), bootloader_time => 200);
        select_serial_terminal;
        validate_script_output(
            'sestatus',
            sub { m/SELinux\ status:\ .*disabled.*/sx });
        return;
    }

    assert_script_run('semanage boolean -m --on selinuxuser_execmod');
    assert_script_run('semanage boolean -m --on unconfined_service_transition_to_unconfined_user');
    assert_script_run('semanage permissive -a snapper_grub_plugin_t');
    assert_script_run('semanage permissive -a sap_unconfined_t');

    restorecon_rootfs();

    record_info("Policy:$policy");
    $self->set_sestatus($policy, 'targeted');

    assert_script_run('semanage boolean -l -C');
    assert_script_run('semanage permissive -l');
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
