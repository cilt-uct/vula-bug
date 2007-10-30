#! /usr/bin/perl

## sakaibuglog.pl - archive Sakai bug reports to a database

## To create the required schema, use 
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
  PRIMARY KEY  (`BUG_ID`)
) ENGINE=InnoDB AUTO_INCREMENT=51 DEFAULT CHARSET=utf8

=cut

use DBI;
use MIME::Parser;

use strict;

#####################
# declare variables #
#####################

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

if ($msgtxt =~ /user:\s([A-Za-z0-9@]+)\s/) {
  $eid = $1;
# print "found eid: $eid\n";
}

if ($msgtxt =~ /email:\s([A-Za-z0-9\@\.]+)/) {
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

if ($msgtxt =~ /request-path:\s([A-Za-z0-9.?=%&\/-]+)/) {
  $reqpath = $1;
# print "found reqpath: $reqpath\n";
}

if ($msgtxt =~ /server:\s([A-Za-z0-9%\/-]+)/) {
  $server = $1;
# print "found server: $server\n";
}

if ($msgtxt =~ /user\scomment:\s([\w\s\n-.%!\/@\:\.]+)\nstack\strace:/) {
  $comment = $1;
  $comment =~ s/^\n+|\n+$//g;
# print "found comment: [$comment]\n";
}

#print "End.\n";

###################################################
# log in database                                 #
###################################################

if ($digest ne "") {
	### Connect to dbs

	my $dbh = DBI->connect("DBI:mysql:database=$dbname;host=$host;port=3306", $user, $password)
        || die "Could not connect to bug database $dbname: $DBI::errstr";

	## For now we just use the current date/time to avoid parsing the mm-ddd-yy date format

	my $insertsql = "INSERT INTO SAKAI_BUGS (BUG_DATE, EID, EMAIL, SESSION, DIGEST, VERSION, REVISION, SERVER, REQPATH, BODY, COMMENT ) VALUES (NOW(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
	my $sth = $dbh->prepare($insertsql) or die "Couldn't prepare statement: " . $dbh->errstr;

	$sth->execute($eid, $email, $session, $digest, $version, $revision, $server, $reqpath, $msgtxt, $comment);

	$sth->finish;
	$dbh->disconnect;
} else {
	die "Not a bug report";
}

## functions ##

