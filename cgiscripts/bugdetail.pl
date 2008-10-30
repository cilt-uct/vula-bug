#!/usr/bin/perl -wT

use strict;
use CGI qw/escapeHTML unescapeHTML/;
use DBI;

require '/srv/www/vhosts/mrtg/scripts/jira.pl';
require '/srv/www/vhosts/mrtg/scripts/timestamp.pl';

require '/usr/local/sakaiconfig/vula_bugs_auth.pl';

my $service = "Vula";
my $service_prefix = "https://vula.uct.ac.za";
my $css = "$service_prefix/library/skin/bugs.css";

(my $dbname, my $dbhost, my $username, my $password) = getBugsDbConfig();
(my $date, my $time) = &time_stamp();

my $dbh = DBI->connect("DBI:mysql:database=$dbname;host=$dbhost;port=3306", $username, $password)
        || die "Could not connect to database: $DBI::errstr";

my $q = new CGI;                        # create new CGI object

## Sanitize fields
my $bugid = $q->param('bug');;

if ($bugid =~ /([0-9]+)/) {
	$bugid = $1;
} else {
	$bugid = 100;
}

# Bug info
my $buginfo= $dbh->selectall_hashref("SELECT BUG_ID, TOOL, SITE_ID, BODY, COMMENT FROM SAKAI_BUGS WHERE BUG_ID=$bugid", "BUG_ID");

my $toolid = $buginfo->{$bugid}->{'TOOL'};
my $bug_body = escapeHTML($buginfo->{$bugid}->{'BODY'});
my $bug_comment = escapeHTML($buginfo->{$bugid}->{'COMMENT'});
my $siteid = $buginfo->{$bugid}->{'SITE_ID'};

# Get tool info for placement ID
my $toolreg = $dbh->selectall_hashref("SELECT REGISTRATION, DESCRIPTION, JIRA_PROJ, JIRA_COMP FROM SAKAI_TOOLS WHERE REGISTRATION='$toolid'", "REGISTRATION");

my $jira_proj = "";
my $jira_comp = "";
my $tooldesc = "";

if (defined($toolreg->{$toolid})) {
        $jira_proj = $toolreg->{$toolid}->{'JIRA_PROJ'};
        $jira_comp = $toolreg->{$toolid}->{'JIRA_COMP'};
        $tooldesc = escapeHTML($toolreg->{$toolid}->{'DESCRIPTION'});
}


my $jira_link = jira_issues($jira_proj, $jira_comp, $tooldesc);

my $site_link = "";
my $tool_link = "";

if ($siteid ne "null") {
	$site_link = "<a href=\"$service_prefix/portal/site/$siteid\" target=\"_blank\">$siteid</a>";
	$tool_link = "<a href=\"$service_prefix/portal/directtool/$toolid?sakai.site=$siteid\" target=\"_blank\">$toolid</a>";
}

if ($bug_comment ne "") {
  $bug_comment = "Comment:<br/>$bug_comment<br/><br>";
}

print $q->header();

print <<HTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "https://www.w3.org/TR/html4/loose.dtd">
<html>
<HEAD>
<TITLE>$service Bug Details: $bugid ($tooldesc)</TITLE>
<link rel="stylesheet" type="text/css" href="$css" />
</HEAD>
<body style="padding:0.3em;">
<h2>$service Bug Summary</h2>

<table id="bugSummaryTable" class="buginfo" border="0" cellpadding="1" cellspacing="1">
<tr>
  <td>Bug#&nbsp;</td><td>$bugid</td>
</tr>
<tr>
  <td>Site</td><td>$site_link</td>
</tr>
<tr>
  <td>Tool</td><td>$tool_link</td>
</td>
</tr>
</table>
<p>$jira_link</p>

<table id="bugDetailTable" class="detail" border="0" cellpadding="0" cellspacing="1">
<tr>
<td class="Body"><pre>
$bug_comment
$bug_body
</pre></td>
</tr>
</table>

</body>
</html>
HTML

