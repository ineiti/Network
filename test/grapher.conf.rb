{
www_images: '/srv/http/graphs',
bw_upper: 600000,
bw: false,
db: '/var/log/traffic.rrd',
#VLANS=$( tail -n +3 /proc/net/vlan/config | sed -e 's/ .*//' | sed -e 's/vlan//g' | sort -n )
hosts: %w(1 2 3 4 5 6 7 8 9 10 11),
hosts_ips: %w( 192.168.210.1 192.168.210.2 192.168.210.4 192.168.210.5
            192.168.210.5 192.168.210.6 192.168.210.7 192.168.210.8 
            192.168.210.9 192.168.210.10 192.168.210.55 ),
# Red
# Cyan
# Green
# Blue
# Yellow

#COLORS=( 000 000 800 F00 F88 FAA 000 000 000 000
#060 080 0C0 8F8 000 CFC 000 000 000 000
#660 CC0 FF8 000 000 FAF 000 000 000 000 )
colors: %w(
800 F00 F88 FCC 
060 0C0 006 0FF
660 AFA CC0 FFC ),
names_hosts: %w( College Colline Ville Presbytere
AlTatawwur Auxi SCDJ FeuEtJoie
Alisei Rasgolo )
}