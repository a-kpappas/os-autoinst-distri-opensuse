# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


# Summary: QAM incident install test in openQA
#    1) boots prepared image / clean install
#    2) update it to last released updates
#    3) install packages mentioned in patch
#    5) try install update and store install_logs
#    6) try reboot
#    7) all done
#
# Maintainer: Ondřej Súkup <osukup@suse.cz>


use base "opensusebasetest";

use strict;
use warnings;
use List::Util qw(reduce);

use utils;
use power_action_utils qw(prepare_system_shutdown power_action);

use qam;
use testapi;
use JSON;
sub resolve_conflicts {
    my $pack_ref = $_[0];
    my %conflict = (
        'p11-kit-nss-trust'      => 'mozilla-nss-certs',
        'mozilla-nss-certs'      => 'p11-kit-nss-trust',
        'rmt-server-config'      => 'rmt-server-pubcloud'
    );
    foreach (@{$pack_ref}){
        zypper_call("rm $conflict{$_}", exitcode => [0, 104]) if exists($conflict{$_}); 
    }
}

sub get_patch {
    my ($incident_id, $repos) = @_;
    $repos =~ tr/,/ /;
    my $patches = script_output("zypper patches -r $repos | awk -F '|' '/$incident_id/ { printf \$2 }'", type_command => 1);
    save_screenshot;
    $patches =~ s/\r//g;
    return $patches;
}
sub get_patchinfos {
    my ($patches) = @_;
    my $patches_status = script_output("zypper -n info -t patch $patches", 200);
    return $patches_status;
}

sub change_repos_state {
    my ($repos, $state) = @_;
    $repos =~ tr/,/ /;
    zypper_call("mr --$state $repos");
}

sub run {
    #0. Initialize system.
    my ($self)      = @_;
    select_console 'root-console';
    #Deactivate nVIDIA repos.
    zypper_call(q{mr -d $(zypper lr | awk -F '|' '/NVIDIA/ {print $2}')}, exitcode => [0, 3]);
    fully_patch_system;
    my $incident_id = get_required_var('INCIDENT_ID');
    my $repos       = get_required_var('INCIDENT_REPO');
    #1. Find  binaries to be installed.
    #1.a) Query SMELT for the main package of the Maintenance Request
    my @packages = get_packages_in_MR($incident_id);
    #1.b) Extract module names for supplied repos.
    my @modules;
    foreach ( split(/,/,get_required_var('INCIDENT_REPO'))){
        if ($_=~ m{SUSE_Updates_(?<product>.*)/}){
            push(@modules, $+{product});
        }
    }
    #1.c) Query SMELT for name and maintenance status of binaries associated with the package
    my %binaries;
    foreach (@packages){
        %binaries = ( %binaries, get_bins_for_packageXmodule($_,\@modules));
    }
    #1.d Seperate them according to maintenance status. Ignore unsupported.
    my @l2 = grep{ ($binaries{$_}->{'supportstatus'} eq 'l2') } keys %binaries; 
    my @l3 = grep{ ($binaries{$_}->{'supportstatus'} eq 'l3') } keys %binaries;
    #1.e Seperate binaries that existed before the update and ones introduced by it.
    my @new_binaries; 
    my @existing_binaries;
    foreach (@l2,@l3) {
        my $ref = zypper_search('--match-exact '. $_ );
        push(@existing_binaries, $_) if (scalar @{$ref});
        push(@new_binaries, $_) unless (scalar @{$ref});
    }
    #1.f) Remove conflicting binaries.
    resolve_conflicts(\@existing_binaries);
    #1.g) Install the existing package
    my $zypper_status = zypper_call("in -l @existing_binaries", timeout => 1500, exitcode => [0, 102, 103],log=>'prepare.log');
    if ($zypper_status == 102){
        prepare_system_shutdown;
        power_action("reboot");
        $self->wait_boot(bootloader_time => 200);
    }
    set_var('MAINT_TEST_REPO', $repos);
    add_test_repositories;
    my $patches = get_patch($incident_id, $repos);
    my $patch_infos = get_patchinfos($patches);
    zypper_call("in -l -t patch ${patches}", exitcode => [0, 102, 103], log => 'zypper.log', timeout => 1500);
    prepare_system_shutdown;
    power_action("reboot");
    $self->wait_boot(bootloader_time => 200);
}

sub test_flags {
    return {fatal => 1};
}

1;
