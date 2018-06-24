#! /usr/bin/perl

use DBI;
use strict;
use CGI qw/escapeHTML/;

require '/usr/local/sakaiconfig/vula_auth.pl';
require '/usr/local/sakaiscripts/alerts.pl';

# Bugs db connection details
(my $dbname, my $dbhost, my $username, my $password) = getBugsDbConfig();

# Production db connection details
(my $prod_dbname, my $prod_dbhost, my $prod_username, my $prod_password) = getDbConfig();

my $debug = 0;
my $verbose = 1;

my $service = "Vula";
my $scripturi="/mrtg/scripts/viewbugs.pl";

### Get the tool registration details from the database

my $dbh = DBI->connect("DBI:mysql:database=$dbname;host=$dbhost;port=3306", $username, $password)
        || die "Could not connect to bugs database: $DBI::errstr";

my $prod_dbh = DBI->connect("DBI:mysql:database=$prod_dbname;host=$prod_dbhost;port=3306", $prod_username, $prod_password)
        || die "Could not connect to production database: $DBI::errstr";

(my $date, my $time) = &time_stamp();

my $bugs_day_count = query_count($dbh, "select count(DISTINCT EID) FROM SAKAI_BUGS WHERE (UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(BUG_DATE)) < 86400 and TOOL IS NOT NULL and EID is not null");
my $bugs_week_count = query_count($dbh, "select count(DISTINCT EID) FROM SAKAI_BUGS WHERE (UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(BUG_DATE)) < 86400*7 and TOOL IS NOT NULL and EID is not null");
my $bugs_month_count = query_count($dbh, "select count(DISTINCT EID) FROM SAKAI_BUGS WHERE (UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(BUG_DATE)) < 86400*30 and TOOL IS NOT NULL and EID is not null");
my $bugs_60d_count = query_count($dbh, "select count(DISTINCT EID) FROM SAKAI_BUGS WHERE (UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(BUG_DATE)) < 86400*60 and TOOL IS NOT NULL and EID is not null");

my $bugs_day_distinct = query_count($dbh, "select count(DISTINCT CAUSED_AT, TOOL) FROM SAKAI_BUGS WHERE (UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(BUG_DATE)) < 86400");
my $bugs_week_distinct = query_count($dbh, "select count(DISTINCT CAUSED_AT, TOOL) FROM SAKAI_BUGS WHERE (UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(BUG_DATE)) < 86400*7");
my $bugs_month_distinct = query_count($dbh, "select count(DISTINCT CAUSED_AT, TOOL) FROM SAKAI_BUGS WHERE (UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(BUG_DATE)) < 86400*30");
my $bugs_60d_distinct = query_count($dbh, "select count(DISTINCT CAUSED_AT, TOOL) FROM SAKAI_BUGS WHERE (UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(BUG_DATE)) < 86400*60");

my $users_day = query_count($prod_dbh, "select count(DISTINCT SESSION_USER) FROM SAKAI_SESSION WHERE (UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(SESSION_START)) < 86400");

chomp($bugs_day_count);
chomp($bugs_week_count);
chomp($bugs_month_count);
chomp($users_day);

my @headings = ("Tool", "Bugs", "Distinct Bugs", "Affected Users", "Impact", "Weighted Impact");

my $bugs_day = query_table($dbh, "select TOOL, COUNT(TOOL), count(DISTINCT CAUSED_AT), count(DISTINCT EID), ROUND((COUNT(TOOL)+COUNT(DISTINCT EID))/COUNT(DISTINCT CAUSED_AT),1), ROUND((COUNT(TOOL)+COUNT(DISTINCT EID))/COUNT(DISTINCT CAUSED_AT)*count(DISTINCT EID) / $bugs_day_count,1) FROM SAKAI_BUGS WHERE COMMENT IS NULL and (UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(BUG_DATE)) < 86400 GROUP BY TOOL HAVING TOOL IS NOT NULL ORDER BY COUNT(TOOL) DESC", $scripturi, 1, @headings);

my $bugs_week = query_table($dbh, "select TOOL, COUNT(TOOL), count(DISTINCT CAUSED_AT), count(DISTINCT EID), ROUND((COUNT(TOOL)+COUNT(DISTINCT EID))/COUNT(DISTINCT CAUSED_AT),1), ROUND((COUNT(TOOL)+COUNT(DISTINCT EID))/COUNT(DISTINCT CAUSED_AT)*count(DISTINCT EID) / $bugs_week_count,1) FROM SAKAI_BUGS WHERE COMMENT IS NULL and (UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(BUG_DATE)) < 86400*7 GROUP BY TOOL HAVING TOOL IS NOT NULL ORDER BY COUNT(TOOL) DESC", $scripturi, 7, @headings);

my $bugs_month = query_table($dbh, "select TOOL, COUNT(TOOL), count(DISTINCT CAUSED_AT), count(DISTINCT EID), ROUND((COUNT(TOOL)+COUNT(DISTINCT EID))/COUNT(DISTINCT CAUSED_AT),1),  ROUND((COUNT(TOOL)+COUNT(DISTINCT EID))/COUNT(DISTINCT CAUSED_AT)*count(DISTINCT EID) / $bugs_month_count,1) FROM SAKAI_BUGS WHERE COMMENT IS NULL and (UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(BUG_DATE)) < 86400*30 GROUP BY TOOL HAVING TOOL IS NOT NULL ORDER BY COUNT(TOOL) DESC", $scripturi, 30, @headings);

