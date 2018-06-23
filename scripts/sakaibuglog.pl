#! /usr/bin/perl

## sakaibuglog.pl - archive Sakai bug reports to a database. Requires Sakai 2-6-x or 2-5-x with SAK-14478

## This is an email handler for emailed bug reports from the portal.error.email address specified in sakai.properties.

## Pipe incoming mail to this script in the MTA (SMTP server) aliases file, e.g. for exim,
## 	vula_bugs:              "|/usr/local/sakaiscripts/sakaibuglog.pl"

## To create the required db schema, use 
##    pod2text sakaibuglog.pl | mysql dbname

=begin text

CREATE TABLE `SAKAI_BUGS` (
  `BUG_ID` bigint(20) NOT NULL auto_increment,
  `BUG_DATE` datetime default NULL,
  `EID` varchar(255) default NULL,
  `EMAIL` varchar(255) default NULL,
  `SESSION` varchar(255) default NULL,
  `DIGEST` varchar(255) default NULL,
  `VERSION` varchar(255) default NULL,
  `REVISION` varchar(255) default NULL,
  `SERVER` varchar(255) default NULL,
  `REQPATH` varchar(255) default NULL,
  `BODY` text,
  `COMMENT` text,
  `TOOL` varchar(255) default NULL,
  `SITE_ID` varchar(255) default NULL,
  `USER_AGENT` varchar(255) default NULL,
  `CAUSED_BY` varchar(255) default NULL,
  `CAUSED_AT` varchar(255) default NULL,
  `SAKAI_BUGID` varchar(255) default NULL,
  PRIMARY KEY  (`BUG_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 

=cut

use DBI;
use MIME::Parser;

use strict;

#####################
# declare variables #
#####################

# die "I am: ". getlogin() . " / " . $>;

require "/usr/local/sakaiconfig/dbbugs.pl";

(my $host, my $dbname, my $user, my $password)= getBugDbAuth ();

###################
# parse the email #
###################

# Temp dir
my $bugtmp = "/tmp/bugreports";

### Create the temporary dir for MIME body parts
mkdir $bugtmp;

### Create a new parser object:
my $parser = MIME::Parser->new();

### Tell it where to put things:
$parser->output_dir($bugtmp);

# Decode bodies
$parser->decode_bodies(1);

### Parse an input filehandle:
my $entity = $parser->parse(\*STDIN) or die "MIME parse failed\n";

my $subject = $entity->head->get('subject');
my $from = $entity->head->get('from');
my $msgdate = $entity->head->get('date');
my $msgid = $entity->head->get('message-id');

die "Invalid email" if !($subject =~ /^Bug\sReport:/);

my $hascomment = ($subject =~ /(comment)/);

chomp $from;
chomp $subject;

my $msgtxt = "";

## As yet no MIME parts, but we need the decoding for quoted-printable

my @parts = $entity->parts;

if (@parts) {                     # multipart...
	my $msgbody = $parts[0];

	my ($type, $subtype) = split('/', $msgbody->head->mime_type);
	my $body = $msgbody->bodyhandle;

	if ($msgbody->bodyhandle) {
		$msgtxt = $msgbody->bodyhandle->as_string;
    	}
    	else {
	  ### this message has no body data (but it might have parts!)
	  die "message has no body parts";
    	}
    }
   else
{   
   $msgtxt = $entity->bodyhandle->as_string;
}

## Cleanup temp files used
$parser->filer->purge();

#################################
# parse some details
#################################

my $bugid;
my $eid;
my $email;
my $session;
my $digest = "";
my $version;
my $revision;
my $server;
my $datetime;
my $reqpath;
my $comment;
my $ua;
my $causedby;
my $causedat;

if ($msgtxt =~ /bug-id:\s([A-Za-z0-9\@\.-]+)\s/) {
  $bugid = $1;
# print "found bug-id: $bugid\n";
}

if ($msgtxt =~ /user:\s([A-Za-z0-9\@\._]+)\s/) {
  $eid = $1;
# print "found eid: $eid\n";
}

if ($msgtxt =~ /email:\s([A-Za-z0-9\@\._]+)/) {
  $email = $1;
# print "found email: $email\n";
}

if ($msgtxt =~ /usage-session:\s([A-Za-z0-9-]+)/) {
  $session = $1;
# print "found session: $session\n";
}

if ($msgtxt =~ /stack-trace-digest:\s([A-Za-z0-9-]+)/) {
  $digest = $1;
# print "found digest: $digest\n";
}

if ($msgtxt =~ /sakai-version:\s([A-Za-z0-9-.]+)/) {
  $version = $1;
# print "found version: $version\n";
}

if ($msgtxt =~ /service-version:\s([A-Za-z0-9-.\[\]]+)/) {
  $revision = $1;
# print "found revision: $revision\n";
}

if ($msgtxt =~ /time:\s([A-Za-z0-9-]+)\s(\d{2}:\d{2}:\d{2})/) {
  $datetime = $1 . " " . $2;
# print "found datetime: $datetime\n";
}

if ($msgtxt =~ /request-path:\s([A-Za-z0-9~.?=_%&\/-]+)/) {
  $reqpath = $1;
# print "found reqpath: $reqpath\n";
}

if ($msgtxt =~ /server:\s([A-Za-z0-9%\/-]+)/) {
  $server = $1;
# print "found server: $server\n";
}

if ($msgtxt =~ /user-agent:\s(.*)\n/) {
  $ua = $1;
# print "found ua: $ua\n";
}

if ($msgtxt =~ /user\scomment:\s([\w\s\n-.%!\/@\:\.]+)\nstack\strace:/) {
  $comment = $1;
  $comment =~ s/^\n+|\n+$//g;
# print "found comment: [$comment]\n";
}

while ($msgtxt =~ m/caused\sby:\s(.*)\n\s\s\s\sat\s(.*)\n/g) {
  $causedby = $1;
  $causedat = $2;
# print "found caused-by: $causedby ## at $causedat\n";
}

if (!defined($causedby)) {
  # Look for an RSF-style caused-by
  while ($msgtxt =~ m/-->\s(.*)\n\s\s\s\sat\s(.*)\n/g) {
    $causedby = $1;
    $causedat = $2;
  # print "found RSF caused-by: $causedby ## at $causedat\n";
  }
}
#print "End.\n";

###################################################
# log in database                                 #
###################################################

# Don't save bug reports that have empty comments (as a pre-comment bug report will already have been saved)

if (($digest ne "") && !$hascomment)  {
	### Connect to dbs

	my $dbh = DBI->connect("DBI:mysql:database=$dbname;host=$host;port=3306;mysql_socket=/var/lib/mysql/mysql.sock", $user, $password)
        || die "Could not connect to bug database $dbname: $DBI::errstr";

	## For now we just use the current date/time to avoid parsing the mm-ddd-yy date format

	my $insertsql = "INSERT INTO SAKAI_BUGS (BUG_DATE, SAKAI_BUGID, EID, EMAIL, SESSION, DIGEST, VERSION, REVISION, SERVER, REQPATH, BODY, USER_AGENT, CAUSED_BY, CAUSED_AT ) VALUES (NOW(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
	my $sth = $dbh->prepare($insertsql) or die "Couldn't prepare statement: " . $dbh->errstr;

	$sth->execute($bugid, $eid, $email, $session, $digest, $version, $revision, $server, $reqpath, $msgtxt, $ua, $causedby, $causedat);

	$sth->finish;
	$dbh->disconnect;

#	print "Saved in db.\n";
} 

# If this has a comment and a bug id, update the database with the comment

if (($bugid ne "") && $hascomment && ($comment ne "")) {
	### Connect to dbs

	my $dbh = DBI->connect("DBI:mysql:database=$dbname;host=$host;port=3306", $user, $password)
        || die "Could not connect to bug database $dbname: $DBI::errstr";

	my $updatesql = "UPDATE SAKAI_BUGS SET COMMENT = ? WHERE SAKAI_BUGID = ?";
	my $sth = $dbh->prepare($updatesql) or die "Couldn't prepare statement: " . $dbh->errstr;

	$sth->execute($comment, $bugid);

	$sth->finish;
	$dbh->disconnect;

}

## functions ##

