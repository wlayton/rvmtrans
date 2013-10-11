#!/usr/bin/perl

##
# Invoke as `rvmtrans.pl <input file>`
#
# Uses the rvm authority file to automatically add translated
# fields for bilingual (English/French) subject access
#

use strict;
use MARC::Batch;
use MARC::Field;
use MARC::Charset 'marc8_to_utf8';
use DBI;
use Encode;

my $batch = MARC::Batch->new('USMARC', $ARGV[0]);
my $dbh = DBI->connect("dbi:mysql:dbname=rvm;", "rvm", "rvm")
    or die "Can't connect to RVM database";
$dbh->{'mysql_enable_utf8'} = 1;
$dbh->do('SET NAMES utf8');

my $out_filename = $ARGV[0];
$out_filename =~ s/\..*$//;

open(OUT, ">".$out_filename."_rvm_out.marc") or die $!;
binmode OUT, ":utf8";

# Cycle through each MARC bib record and add French subject headings
while (my $record = $batch->next()) {
    my @subjects = $record->field('65.');

    foreach my $subject (@subjects) {
        unless (($subject->indicator(2) == "0")
                || ($subject->indicator(2) == "5")) {
            next;
        }

        my @subfields = $subject->subfields();
        my $heading;
        my $heading2;
        my @divisions;
        my $divisions2;
        foreach my $subf (@subfields) {
            $heading .= "|".@$subf[0].@$subf[1];

            if (@$subf[0] =~ /[vz]/) {
                push @divisions, ["|".@$subf[0], @$subf[1]];
            } else {
                $heading2 .= "|".@$subf[0].@$subf[1];
            }
        }

        # Remove trailing period
        $heading =~ s/\.$//;
        #$heading =~ s/'/\\'\\'/;

        my $stmt = $dbh->prepare("select french.heading from rvm.french "
                                ."INNER JOIN english "
                                ."ON english.french = french.id "
                                ."WHERE english.thesaurus = '".$subject->indicator(2)."' "
                                ."AND english.tag = '750' "
                                ."AND english.heading = ?");

        $stmt->execute($heading);

        # If there is no exact match, there could still be a translation
        # with a topical term + geo/format subheadings
        if ($stmt->rows == 0) {

            $stmt = $dbh->prepare("select french.heading from rvm.french "
                                ."INNER JOIN english "
                                ."ON english.french = french.id "
                                ."WHERE english.thesaurus = '".$subject->indicator(2)."' "
                                ."AND english.tag = '750' "
                                ."AND english.heading = ?");

            $stmt->execute($heading2);
            
            if ($stmt->rows == 0) {
                next; #give up -- better luck with the next heading
            } else {
                foreach my $div (@divisions) {
                    @$div[1] =~ s/\.$//;

                    my $stmt2 = $dbh->prepare(
                        "SELECT substring(french.heading from 3) AS heading "
                       ."FROM rvm.french "
                       ."INNER JOIN rvm.english "
                       ."ON english.french = french.id "
                       ."WHERE english.thesaurus = '".$subject->indicator(2)."' "
                       ."AND english.heading = ?");

                    $stmt2->execute("|a".@$div[1]);

                    if ($stmt2->rows == 0) {
                        $divisions2 = '';
                        next; #if one lookup fails, whole entry fails
                    } else {
                        my $ref = $stmt2->fetchrow_hashref();
                        $divisions2 .= @$div[0].$ref->{'heading'};
                    }
                }
            }


            #print "Original:\n".$subject->as_formatted()."\n";
            #print "Translation: \n";
            while (my $ref = $stmt->fetchrow_hashref()) {
                my @new_subf;
                foreach my $nsf (split('\|', $ref->{'heading'}.$divisions2)) {

#                    $nsf = decode("UTF-8", $nsf);

                    if (length($nsf) > 0) {
                        push (@new_subf, substr($nsf,0,1), substr($nsf, 1));
                    }
                }

                my $nmf = MARC::Field->new($subject->tag(),
                            '', '6', @new_subf);
                
                $record->insert_grouped_field($nmf);
                #print $nmf->as_formatted()."\n";
            }
            #print "\n";
            
        } else {

            #print "Original:\n".$subject->as_formatted()."\n";
            #print "Translation: \n";
            while (my $ref = $stmt->fetchrow_hashref()) {
                my @new_subf;
                foreach my $nsf (split('\|', $ref->{'heading'})) {
                    
#                    $nsf = decode("UTF-8", $nsf);

                    if (length($nsf) > 0) {
                        push (@new_subf, substr($nsf,0,1), substr($nsf, 1));
                    }
                }
                my $nmf = MARC::Field->new($subject->tag(),
                            '', '6', @new_subf);

                $record->insert_grouped_field($nmf);
                #print $nmf->as_formatted()."\n";
            }
            #print "\n";
        }
        
    }

    print OUT $record->as_usmarc();
}

$dbh->disconnect();
close OUT;
