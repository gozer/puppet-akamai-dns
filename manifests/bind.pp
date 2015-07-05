class dns::bind {
    user {
        'named-update':
            ensure => present,
            system => true,
            home   => '/var/named';
    }
    
    exec {
        'rndc-keygen':
            cwd       => "/var/named/chroot/etc",
            command   => "/usr/sbin/rndc-confgen -r /dev/urandom -a -k rndckey -b 384 -c rndc.key",
            creates   => "/var/named/chroot/etc/rndc.key",
            logoutput => on_failure,
            before    => Service['named'],
            require   => [ Package['bind'], Exec["dns-svn-checkout"] ];
    
        # The install script for bind makes /var/named/chroot/var/named/slaves, which angers svn checkout
        'dns-svn-cleanup':
            cwd         => "/var/named/chroot/var/named/",
            command     => "/bin/rm -rf /var/named/chroot/var/named/slaves /var/named/chroot/var/named/data",
            environment => "SVN_SSH=/usr/bin/ssh -oStrictHostKeyChecking=no",
            onlyif      => '/usr/bin/test -d /var/named/chroot/var/named/slaves -a \! -d /var/named/chroot/var/named/.svn',
            require     => Package['bind-chroot'];

        'dns-svn-checkout':
            cwd         => "/var/named/chroot/var/named/",
            command     => "/usr/local/sbin/dns-svn-checkout",
            creates     => "/var/named/chroot/var/named/.svn",
            logoutput   => on_failure,
            user        => "named-update",
            require     => [
                File['/var/named/chroot/var/named'],
                File['/usr/local/sbin/dns-svn-checkout'],
                Package['subversion'],
                Exec["dns-svn-cleanup"],
            ],
            before      => Service['named'];
    
        # Bug 845107
        'enforce-ownership':
            path        => '/usr/bin:/usr/sbin:/bin:/sbin',
            command     => '/usr/bin/find /var/named/chroot/var/named \( -type d -name dynamic -prune -o -type d -name slaves -prune \) -o -not -user named-update -exec chown -h named-update:named-update {} \;',
            onlyif      => '/usr/bin/find /var/named/chroot/var/named \( -type d -name dynamic -prune -o -type d -name slaves -prune \) -o -not -user named-update -print | /bin/grep -q ".*"',
            require     => Exec["dns-svn-checkout"]
    }
    
    host {
        'svn.mozilla.org':
            ensure  => present,
            ip      => "63.245.217.46",
            comment => "Need this for the nameservers to access svn via the external interface";
    }
}