my $bugs_60days = query_table($dbh, "select TOOL, COUNT(TOOL), count(DISTINCT CAUSED_AT), count(DISTINCT EID), ROUND((COUNT(TOOL)+COUNT(DISTINCT EID))/COUNT(DISTINCT CAUSED_AT),1),  ROUND((COUNT(TOOL)+COUNT(DISTINCT EID))/COUNT(DISTINCT CAUSED_AT)*count(DISTINCT EID) / $bugs_month_count,1) FROM SAKAI_BUGS WHERE COMMENT IS NULL and (UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(BUG_DATE)) < 86400*60 GROUP BY TOOL HAVING TOOL IS NOT NULL ORDER BY COUNT(TOOL) DESC", $scripturi, 60, @headings);


my $comments_day_count = query_count($dbh, "select COUNT(*) FROM SAKAI_BUGS WHERE COMMENT IS NOT NULL and (UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(BUG_DATE)) < 86400");
my $comments_week_count = query_count($dbh, "select COUNT(*) FROM SAKAI_BUGS WHERE COMMENT IS NOT NULL and (UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(BUG_DATE)) < 86400*7");
my $comments_month_count = query_count($dbh, "select COUNT(*) FROM SAKAI_BUGS WHERE COMMENT IS NOT NULL and (UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(BUG_DATE)) < 86400*30");
my $comments_60d_count = query_count($dbh, "select COUNT(*) FROM SAKAI_BUGS WHERE COMMENT IS NOT NULL and (UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(BUG_DATE)) < 86400*60");

my $comments_day = "<a href=\"$scripturi?comment=1&amp;period=1\">User comments: $comments_day_count</a>";
my $comments_week = "<a href=\"$scripturi?comment=1&amp;period=7\">User comments: $comments_week_count</a>";
my $comments_month = "<a href=\"$scripturi?comment=1&amp;period=30\">User comments: $comments_month_count</a>";
my $comments_60days = "<a href=\"$scripturi?comment=1&amp;period=60\">User comments: $comments_60d_count</a>";

my $bugs_day_pct = sprintf("%.2f", $bugs_day_count / $users_day * 100);

## Output data for mrtg graphing purposes

my $bugs_day_mrtg = int($bugs_day_count / $users_day * 1000 + 0.5);
my $bugs_mrtg_data = "/usr/local/sakaiscripts/bugs_per_1000.txt";

open (MRTGDATA, ">$bugs_mrtg_data");
print MRTGDATA "$bugs_day_mrtg\n";
print MRTGDATA "0";
close (MRTGDATA);

## HTML output

print <<HTML;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" 
	"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
<head>
<title>$service Bug Summary</title>
<link rel="stylesheet" type="text/css" href="https://vula.uct.ac.za/library/content/uct/css/bugs.css" />
</head>
<body>
<h2>$service Bug Summary</h2>
<div class="instruction">Updated $date $time</div>
<h3>Last 24 hours</h3>
$bugs_day
<p>
Total affected users: $bugs_day_count / $users_day ($bugs_day_pct%)<br/>
Total distinct bugs: $bugs_day_distinct<br/>
$comments_day
</p>
<h3>Last 7 days</h3>
$bugs_week
<p>
Total affected users: $bugs_week_count<br/>
Total distinct bugs: $bugs_week_distinct<br/>
$comments_week
</p>
<h3>Last 30 days</h3>
$bugs_month
<p>
Total affected users: $bugs_month_count<br/>
Total distinct bugs: $bugs_month_distinct<br/>
$comments_month
</p>
<h3>Last 60 days</h3>
$bugs_60days
<p>
Total affected users: $bugs_60d_count<br/>
Total distinct bugs: $bugs_60d_distinct<br/>
$comments_60days
</p>
</body>
</html>
HTML

## Functions

sub query_count() {
 my $dbh = shift;
 my $sql = shift;

 my $result = "";

 my $sth = $dbh->prepare($sql);
 $sth->execute();

 my @ary = $sth->fetchrow_array ();
 $result = $ary[0];

 $sth->finish();
 
 return $result;
}

sub query_table() {
 my $dbh = shift;
 my $sql = shift;
 my $scripturi = shift;
 my $period = shift;
 my @headings = @_;

 my $sth = $dbh->prepare($sql);
 $sth->execute();

 my $html = "<table class=\"overview\">\n";

 $html = $html . "<tr>\n";
 # Show headings
 foreach(@headings) {
	my $hclass = $_;
	$hclass =~ s/\s//g;
	$html = $html . "<th class=\"$hclass\">$_</th>\n";
 }
 $html = $html . "</tr>\n";

 # read results of query, then clean up
 while (my @ary = $sth->fetchrow_array ())
	{
		$html = $html . "<tr>\n";
		my $column = 0;
		foreach(@ary)
		{
			my $hclass = $headings[$column];
			$hclass =~ s/\s//g;
			my $link;
			if ($column == 0) {
				$link = "<a href=\"$scripturi?tool=$_\&amp;period=$period\">" . escapeHTML($_) . "</a>";
			} else {
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

