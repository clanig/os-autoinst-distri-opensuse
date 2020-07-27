# SUSE's openQA tests
#
# Copyright (c) 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check cluster integrity
# Maintainer: Christian Lanig <clanig@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use hacluster;
use utils 'systemctl';

sub run {
    select_console 'root-console';
    my $cluster_name = get_cluster_name;

    # Remove iptable rules in node 1 when testing qnetd/qdevice in multicast
    assert_script_run "iptables -F && iptables -X" if (is_node(1) && check_var('QDEVICE_TEST_ROLE', 'client') && !get_var('HA_UNICAST'));

    # Workaround network timeout issue during upgrade
    if (get_var('HDDVERSION')) {
        assert_script_run 'journalctl -b --no-pager -o short-precise > bsc1129385-check-journal.log';
        my $iscsi_fails = script_run 'grep -q "iscsid: cannot make a connection to" bsc1129385-check-journal.log';
        my $csync_fails = script_run 'grep -q "corosync.service: Failed" bsc1129385-check-journal.log';
        my $pcmk_fails  = script_run 'egrep -q "pacemaker.service.+failed" bsc1129385-check-journal.log';

        if (defined $iscsi_fails and $iscsi_fails == 0 and defined $csync_fails
            and $csync_fails == 0 and defined $pcmk_fails and $pcmk_fails == 0)
        {
            record_soft_failure "bsc#1129385";
            upload_logs 'bsc1129385-check-journal.log';
            $iscsi_fails = script_run 'grep -q LIO-ORG /proc/scsi/scsi';
            systemctl 'restart iscsi' if ($iscsi_fails);
            systemctl 'restart pacemaker';
        }
    }

    # Check iSCSI server is connected
    my $ret = script_run 'ls /dev/disk/by-path/ip-*', $default_timeout;
    if ($ret) {    # iscsi is not connected?
        script_run("yast2 iscsi-client; echo yast2-iscsi-client-status-\$? > /dev/$serialdev", 0);
        assert_screen 'iscsi-client-overview-service-tab', $default_timeout;
        send_key 'alt-v';
        wait_still_screen 3;
        assert_screen 'iscsi-client-target-connected', $default_timeout;
        send_key 'alt-c';
        wait_still_screen 3;
        wait_serial('yast2-iscsi-client-status-0', 90) || die "'yast2 iscsi-client' didn't finish";
        assert_screen 'root-console', $default_timeout;
        systemctl 'restart pacemaker', timeout => $default_timeout;
    }
    systemctl 'list-units | grep iscsi', timeout => $default_timeout;
    systemctl 'status pacemaker',        timeout => $default_timeout;

    # And check for the state of the whole cluster
    check_cluster_state;
}

1;
