#!/usr/bin/perl -T

use strict;

sub jira_issues() {

  my $project = shift;
  my $component = shift;
  my $description = shift;

  my $jiralink = "";

  if (($project ne "") && ($component ne "")) {
	my $url = "http://jira.sakaiproject.org/jira/secure/IssueNavigator.jspa?reset=true&mode=hide&type=1&pid=$project&sorter/order=DESC&sorter/field=priority&resolution=-1&component=$component";

	$jiralink = <<JIRAFORM;
<form action="http://jira.sakaiproject.org/jira/secure/IssueNavigator.jspa" target="_blank" type="GET">
<p>JIRA: <a href="$url" target="_blank">Open bugs for $description</a>
Search this component: 
<input size=55 name="query" title="JIRA Search">
<input type=hidden name="reset" value="true">
<input type=hidden name="summary" value="true">
<input type=hidden name="description" value="true">
<input type=hidden name="body" value="true">
<input type=hidden name="type" value="1">
<input type=hidden name="resolution" value="-1">
<input type=hidden name="pid" value="$project">
<input type=hidden name="component" value="$component">
</p>
</form>
JIRAFORM
  }

  if (($project ne "") && ($component eq "")) {
	my $url = "http://jira.sakaiproject.org/jira/secure/IssueNavigator.jspa?reset=true&mode=hide&type=1&pid=$project&sorter/order=DESC&sorter/field=priority&resolution=-1";

	$jiralink = <<JIRAFORM2;
<form action="http://jira.sakaiproject.org/jira/secure/IssueNavigator.jspa" target="_blank" type="GET">
<p>JIRA: <a href="$url" target="_blank">Open bugs for $description</a>
Search this component: 
<input size=55 name="query" title="JIRA Search">
<input type=hidden name="reset" value="true">
<input type=hidden name="summary" value="true">
<input type=hidden name="description" value="true">
<input type=hidden name="body" value="true">
<input type=hidden name="type" value="1">
<input type=hidden name="resolution" value="-1">
<input type=hidden name="pid" value="$project">
</p>
</form>
JIRAFORM2



  }


  return $jiralink;
}

return 1;

