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
use registration qw (get_addon_fullname);

sub get_included_products
{
    die "Code under construction" if not is_sles4sap;
    if (is_sle('=15-SP2') or is_sle('=15-SP3') or is_sle('=15-SP4')) {
        return "base,serverapp,ha,sapapp";
    }
    elsif (is_sle('=15-SP5') or is_sle('=15-SP6')) {
        return "base,serverapp,ha,sapapp,python3";    # Desktop applications intentionally left out.
    }
    elsif (is_sle('=12-SP5')) {
        return "";
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

    my $version_id = get_required_var('VERSION');
    $version_id =~ s/-SP/./;
    my $cpu = get_required_var('ARCH');
    my @unregistered_addons = split(',', get_required_var("SCC_ADDONS"));
    my @addons_to_register = grep { not(get_included_products =~ /$_/) } @unregistered_addons;
    foreach my $addon (@addons_to_register) {
        my $addon_name = get_addon_fullname($addon);
        die "Invalid addon name. Check if SCC_ADDONS var is set correctly." unless (defined $addon_name);
        assert_script_run("SUSEConnect -p $addon_name/$version_id/$cpu");
    }
}

1;
