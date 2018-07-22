#!/usr/bin/perl -T

use strict;
use CGI qw/escapeHTML/;
use DBI;

require '/srv/www/vhosts/vula.uct.ac.za/mrtg/scripts/jira.pl';
require '/srv/www/vhosts/vula.uct.ac.za/mrtg/scripts/timestamp.pl';

require '/usr/local/sakaiconfig/vula_bugs_auth.pl';

(my $dbname, my $dbhost, my $username, my $password) = getBugsDbConfig();
(my $date, my $time) = &time_stamp();

my $dbh = DBI->connect("DBI:mysql:database=$dbname;host=$dbhost;port=3306", $username, $password)
        || die "Could not connect to database: $DBI::errstr";

my $service = "Vula";
my $service_prefix = "https://vula.uct.ac.za";
my $css = "$service_prefix/library/content/uct/css//bugs.css";

my $q = new CGI;                        # create new CGI object

## Fields
my $toolid = $q->param('tool');
my $siteid = $q->param('site');
my $user = $q->param('user');
my $period= $q->param('period');
my $comment= $q->param('comment');

if ($toolid =~ /([a-z.:-]+)/) {
	$toolid = $1;
} else {
	$toolid = "unknown";
}

if ($siteid =~ /([!A-Za-z0-9.-]+)/) {
	$siteid = $1;
} else {
	$siteid = "unknown";
}

if ($user =~ /([a-z0-9@.]+)/) {
	$user= $1;
} else {
	$user= "unknown";
}


if ($period =~ /([0-9]+)/) {
	$period = $1;
} else {
	$period = 1;
}

if ($comment =~ /([0-9]+)/) {
	$comment = $1;
} else {
	$comment = 0;
}

my $jira_proj = "";
my $jira_comp = "";
my $tooldesc = "";
my $bugs_desc;

if ($toolid ne "unknown") {
	# Get tool info for placement ID
	my $toolreg = $dbh->selectall_hashref("SELECT REGISTRATION, DESCRIPTION, JIRA_PROJ, JIRA_COMP FROM SAKAI_TOOLS WHERE REGISTRATION='$toolid'", "REGISTRATION");

	if (defined($toolreg->{$toolid})) {
		$jira_proj = $toolreg->{$toolid}->{'JIRA_PROJ'};
		$jira_comp = $toolreg->{$toolid}->{'JIRA_COMP'};
		$tooldesc = escapeHTML($toolreg->{$toolid}->{'DESCRIPTION'});
	}
}

my @headings;
my $scripturi = "bugdetail.pl";

my $bugs_table;
my $jira_link;

if ($toolid ne "unknown") {
	@headings = ("ID", "Date", "User", "Site", "Path", "CausedBy", "CausedAt");
	$bugs_table = query_table($dbh, "select BUG_ID, BUG_DATE, EID, SITE_ID, REQPATH, CAUSED_BY, CAUSED_AT FROM SAKAI_BUGS WHERE TOOL='$toolid' and (UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(BUG_DATE)) < 86400*$period order by BUG_ID DESC", $scripturi, $period, $toolid, @headings);
	$jira_link = jira_issues($jira_proj, $jira_comp, $tooldesc);
	$bugs_desc = "Tool: $tooldesc ($toolid)";
}

if ($user ne "unknown") {
	@headings = ("ID", "Date", "Tool", "Site", "Path", "CausedBy", "CausedAt");
	$bugs_table = query_table($dbh, "select BUG_ID, BUG_DATE, TOOL, SITE_ID, REQPATH, CAUSED_BY, CAUSED_AT FROM SAKAI_BUGS WHERE EID='$user' and (UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(BUG_DATE)) < 86400*$period order by BUG_ID DESC", $scripturi, $period, $toolid, @headings);
	$jira_link = "";
	$bugs_desc = "User: $user";
}

if ($siteid ne "unknown") {
	@headings = ("ID", "Date", "Tool", "User", "Path", "CausedBy", "CausedAt");
	$bugs_table = query_table($dbh, "select BUG_ID, BUG_DATE, TOOL, EID, REQPATH, CAUSED_BY, CAUSED_AT FROM SAKAI_BUGS WHERE SITE_ID='$siteid' and (UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(BUG_DATE)) < 86400*$period order by BUG_ID DESC", $scripturi, $period, $toolid, @headings);
	$jira_link = "";
	$bugs_desc = "Site: $siteid";
}

if ($comment == 1) {
	@headings = ("ID", "Date", "User", "CausedBy", "CausedAt");
	$bugs_table = query_table($dbh, "select BUG_ID, BUG_DATE, EID, CAUSED_BY, CAUSED_AT FROM SAKAI_BUGS WHERE COMMENT IS NOT NULL and (UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(BUG_DATE)) < 86400*$period order by BUG_ID DESC", $scripturi, $period, $toolid, @headings);
	$jira_link = "";
	$bugs_desc = "Bugs with user comments";
}

print $q->header();

print <<HTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "https://www.w3.org/TR/html4/loose.dtd">
<html>
<HEAD>
<TITLE>$service Tool Bugs: $toolid : $period day(s)</TITLE>
<link rel="stylesheet" type="text/css" href="$css" />
<script language="JavaScript" src="jquery-latest.js"></script>
<script language="JavaScript" src="jquery.tablesorter.js"></script>
<script language="JavaScript">
	\$(document).ready(function() {
		\$("#bugsTable").tablesorter({ widgets: ['zebra'] });
	}); 
	</script>
</HEAD>
<body>
<h2>$service Bug Summary</h2>
<div class="instruction">Updated $date $time</div>
<p>
$bugs_desc
<br>
Days: $period
</p>
$jira_link
$bugs_table
</body>
</html>
HTML

sub query_table() {
 my $dbh = shift;
 my $sql = shift;
 my $scripturi = shift;
 my $period = shift;
 my $toolid = shift;
 my @headings = @_;

 my $sth = $dbh->prepare($sql);
 $sth->execute();

 my $html = "<table id=\"bugsTable\" class=\"tablesorter\" border=\"0\" cellpadding=\"0\" cellspacing=\"1\"><thead><tr>\n";

 # Print titles
 foreach (@headings)
 {
   $html = $html . "<th class=\"header\">$_</th>";
 }
 $html = $html . "</tr></thead>";

 # read results of query, then clean up
 while (my @ary = $sth->fetchrow_array ())
        {
                $html = $html . "<tr>\n";
                my $column = 0;
                foreach(@ary)
                {
                        my $hclass = $headings[$column];
                        my $link = "";

                        if ($headings[$column] eq "ID") {
                                $link = "<a href=\"$scripturi?bug=$_\">" . escapeHTML($_) . "</a>";
                        }

			if ($headings[$column] eq "User") {
                                $link = "<a href=\"?user=$_&period=$period\">" . escapeHTML($_) . "</a>";
                        } 

			if ($headings[$column] eq "Tool") {
                                $link = "<a href=\"?tool=$_&period=$period\">" . escapeHTML($_) . "</a>";
                        } 

			if ($headings[$column] eq "Site") {
                                $link = "<a href=\"?site=$_&period=$period\">" . escapeHTML($_) . "</a>";
                        } 

			if ($link eq "") {
                                $link = escapeHTML($_);
                        }
                        $html = $html . "<td class=\"$hclass\">$link</td>\n";
                        $column++;
                }
                $html = $html . "</tr>\n";
        }
 $sth->finish ();
 $html = $html . "</table>\n";
 return $html;
}

