#! /usr/bin/perl

sub time_stamp {
  my ($d,$t);
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

        $year += 1900;
        $mon++;
        $d = sprintf("%4d-%2.2d-%2.2d",$year,$mon,$mday);
        $t = sprintf("%2.2d:%2.2d:%2.2d",$hour,$min,$sec);
        return($d,$t);
}

1;

