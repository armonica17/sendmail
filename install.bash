#!/bin/bash
grep CentOS /etc/redhat-release >/dev/null
if [ $? == 0 ] ; then
    centos=1
else
    centos=0
fi
if [ $centos == 0 ] ; then
    dnf -y install cronie sendmail spamassassin clamd sendmail-cf make amavis.noarch amavis-doc.noarch amavisd-milter.x86_64
else
    dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
    dnf --enablerepo=epel,PowerTools -y install amavisd-new clamd perl-Digest-SHA1 perl-IO-stringy make cronie sendmail spamassassin clamd sendmail-cf
    dnf install clamav-server clamav-data clamav-update clamav-filesystem clamav clamav-scanner-systemd clamav-devel clamav-lib clamav-server-systemd
fi

firewall-cmd --permanent --add-port=25/tcp
firewall-cmd --permanent --add-port=587/tcp
firewall-cmd --reload
uname -n >>/etc/mail/local-host-names
mkdir /var/spool/mqueue-rx
chown smmsp:smmsp /var/spool/mqueue-rx
dnf -y install clamav clamav-update clamd
/bin/systemctl start spamassassin.service
/bin/systemctl enable spamassassin.service
#/bin/systemctl enable clamd@scan
#/bin/systemctl start clamd@scan
setsebool -P antivirus_can_scan_system 1
setsebool -P clamd_use_jit 1
cp /usr/share/doc/clamd/clamd.conf /etc/clamd.d/clamd.conf
# Get rid of Example
sed -i '/^Example/d' /etc/clamd.d/clamd.conf
# Set the USER to clamscan
gawk -i inplace '/User/{gsub(/<USER>/, "clamscan")}; {print}' /etc/clamd.d/clamd.conf
# Set it to listen to tcp, otherwise it won't start
sed -i '/^#TCP/s/^#//' /etc/clamd.d/clamd.conf
# How to debug? Use this - /usr/sbin/clamd -c /etc/clamd.d/clamd.conf

