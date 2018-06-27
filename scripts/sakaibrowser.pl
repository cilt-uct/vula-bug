#! /usr/bin/perl

=begin text
CREATE TABLE `SAKAI_USER_AGENT` (
`USER_AGENT_ID` bigint(20) NOT NULL auto_increment,
  `USER_AGENT` varchar(255) default NULL,
  `Browser` bigint(20) NOT NULL,
  `Browser_Version` bigint(20) NOT NULL,
  `OS` bigint(20) NOT NULL,
   PRIMARY KEY  (`USER_AGENT_ID`),
   KEY (`USER_AGENT`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `SAKAI_BROWSER` (
     `BROWSER_ID` bigint(20) NOT NULL auto_increment,
     `BROWSER` varchar(255) default NULL,
     PRIMARY KEY  (`BROWSER_ID`),
     KEY (`BROWSER`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `SAKAI_BROWSER_VERSION` (
    `BROWSER_VERSION_ID` bigint(20) NOT NULL auto_increment,
    `BROWSER_VERSION` varchar(255) default NULL,
    PRIMARY KEY  (`BROWSER_VERSION_ID`),
    KEY (`BROWSER_VERSION_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE TABLE `SAKAI_OS` (
     `OS_ID` bigint(20) NOT NULL auto_increment,
     `OS` varchar(255) default NULL,
     PRIMARY KEY  (`OS_ID`),
     KEY (`OS`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO SAKAI_BROWSER (BROWSER ) VALUES ('UNAVAILABLE');
INSERT INTO SAKAI_BROWSER_VERSION (BROWSER_VERSION) VALUES ('UNAVAILABLE'); 
INSERT INTO SAKAI_OS (OS) VALUES ('UNAVAILABLE');##
=cut

use DBI;
#use strict;
use HTTP::BrowserDetect;

   require "/usr/local/sakaiconfig/dbbugs.pl";
   
   (my $host, my $dbname, my $user, my $password)= getBugDbAuth ();
   
  
#getuUserAgent("Mozilla/5.0 (Linux; Android 5.0.1; GT-I9500 Build/LRX22C) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.91 Mobile Safari/537.36");

sub getuUserAgent ()
    {
    my ($user_agent_string) = @_;
    
    
    my $ua = HTTP::BrowserDetect->new($user_agent_string);
 
    print $user_agent_string, "\n";
    
    my $dbh = DBI->connect("DBI:mysql:database=$dbname;host=$host;port=3306", $user, $password)
        || die "Could not connect to bug database $dbname: $DBI::errstr";
    
    $us = "SELECT USER_AGENT_ID from SAKAI_USER_AGENT where USER_AGENT = '$user_agent_string'";
    @usag = $dbh->selectrow_array($us);
    $uadb = $usag[0];
    print "UA dt: $uadb \n";
    # Print general information
    
    if ($uadb == NULL) {
        print "UA NULL! \n\n";
        
        print "Version: ", $ua->browser_version,$ua->browser_beta, "\n";
     
        $OS_ID = getOperatingSystem($ua->os_string);
        $BROWSER = getBrowser($ua->browser_string);
        
        $BROWSER_VERSION = getBrowserVersion($ua->browser_version,$ua->browser_beta);
        
        print "OS_ID: $OS_ID \n";
        
        my $uainsertsql = "INSERT INTO SAKAI_USER_AGENT (USER_AGENT, OS, BROWSER, BROWSER_VERSION ) VALUES (?, ?, ?, ?)";
        my $sth = $dbh->prepare($uainsertsql) or die "Couldn't prepare statement: " . $dbh->errstr;
        $sth->execute($user_agent_string, $OS_ID, $BROWSER, $BROWSER_VERSION);
        $sth->finish;
        @usag = $dbh->selectrow_array($us);
        $uadb = $usag[0];
        print "UA dt2: $uadb \n";
    }
    if ($ua->tablet) {
        print "Tablet: OK \n";
    }
    
    if ($ua->mobile) {
        print "Mobile: OK \n";
    }
    $dbh->disconnect;
    return $uadb;
}

sub getOperatingSystem () 
 {
 print "getOperatingSystem ()\n";
 my ($OSB) = @_;
 print "OS string: $OSB \n";
 my $u = "UNAVAILABLE";
 
 if ($OSB eq "") {
    print "OS: null!"; 
    $OSB = $u
 }
 

 
  my $dbh = DBI->connect("DBI:mysql:database=$dbname;host=$host;port=3306", $user, $password)
        || die "Could not connect to bug database $dbname: $DBI::errstr";
  my $p = "SELECT * from SAKAI_OS where OS='$OSB'";
  @row_ary = $dbh->selectrow_array($p);
  print "OS: $p \n";
  $os_id = @row_ary[0];
  print "OS id: $os_id \n";
 
  if ($os_id eq "") {
    print "OS database $OSB \n\n";
    my $insertsql = "INSERT INTO SAKAI_OS (OS) VALUES (?)";
    my $sth = $dbh->prepare($insertsql) or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($OSB);

	$sth->finish;
    @row_ary = $dbh->selectrow_array($p);
	
  }

    
	
    $dbh->disconnect;
     return $os_id;
}

sub getBrowser () 
 {
 print "getBROWSER ()\n";
 my ($BB) = @_;
 print "BROWSER string: $BB \n";
 
 
 if ($BB eq "") {
    print "BROWSER: null!"; 
    $BB =  "UNAVAILABLE";
 }
 

 
  my $dbh = DBI->connect("DBI:mysql:database=$dbname;host=$host;port=3306", $user, $password)
        || die "Could not connect to bug database $dbname: $DBI::errstr";
  my $pp = "SELECT * from SAKAI_BROWSER where BROWSER='$BB'";
  @row_ary = $dbh->selectrow_array($pp);
  print "BROWSER: $pp0 \n";
  $os_id = @row_ary[0];
  print  "BROWSER id: $os_id \n";
 
  if ($os_id eq "") {
    print "BROWSER database $BB \n\n";
    my $insertsql = "INSERT INTO SAKAI_BROWSER (BROWSER) VALUES (?)";
    my $sth = $dbh->prepare($insertsql) or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($BB);

	$sth->finish;
    @row_ary = $dbh->selectrow_array($p);
	
  }

    
	
    $dbh->disconnect;
    return $os_id;
}

sub getBrowserVersion () 
 {
 print "getBROWSERVERSION ()\n";
 my ($BB) = @_;
 print "BROWSER_VERSION string: $BB \n";
 
 
 if ($BB eq "") {
    print "BROWSER_VERSION: null!"; 
    $BB =  "UNAVAILABLE";
 }
 

 
  my $dbh = DBI->connect("DBI:mysql:database=$dbname;host=$host;port=3306", $user, $password)
        || die "Could not connect to bug database $dbname: $DBI::errstr";
  my $pp = "SELECT * from SAKAI_BROWSER_VERSION where BROWSER_VERSION='$BB'";
  @row_ary = $dbh->selectrow_array($pp);
  print "BROWSER_VERSION: $pp0 \n";
  $os_id = @row_ary[0];
  print  "BROWSER_VERSION id: $os_id \n";
 
  if ($os_id eq "") {
    print "BROWSER_VERSION database $BB \n\n";
    my $insertsql = "INSERT INTO SAKAI_BROWSER_VERSION (BROWSER_VERSION) VALUES (?)";
    my $sth = $dbh->prepare($insertsql) or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($BB);

	$sth->finish;
    @row_ary = $dbh->selectrow_array($p);
	
  }

    
	
    $dbh->disconnect;
    return $os_id;
}
     
