#version: 2010-09-10

#!/usr/local/bin/perl -w

use strict;
#use cwd;
use diagnostics;

use LWP::UserAgent;
use LWP::Simple;
use Win32;
use Compress::Zlib;

#*****************************GLOBAL  VARIABLES****************************#
my $bDEBUG = 0;
my ($TRUE, $FALSE, $SUCCESS, $FAILED) = (1,0,1,0);
my $osVersion = "";

my $NEWLINE = "\r\n";
#*****************************AUXILIARY  FUNCTIONS****************************#
sub DEBUG_INFO {
  return if (!$bDEBUG);
  if (defined(@_)) {
    print "@_\n";
  } else {
    print "Not Defined!\n";
  }
}
sub D {DEBUG_INFO(@_);}
sub P {print "@_\n";}

sub LOG_FILE {
  my($fileName, $bAppData, @logPara) = @_;  #bAppData -- append date to file or overwrite file
  #DEBUG_INFO($fileName, $bAppData);
  $fileName =~ s!\\!/!ig;
  my @pathAry = split('/', $fileName);
  my $tmpPath = "";
  for (my $i=0; $i<scalar(@pathAry)-1; $i++) {
      $tmpPath .= $pathAry[$i] . '/';   #D($tmpPath);
      mkdir($tmpPath, 0111) if (! -d $tmpPath);
  }
  if ($bAppData) {$fileName = " >> " . $fileName;  #append data
  } else         {$fileName = " > " . $fileName;}

  open(tmpLogFile, $fileName) || die "Cannot open log file: $fileName!\n";
  foreach (@logPara) {print tmpLogFile "$_\n";}
  close(tmpLogFile);
}

sub download_webpage {
  my ($url, $savedFName) = @_;  D("In download_webpage() -- $savedFName\t$url");
  my $userAgent = new LWP::UserAgent;
  $userAgent->agent('Mozilla/5.0');

  my $req = HTTP::Request->new('GET', $url);
  #my $req = new HTTP::Request ('POST',$address);
  $req->content_type('application/x-www-form-urlencoded');
  #$req->content();

  my $res = $userAgent->request($req);
  LOG_FILE($savedFName, $FALSE, $res->as_string());
}#download_webpage

sub download_bin {
  my ($url, $savedFName) = @_;  D("In download_bin() -- $savedFName\t$url");
  my $outcome = get ($url);
  open FILE,"> $savedFName" || die "$!";
  binmode(FILE);
  print FILE $outcome if(defined $outcome);
  close FILE;
}

sub send_request {
  my ($url, $reqStr) = @_;  D("In send_request() -- $url\n$reqStr");

  my $ua = LWP::UserAgent -> new();
  #$ua->agent('Mozilla/5.0');
  $ua->agent('Jakarta Commons-HttpClient/3.1');
  #request
  my $req = new HTTP::Request ('POST',$url);
  #$req->content_type('application/x-www-form-urlencoded');
  $req->content_type('text/xml;charset=UTF-8');
  $req->content($reqStr);
  #response
  my $resp = $ua->request($req);  #D($res->as_string());
  #D($resp->is_success());
  #D($resp->message());
  my $respStr = $resp->content();
  if ($respStr=~/Error/i) {
    P("** Send reqeust got ERROR! **\nExiting...\n"); exit 0;
  }
}#send_request

sub trim($) {
    my $string = shift;
    $string =~ s/^\s+//;  $string =~ s/\s+$//;
    return $string;
}

sub isEmptyStr {
    my ($result, $str) = (0, @_);
    $result = 1 if (!defined($str) || $str eq "" || $str=~m/^\s+$/ig);
    return $result;
}

sub parse_args {
  P(@_);
  for (my $i=0; $i<scalar(@_); $i++) {
    if ($_[$i] eq "-debug") {
      $bDEBUG = $TRUE;   #D("bDEBUG is set to: $bDEBUG");
    } else {

    }
  }
  if (defined $^O) {$osVersion =  $^O;} else {$osVersion = "win32"; }  D("osVersion is: $osVersion");
}
###############################################################################
sub main {
  my ($content, $articleId) = ("", "");
  my ($pageNo, $lastPageNo) = (1, 0);
  my ($url, $url_host, $savedFName) = ("", "http://www.caorenchao.com/", "Temp.htm");

  $url = $url_host;  $pageNo = 1;
  do {
    download_webpage($url, $savedFName);
    open(hFileHandle, $savedFName) || die "Cannot open file $savedFName!";
    while (<hFileHandle>) {
      die "500 Internal Error: Fail to download $url!\n" if (/500.+Internal Server Error/);

      if ($lastPageNo<1 && m!class=[\"\']pages[\"\']>!ig) {
        D($_);
        $lastPageNo = (m!class=[\"\']pages[\"\']>\d+/(\d+)!i) [0];
        P("Last Page is: $lastPageNo");    #exit 1;
      }

      next if (not m/<div class="post" id="post-\d+"/i);
      $articleId = (m/<div class="post" id="post-(\d+)"/i) [0];  P("articleId is $articleId");
      my $savedArticle = "./Articles/$articleId.htm";
      #last if (-e $savedArticle);
      next if (-e $savedArticle);  #hemerr

      $content = "";
      while (defined $_ && not m!/img/comments.gif!ig)  #break when reach the end of file
      {
        if (defined $_ && m/<img /i) {  #need download image
          my $imageUrl = (m!<img.+src="(http://\S+)"!ig) [0];   #D("imageUrl is: \t$imageUrl");
          my $imageFName = substr($imageUrl, rindex($imageUrl, '/')+1);  #D("imageFName is: \t$imageFName");
          my $imagePath = "";

          if ($imageUrl=~m/wp-content/i || $imageFName=~m/author.gif/i || $imageFName=~m/timeicon.gif/i || $imageFName=~m/comments.gif/i) {
            #do not download the image
          } else {
            $imageFName = "$articleId\_$imageFName";
            $imagePath = "./Articles/$imageFName";
            if (not -e $imagePath)   #hemerr
            {
              download_bin($imageUrl, $imagePath);
            }
            #change the content of image path
            #D($_);
            s!$imageUrl!$imageFName!ig;  #D($_);
          }
        } elsif (m/\<script /) {
          my $aLine = "";
          while (not m/<\/script>/i) {
            $aLine .= $_;
            $_ = <hFileHandle>;
          }
          $aLine .= $_;

          D("aLine before is: $aLine");
          $aLine =~ s!<script .*<\/script>!!isg;
          D("aLine after is: $aLine");
          $_ = $aLine;
        }

        $content .= $_;
        $_ = <hFileHandle>;   #$_="" if (!defined $_);
      }
      #P("break while $_") ;
      #D("Content is: $content");

      $content = sprintf("%s\n%s\n%s\n%s\n%s",
        '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">',
        '<html xmlns="http://www.w3.org/1999/xhtml">',
        '<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />',
        $content, "<p><p><p></html>");

      unlink $savedArticle if (-e $savedArticle);
      LOG_FILE($savedArticle, $FALSE, $content);
    }
    close(hFileHandle);

    $url = sprintf("%s/page/%d", $url_host, ++$pageNo);

  } while ($pageNo <= $lastPageNo);
}

sub Test02 {
  print "\@INC is @INC\n";
}

sub print_usage {
    print"\n";
    printf("*** Function SELECTOR ***\n");
    printf("* 1. TEST01             *\n");
    printf("* 2. TEST02             *\n");
    printf("*************************\n");

    printf("\nChoose An Option: ");
}
###############################################################################
parse_args(@ARGV);

if (1) {
    main();
} else {
    Test();
}