cat >/etc/mail/thishost-rx.mc <<- "EOF"
include(`/usr/share/sendmail-cf/m4/cf.m4')dnl
VERSIONID(`setup for linux')dnl
OSTYPE(`linux')dnl
define(`confSMTP_LOGIN_MSG', `Wazzup Wacky Warren $j Sendmail; $b')dnl
define(`confLOG_LEVEL', `9')dnl
define(`confDEF_USER_ID', ``8:12'')dnl
define(`confTO_CONNECT', `1m')dnl
define(`confTRY_NULL_MX_LIST', `True')dnl
define(`confDONT_PROBE_INTERFACES', `True')dnl
define(`PROCMAIL_MAILER_PATH', `/usr/bin/procmail')dnl
define(`ALIAS_FILE', `/etc/aliases')dnl
define(`STATUS_FILE', `/var/log/mail/statistics')dnl
define(`confUSERDB_SPEC', `/etc/mail/userdb.db')dnl
define(`confPRIVACY_FLAGS', `authwarnings,novrfy,noexpn,restrictqrun')dnl
define(`confAUTH_OPTIONS', `A')dnl
define(`confAUTH_MECHANISMS', `EXTERNAL GSSAPI DIGEST-MD5 CRAM-MD5 LOGIN PLAIN')dnl

define(`confCACERT_PATH', `/etc/pki/tls/certs')dnl
define(`confCACERT', `/etc/pki/tls/certs/ca-bundle.crt')dnl
define(`confSERVER_CERT', `/etc/pki/tls/certs/sendmail.pem')dnl
define(`confSERVER_KEY', `/etc/pki/tls/private/sendmail.key')dnl
define(`confTLS_SRV_OPTIONS', `V')dnl


dnl Stick in cert stuff here. I.e. let's encrypt:
dnl define(`CERT_DIR', `/etc/letsencrypt/live/yourdomain/')dnl
dnl define(`confSERVER_CERT',`CERT_DIR/cert.pem')dnl
dnl define(`confSERVER_KEY',`CERT_DIR/privkey.pem')dnl
dnl define(`confCLIENT_CERT',`CERT_DIR/cert.pem')dnl
dnl define(`confCLIENT_KEY',`CERT_DIR/privkey.pem')dnl
dnl define(`confCACERT',`CERT_DIR/fullchain.pem')dnl
dnl define(`confCACERT_PATH',`CERT_DIR')dnl

define(`confCRL', `/etc/pki/tls/certs/revoke.crl')dnl


dnl To be used for MTA-RX, the first MTA instance (receiving mail)
dnl Insert here the usual .mc preamble, including OSTYPE and DOMAIN calls.
dnl Specify here also access controls, relayable domains, anti-spam measures
dnl including milter settings if needed, mail submission settings, client
dnl authentication, resource controls, maximum mail size and header size,
dnl confMIN_FREE_BLOCKS, and other settings needed for receiving mail.
dnl
dnl NOTE:
dnl   confMIN_FREE_BLOCKS at MTA-RX should be kept higher than the same
dnl   setting at MTA-TX to quench down clients when disk space is low,
dnl   and not to stop processing the already received mail.
dnl
dnl In particular, here are some settings to be considered:
dnl   ( see also http://www.sendmail.org/m4/anti_spam.html )
dnl
FEATURE(`access_db')
dnl VIRTUSER_DOMAIN(`sub1.example.com')dnl  list valid users here
dnl VIRTUSER_DOMAIN(`sub2.example.com')dnl  list valid users here
FEATURE(`virtusertable')
dnl define(`confUSERDB_SPEC', `/etc/mail/userdb.db')
dnl FEATURE(`blacklist_recipients')
FEATURE(`use_cw_file')
dnl FEATURE(`use_ct_file')
dnl FEATURE(`nocanonify', `canonify_hosts')dnl
dnl INPUT_MAIL_FILTER(...)
dnl define(`confPRIVACY_FLAGS', `noexpn,novrfy,authwarnings')  nobodyreturn ?
dnl define(`confDONT_PROBE_INTERFACES')
dnl MASQUERADE_AS(...) FEATURE(`allmasquerade') FEATURE(`masquerade_envelope')
dnl define(`confTO_IDENT', `0')dnl  Disable IDENT
dnl define(`confMAX_MESSAGE_SIZE',`10485760')
dnl define(`confMAX_MIME_HEADER_LENGTH', `256/128')
dnl define(`confNO_RCPT_ACTION', `add-to-undisclosed')
dnl define(`confBIND_OPTS', ...)
dnl define(`confTO_RESOLVER_*... )
dnl define(`confDELAY_LA,    8)
dnl define(`confREFUSE_LA', 12)
dnl define(`confMAX_DAEMON_CHILDREN',20)
dnl define(`confMIN_FREE_BLOCKS', `10000')
dnl define(`confDEF_USER_ID', ...)

define(`confRUN_AS_USER',`smmsp:smmsp')dnl  Drop privileges (see SECURITY NOTE)

define(`confPID_FILE', `/var/run/sendmail-rx.pid')dnl  Non-default pid file
define(`STATUS_FILE', `/etc/mail/stat-rx')dnl    Non-default stat file
define(`QUEUE_DIR', `/var/spool/mqueue-rx')dnl   Non-default queue area
define(`confQUEUE_SORT_ORDER',`Modification')dnl Modif or Random are reasonable

dnl Match the number of queue runners (R=) to the number of amavisd-new child
dnl processes ($max_servers). 2 to 7 OK, 10 is plenty, 20 is too many
QUEUE_GROUP(`mqueue', `P=/var/spool/mqueue-rx, R=2, F=f')dnl

dnl Direct all mail to be forwarded to amavisd-new at 127.0.0.1:10024
FEATURE(stickyhost)dnl  Keep envelope addr "u@local.host" when fwd to MAIL_HUB
define(`MAIL_HUB',   `esmtp:[127.0.0.1]')dnl  Forward all local mail to amavisd
define(`SMART_HOST', `esmtp:[127.0.0.1]')dnl  Forward all other mail to amavisd
define(`LOCAL_RELAY',`esmtp:[127.0.0.1]')dnl
FEATURE(`access_db', `hash -T<TMPF> -o /etc/mail/access.db')dnl
FEATURE(`greet_pause',5000)dnl
define(`confBAD_RCPT_THROTTLE', `1')dnl
FEATURE(`blacklist_recipients')dnl

define(`confDELIVERY_MODE',`q')dnl     Delivery mode: queue only (a must,
dnl  ... otherwise the advantage of this setup of being able to specify
dnl  ... the number of queue runners is lost)
define(`ESMTP_MAILER_ARGS',`TCP $h 10024')dnl  To tcp port 10024 instead of 25
MODIFY_MAILER_FLAGS(`ESMTP', `+z')dnl  Speak LMTP (this is optional)
define(`SMTP_MAILER_MAXMSGS',`10')dnl  Max no. of msgs in a single connection
define(`confTO_DATAFINAL',`20m')dnl    20 minute timeout for content checking
DAEMON_OPTIONS(`Name=MTA-RX')dnl       Daemon name used in logged messages
dnl DAEMON_OPTIONS(`Port=smtps, Name=TLSMTA, M=s')dnl

dnl Disable local delivery, as all local mail will go to MAIL_HUB
undefine(`ALIAS_FILE')dnl     No aliases file, all local mail goes to MAIL_HUB
define(`confFORWARD_PATH')dnl Empty search path for .forward files
undefine(`UUCP_RELAY')dnl
undefine(`BITNET_RELAY')dnl
undefine(`DECNET_RELAY')dnl

MAILER(smtp)

dnl  The following solution to reject unknown recipients outright
dnl  is provided by Matej Vela <m...@irb.hr>, see:
dnl  http://groups.google.com/group/comp.mail.sendmail/
dnl    browse_thread/thread/88cc72d7c4d3a6e/ee2a9474b3a4558d
dnl  The FEATURE(stickyhost) short-circuits FEATURE(luser_relay) so that a:
dnl    define(`LUSER_RELAY',`error:5.1.1:"550 User unknown"') can't be used.
dnl  A simple solution is to disable FEATURE(stickyhost). If this is not
dnl  possible, the alternative is to replace FEATURE(luser_relay) with custom
dnl  rules below. The latter has the advantage of properly handling special
dnl  aliases like ("|program", "/mailbox", and ":include:/list").  If choosing
dnl  this route, one should NOT use `undefine(`ALIAS_FILE')dnl', and use the
dnl  following custom rules:
dnl

LOCAL_CONFIG
Kaliasp hash -m /etc/aliases
Kuserp user -m

LOCAL_RULESETS
O CipherList=HIGH:!ADH:!aNULL:!eNULL
SLocal_check_rcpt
R$*		$: <?> $&{rcpt_addr}
R<?> $+ @ $=w	$: <@> $1				mark local address
R<?> $* @ $*	$@ OK					ignore remote address
R<?> $+		$: <@> $1				mark unqualified user
R<@> $+ + $*	$: < $(aliasp $1+$2 $: @ $) > $1 + *	plussed alias?
R<@> $+ + $*	$: < $(aliasp $1+$2 $: @ $) > $1	+* alias?
R<@> $+		$: < $(aliasp $1 $: @ $) > $1		normal alias?
R<@> $+		$: < $(userp $1 $: @ $) > $1		system user?
R<@> $+		$#error $@ 5.1.1 $: "550 User unknown"	nope, go away 
EOF






cat >/etc/mail/thishost-tx.mc <<- "EOF1"
include(`/usr/share/sendmail-cf/m4/cf.m4')dnl
VERSIONID(`setup for linux')dnl
OSTYPE(`linux')dnl
dnl To be used for MTA-TX, the second MTA instance
dnl (delivering outgoing and local mail)

dnl Insert here the usual .mc preamble, including OSTYPE and DOMAIN calls.

dnl Specify here also the required outgoing mail processing and
dnl local delivery settings such as mailertables, needed mailers, aliases,
dnl local delivery mailer settings, smrsh, delivery mode, queue groups, ...
dnl Don't use milters here - for all common filtering purposes they belong
dnl to MTA-RX; an exception to this rule would be DKIM or DomainKeys mail
dnl signing milters (signature _verification_ milters still belong to MTA-RX).

define(`confREFUSE_LA',999)dnl  Disable the feature, limiting belongs to MTA-RX
define(`confMAX_DAEMON_CHILDREN',0)dnl  Disable, limiting belongs to MTA-RX
FEATURE(`no_default_msa')dnl  No need for another MSA, MTA-RX already has one
FEATURE(`nocanonify')dnl      Host/domain names are considered canonical
DAEMON_OPTIONS(`Addr=127.0.0.1, Port=10025, Name=MTA-TX')dnl Listen on lo:10025
FEATURE(`smrsh', `/usr/sbin/smrsh')dnl
FEATURE(`mailertable', `hash -o /etc/mail/mailertable.db')dnl
FEATURE(`virtusertable', `hash -o /etc/mail/virtusertable.db')dnl
FEATURE(redirect)dnl
FEATURE(always_add_domain)dnl
FEATURE(use_cw_file)dnl
FEATURE(use_ct_file)dnl
FEATURE(local_procmail, `', `procmail -t -Y -a $h -d $u')dnl
define(`confSMTP_LOGIN_MSG', `$w.tx.$m Sendmail $v/$Z; $b')dnl
define(`confTO_IDENT', `0')dnl  Disable IDENT

MAILER(smtp)
MAILER(procmail)dnl
MAILER(local)
EOF1

if [ ! -f /etc/amavisd/amavisd.conf.bak ] ; then
  cp /etc/amavisd/amavisd.conf /etc/amavisd/amavisd.conf.bak
fi
FQDN=`uname -n`
HOSTNAME=`echo $FQDN |awk -F. '{ print $1 }'`
DOMAIN=`echo $FQDN |awk -F. '{$1="";OFS="." ; print $0}' | sed 's/^.//' |sed s/\ /./g`
sed s/host.example.com/$FQDN/g /etc/amavisd/amavisd.conf.bak >/etc/amavisd/amavisd.conf.bak1
sed s/example.com/$DOMAIN/g /etc/amavisd/amavisd.conf.bak1 >/etc/amavisd/amavisd.conf
rm -f /etc/amavisd/amavisd.conf.bak1


/bin/systemctl enable amavisd.service
/bin/systemctl start amavisd.service

cd /etc/mail
make
m4 thishost-rx.mc >/etc/mail/sendmail-rx.cf
m4 thishost-tx.mc >/etc/mail/sendmail.cf
chown smmsp access.db
chown smmsp domaintable.db
chown smmsp  mailertable.db
chown smmsp  virtusertable.db
touch /var/log/clamd.scan
chown clamscan /var/log/clamd.scan
cat >/etc/cron.daily/clamfreshen <<- "EOF2"
#!/bin/bash
/usr/bin/freshclam
EOF2
touch /var/log/freshclam.log
chown clamupdate /var/log/freshclam.log
cat >/etc/mail/access <<- "EOF3"
# Check the /usr/share/doc/sendmail/README.cf file for a description
# of the format of this file. (search for access_db in that file)
# The /usr/share/doc/sendmail/README.cf is part of the sendmail-doc
# package.
#
# If you want to use AuthInfo with "M:PLAIN LOGIN", make sure to have the 
# cyrus-sasl-plain package installed.
#
# By default we allow relaying from localhost...
Connect:localhost.localdomain           RELAY
Connect:localhost                       RELAY
Connect:127.0.0.1                       RELAY
srecemail.com REJECT
lifeworkresource.com REJECT
touchtract.com REJECT
myvzw.com REJECT
in.net REJECT
hey7346.com REJECT
# TLD Reject
# New bullshit domains to reject.
accountant                REJECT
actor                    REJECT
airforce                REJECT
army                    REJECT
audio                    REJECT
band                    REJECT
blackfriday                REJECT
christmas                REJECT
click                    REJECT
club                    REJECT
cricket                    REJECT
dance                    REJECT
date                    REJECT
degree                    REJECT
democrat                REJECT
dentist                    REJECT
diet                    REJECT
download                REJECT
faith                    REJECT
forsale                    REJECT
futbol                    REJECT
gift                    REJECT
gives                    REJECT
guitars                    REJECT
help                    REJECT
hiphop                    REJECT
ninja                    REJECT
party                    REJECT
photo                    REJECT
pro                    REJECT
rest                   REJECT
rip                    REJECT
rocks                    REJECT
sexy                    REJECT
show                    REJECT
site                    REJECT
social                    REJECT
tattoo                    REJECT
top                    REJECT
#us                    REJECT
wang                    REJECT
webcam                    REJECT
win                    REJECT
xyz                    REJECT
host                   REJECT
icu                    REJECT
best                   REJECT
EOF3

cat >/root/mail.bash <<- "EOF4"
#!/bin/bash
/usr/sbin/sendmail -C/etc/mail/sendmail-rx.cf -L sm-mta-rx -bd -qp
/usr/sbin/sendmail                            -L sm-mta-tx -bd -q15m
EOF4
cd
chmod +x /root/mail.bash
crontab -l >crontabfile.$$
echo "@reboot /root/mail.bash" >>crontabfile.$$
crontab crontabfile.$$
rm crontabfile.$$
