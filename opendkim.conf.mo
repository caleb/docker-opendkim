# This is a basic configuration that can easily be adapted to suit a standard
# installation. For more advanced options, see opendkim.conf(5) and/or
# /usr/share/doc/opendkim/examples/opendkim.conf.sample.

UserID opendkim:opendkim

Background false
Socket {{OPENDKIM_SOCKET}}
Syslog true

# Required to use local socket with MTAs that access the socket as a non-
# privileged user (e.g. Postfix)
UMask			002

KeyTable     refile:/etc/opendkim/KeyTable
SigningTable refile:/etc/opendkim/SigningTable

Mode sv
SubDomains no
ADSPAction continue

# Always oversign From (sign using actual From and a null From to prevent
# malicious signatures header fields (From and/or others) between the signer
# and the verifier.  From is oversigned by default in the Debian pacakge
# because it is often the identity key used by reputation systems and thus
# somewhat security sensitive.
OversignHeaders		From
