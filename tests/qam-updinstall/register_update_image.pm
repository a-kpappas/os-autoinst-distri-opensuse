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


# Returns a string containing the addons that are added to the system when the base product is registered
sub get_included_products
{
    my $flavor = get_var("FLAVOR");
    unless ($flavor =~ /SAP-Incidents-Install/ or $flavor =~ /HA-Incidents-Install/) {
        die "This module might be scheduled for the wrong product";
    }
    if (is_sle('=15-SP2') or is_sle('=15-SP3') or is_sle('=15-SP4')) {
        return "base,serverapp,ha,sapapp,desktop" if is_sles4sap;
        die "Product unsupported";
    }
    elsif (is_sle('=15-SP5') or is_sle('=15-SP6')) {
        return "base,serverapp,ha,sapapp,python3,desktop" if is_sles4sap;
        return "base,serverapp,python3";
    }
    elsif (is_sle('=12-SP5')) {
        return "" if is_sles4sap;
        die "Product unsupported";
    }
    else {
        die "This module might be scheduled for the wrong product";
    }
}

sub run {
    select_serial_terminal;
    # Register base product
    #
    #SLES(-HA) and SLES4SAP are different base products. Registering them using
    #SUSEConnect only requires a product key.

    my $base_product_key;

    if (is_sles4sap) {
        $base_product_key = get_required_var("SCC_REGCODE_SLES4SAP");
    }
    else {
        $base_product_key = get_required_var("SCC_REGCODE");
    }
    assert_script_run("SUSEConnect -r $base_product_key");

    # Register addons.

    # Registering them requires inputing the CPU and VERSION_ID of the SUT. We
    # are getting these from openQA vars and not /etc/os-release because it is
    # easier.
    my $version = get_required_var('VERSION');
    my $version_id = $version;
    $version_id =~ s/-SP/./;
    my $cpu = get_required_var('ARCH');


    my $scc_addons = get_required_var('SCC_ADDONS');

    # All products need LTSS for 12-SP5.
    if (is_sle '=12-SP5') {
        my $ltss_key = get_required_var("SCC_REGCODE_LTSS");
        assert_script_run("SUSEConnect -p SLES-LTSS/12.5/$cpu -r $ltss_key");
        $scc_addons = s/ltss[,]?//;
    }

    my $flavor = get_required_var("FLAVOR");
    if ($flavor =~ /HA-Incidents-Install/) {
        # sle-ha needs a seperate key if installed on vanilla SLES.
        my $ha_key = get_required_var("SCC_REGCODE_HA");
        assert_script_run("SUSEConnect -p sle-ha/$version_id/$cpu -r $ha_key");
        $scc_addons = s/ha[,]?//;
    }

    # Do not add PackageHub if the update package is qemu. There is a known
    # conflict and PackageHub is not supported.
    if (get_var('BUILD') =~ /qemu/ && get_var('INCIDENT_REPO') !~ /Packagehub-Subpackages/) {
        record_info('No PackageHub', 'known conflict on qemu update with phub repo poo#162704');
        $scc_addons = s/phub[,]?//;
    }

    my @unregistered_addons = split(',', $scc_addons);

    # Remove already registered addons from the list of addons to register to save on typing.
    my @addons_to_register = grep { not(get_included_products =~ /$_/) } @unregistered_addons;
    foreach my $addon (@addons_to_register) {
        my $addon_name = get_addon_fullname($addon);
        die "Invalid addon name. Check if SCC_ADDONS var is set correctly." unless (defined $addon_name);
        assert_script_run("SUSEConnect -p $addon_name/$version_id/$cpu");
    }
}

1;
