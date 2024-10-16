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

use Data::Printer;

my %addon_name = ( 'ha' => 'sle-ha',
                   'base' => 'sle-module-basesystem',
                   'contm' => 'sle-module-containers',
                   'sdk' => 'sle-module-development-tools',
                   'lgm' => 'sle-module-legacy',
                   'phub' => 'PackageHub',
                   'pcm' => 'sle-module-public-cloud',
                   'python3' => 'sle-module-python3',
                   'serverapp' => 'sle-module-server-applications',
                   'sapapp' => 'sle-module-sap-applications' );

sub get_included_products
{
    die "Code under construction" if not is_sles4sap;
    if (is_sle('=15-SP6')){
        return "base,serverapp,ha,sapapp,python3"; # Desktop applications intentionally left out.
    }
    else{
        die "Code under construction!";
    }
}

sub run {
    my $base_product_key;
    if (is_sles4sap){
        $base_product_key = get_required_var("SCC_REGCODE_SLES4SAP");
    }
    else{
        $base_product_key = get_required_var("SCC_REGCODE");
    }
    select_serial_terminal;

    # Register the base product.
    assert_script_run ("SUSEConnect -r $base_product_key");

    my $version_id = get_required_var('VERSION');
    $version_id =~ s/-SP/./;
    my $cpu = get_required_var('ARCH');
    my @unregistered_addons = split(',', get_required_var("SCC_ADDONS"));
    p @unregistered_addons;
    my @addons_to_register = grep {not ( get_included_products =~ /$_/)} @unregistered_addons;
    p @addons_to_register;
    foreach my $addon  (@addons_to_register){
        assert_script_run("SUSEConnect -p $addon_name{$addon}/$version_id/$cpu");
    }
}

1;
