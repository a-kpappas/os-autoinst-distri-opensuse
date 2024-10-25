# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Bring up for the SAP/HA incident install tests in openQA

use strict;
use warnings;

use base "opensusebasetest";
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils qw(is_sles4sap is_sle);
use suseconnect_register;

use Data::Printer;

my %addon_name = (
    'base' => 'sle-module-basesystem',
    'contm' => 'sle-module-containers',
    'ha' => 'sle-ha',
    'lgm' => 'sle-module-legacy',
    'pcm' => 'sle-module-public-cloud',
    'phub' => 'PackageHub',
    'python2' => 'sle-module-python2',
    'python3' => 'sle-module-python3',
    'sapapp' => 'sle-module-sap-applications',
    'sdk' => 'sle-module-development-tools',
    'serverapp' => 'sle-module-server-applications'
);

sub get_included_products
{
    die "Code under construction" if not is_sles4sap;
    if (is_sle('=15-SP2') or is_sle('=15-SP3') or is_sle('=15-SP4')) {
        return "base,serverapp,ha,sapapp";
    }
    elsif (is_sle('=15-SP5') or is_sle('=15-SP6')) {
        return "base,serverapp,ha,sapapp,python3";    # Desktop applications intentionally left out.
    }
    elsif (is_sle('=12-SP5')){
        assert_script_run ('SUSEConnect -l');
    }
    else {
        die "Code under construction!";
    }
}

sub run {
    my $base_product_key;
    if (is_sles4sap) {
        $base_product_key = get_required_var("SCC_REGCODE_SLES4SAP");
    }
    else {
        $base_product_key = get_required_var("SCC_REGCODE");
    }
    select_serial_terminal;

    # Register the base product.
    assert_script_run("SUSEConnect -r $base_product_key");

    suseconnect_registration;

    # my $version_id = get_required_var('VERSION');
    # $version_id =~ s/-SP/./;
    # my $cpu = get_required_var('ARCH');
    # my @unregistered_addons = split(',', get_required_var("SCC_ADDONS"));
    # p @unregistered_addons;
    # my @addons_to_register = grep { not(get_included_products =~ /$_/) } @unregistered_addons;
    # p @addons_to_register;
    # foreach my $addon (@addons_to_register) {
    #     assert_script_run("SUSEConnect -p $addon_name{$addon}/$version_id/$cpu");
    # }
}

1;
