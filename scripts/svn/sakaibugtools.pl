#! /usr/bin/perl

# Populate tool id in SAKAI_BUGS table. Run this periodically (e.g. every few hours) from cron.
#

use DBI;
#use strict;

require "/usr/local/sakaiconfig/dbauth.pl";
require "/usr/local/sakaiconfig/dbbugs.pl";

(my $host1, my $dbname1, my $user1, my $password1)= getProductionDbAuth ();
(my $host2, my $dbname2, my $user2, my $password2)= getBugDbAuth ();

my $debug = 0;

my $currentversion = "12";

### Connect to dbs

my $dbh1 = DBI->connect("DBI:mysql:database=$dbname1;host=$host1;port=3306", $user1, $password1) 
	|| die "Could not connect to production database $dbname1: $DBI::errstr";

my $dbh2 = DBI->connect("DBI:mysql:database=$dbname2;host=$host2;port=3306;mysql_socket=/var/lib/mysql/mysql.sock", $user2, $password2)
	|| die "Could not connect to bugs database $dbname2: $DBI::errstr";

### Pull in all the production tool IDs

  my $toolsql = "SELECT SITE_ID, REGISTRATION FROM SAKAI_SITE_TOOL WHERE TOOL_ID=?";
  my $toolsth = $dbh1->prepare($toolsql);

  if ($debug) { print "getting bug reports...\n"; }
  my $eventsql = "select distinct REQPATH from SAKAI_BUGS WHERE VERSION=? and TOOL is NULL";

  my $sth1 = $dbh2->prepare($eventsql) or die "Couldn't prepare statement: " . $dbh2->errstr;
  $sth1->execute($currentversion)             # Execute the query
     or die "Couldn't execute statement: " . $sth1->errstr;

  my $updsql = "update SAKAI_BUGS SET TOOL = ?, SITE_ID = ? WHERE VERSION = ? AND REQPATH LIKE ?";
  my $sth2 = $dbh2->prepare($updsql)  or die "Couldn't prepare statement: " . $dbh2->errstr;

  # Find tool names for placement IDs
  while (my @data = $sth1->fetchrow_array()) {

	my $request = $data[0];

	if ($debug) { print "got path: " . $data[0] . "\n"; }

	if ($request =~ /^\/portal\/tool\/([A-Za-z0-9-!]*)[?]*/) {
		my $toolid = $1;
		#print "  got tool id: " . $1 . "\n";

		(my $siteid, my $registration) = getToolReg($toolid);

		if (defined($registration) && $registration ne "") {
			$sth2->execute($registration, $siteid, $currentversion, "/portal/tool/$toolid%");

		   #print "  got tool id: $toolid site id: $siteid reg: $registration\n";

		}
	} elsif ($request =~ /^\/portal\/site\/([~A-Za-z0-9-!]*)[?]*\/tool\/([A-Za-z0-9-!]*)[?]*/) {
		my $toolid = $2;

		if ($debug) { print "  got site id: $1 tool id: $2\n"; }

		(my $siteid, my $registration) = getToolReg($toolid);

		if (defined($registration) && $registration ne "") {
			$sth2->execute($registration, $siteid, $currentversion, "/portal/site/%/tool/$toolid%");
		   	if ($debug) { print "  got tool id: $toolid site id: $siteid reg: $registration\n"; }
		}
	
	} else {
		my @pathelem = split("/", $request);
		my $registration;

		if (($pathelem[1] eq "portal") || ($pathelem[1] eq "direct") || ($pathelem[1] eq "access")) {
			$registration = "url:" . $pathelem[1] . ":" . $pathelem[2];
		} else {
			$registration = "url:" . $pathelem[1];
		}

		$sth2->execute($registration, null, $currentversion, $request);
		
		## e.g. presence, xlogin, help - ignoring these for now
		if ($debug) { print "not a tool path: $request\n"; }
	}

  }

$sth1->finish();
$sth2->finish();

### All done.

# Get tool registration info for a tool
sub getToolReg($) {

 my $toolid = shift;

 my $t_site = "";
 my $t_reg = "";
 
 $toolsth->execute($toolid);

 while (my @td = $toolsth->fetchrow_array()) {
   $t_site = $td[0];
   $t_reg = $td[1];
 }
 
 return ($t_site, $t_reg);
}

