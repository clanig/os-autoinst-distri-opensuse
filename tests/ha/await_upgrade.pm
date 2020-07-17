# SUSE's openQA tests
#
# Copyright (c) 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Wait for all nodes which are allowed to upgrade before.
# Maintainer: Christian Lanig <clanig@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use hacluster;
use lockapi;

sub run {

    my $cluster_name = get_cluster_name;
    for (1 .. get_node_number) {
        if (is_node $_) {
            record_info "Upgrade barrier info", "It's our turn to upgrade.";
            return;
        }
	record_info "Upgrade barrier info", "Waiting for node $_ to upgrade.";

        # Make sure cluster integrity can be checked by other nodes.
        barrier_wait "CHECK_AFTER_REBOOT_BEGIN_$cluster_name";
        barrier_wait "CHECK_AFTER_REBOOT_END_$cluster_name";
        barrier_wait "NODE_UPGRADED_${cluster_name}_NODE$_";
    }
}

1;
