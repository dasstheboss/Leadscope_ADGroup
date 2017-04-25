use XML::Simple;
use Data::Dumper;
use DBI;
use POSIX 'strftime';
use XML::Writer;
use IO::File;


sub  trim {
  my $s = shift; $s =~ s/^\s+|\s+$//g;
  return $s;
}


sub hashConfigurations {
  my ($configurations) = @_;
  my %config = ();
  open(IN, $configurations);
  my @config_array = <IN>;
  close(IN);

  foreach $line (@config_array){
    my @pair = split("=", $line);
    my $key = &trim($pair[0]);
    my $value = &trim($pair[1]);
    $config{$key} = $value;
  }
  return %config;
}

sub adParse {
 #$ENV{PATH} = "/usr/bin/";
 my @userID = `/usr/bin/ldapsearch -x -H ldap://unxldap.global.lilly.com/ -b ou=group,dc=gds,o=lilly.com cn=lseUser | sed -n -e 's/^memberUid.* //p'`;
 chomp(@userID);
 print "No of users:", scalar(@userID),"\n";
 return @userID;
}

sub XML_Parse {
my %config = @_;
 my $xmlPath = $config{'xmlPath'};

 my $xml = XML::Simple->new( );
 my $input = $xml->XMLin($xmlPath, forcearray => 1);

 my @output=();
 foreach $ID (@{$input->{application}{LeadScopeEnterpriseServer}{key}{server}{key}{'auth.principal.name'}{value}}){

    push(@output,$ID->{content});
  }
  print "No of users:", scalar(@output),"\n";
  return @output;
}

sub xmlRemover{
 my $toRemove = $_[0];
 #my $xmlPath = "./LSEPreferences.xml";
 system("sed -i /$toRemove/Id $config_hash{'xmlPath'}");
}

sub xmlWriter{
 my $newUser = $_[0];
 $newUser = &trim($newUser);
 print "New user: $newUser \n";
 #tet path of XMl file from config file 
# my $xmlPath = "./LSEPreferences.xml";
 #ente new user ID to Preference fiel
 open(FILE,"$xmlPath") || die "can't open file for read\n";
 my @lines=<FILE>;
 close(FILE);
 open(FILE,">$xmlPath")|| die "can't open file for write\n";
 foreach $line (@lines){
    print FILE $line;
    print FILE "<value type=\"java.lang.String\">$newUser</value>\n" if($line =~ /<key name="auth.principal.name">/); #Insert newUser Id along with required text.
  }
 close(FILE);
}

sub idCompare{
 my ($ad_ref,$xml_ref)= @_;
 my @adUser  = @{ $ad_ref };
 my @xmlUser = @{ $xml_ref };
 my @finalUser; 
 tr/a-z/A-Z/ for @adUser;
 tr/a-z/A-Z/ for @xmlUser;
 #print "AD: @adUser \n";
 #print "XML:@xmlUser \n";

 my %diff;

 @diff{ @xmlUser } = undef;
 delete @diff{ @adUser };

 my @toRemove = keys %diff; 

 foreach $xml (@toRemove){
   &xmlRemover($xml);
   my $logDetail = "[Revoke]	User ID '$xml'	deleted from LSEPreference.xml file.";
   &logNotify($logDetail) or die;
   print "$xml is deleted from LSEPref file \n";
 }

 my %diff1;

 @diff1{ @adUser } = undef;
 delete @diff1{ @xmlUser };

 my @toAdd = keys %diff1;

 foreach $ad (@toAdd){
   &xmlWriter($ad);
   my $logDetail = "[Grant]	User ID '$ad'	inserted to LSEPreference.xml file.";
   &logNotify($logDetail) or die;
   print "$ad is inserted to LSEPref file \n";
 }

}

sub logNotify {
  my ($logPath) = $config_hash{'logPath'};
  my $logDetail = $_[0];
  my $date = strftime '%Y-%m-%d %T', localtime;
  open ($logFile, '>>', $logPath) or die;
  print $logFile "$date - $logDetail \n";
  close $logFile;
}

$config_file = shift;
%config_hash = &hashConfigurations($config_file);
$xmlPath = $config_hash{'xmlPath'};   #It is a global variable, will be used in xmlRemover and xmlWriter
my @activeUsers = &XML_Parse(%config_hash);
my @adUsers = &adParse;
&idCompare(\@adUsers,\@activeUsers);
