#!/usr/bin/perl

##
# Invoke as `rvmtrans.pl <input file>`
#
# Uses the rvm authority file to automatically add translated
# fields for bilingual (English/French) subject access
#

use strict;
use Getopt::Long;
use MARC::Batch;
use MARC::Field;
use MARC::Charset 'marc8_to_utf8';
use DBI;
use Encode;

my $opt_first = '';
my $opt_all = 1;
my $opt_prompt = '';
my $opt_ctrlfreak = '';
my $opt_debug = '';
my $opt_help = '';

GetOptions ('first' => \$opt_first,
            'all' => \$opt_all,
            'prompt' => \$opt_prompt,
            'ctrlfreak' => \$opt_ctrlfreak,
            'debug' => \$opt_debug,
            'help' => \$opt_help);


if ($opt_help) {
    print "rvmtrans.pl -- Add RVM translations of your LCSH and CSH subject headings.\n\n";
    print "Usage:\n";
    print "  rvmtrans.pl [--int] [--prompt] [--prompt] [--debug] [--help] file.marc\n\n";
    print "  Options:\n";
    print "\t--int : Interactive mode\n";
}

my $batch = MARC::Batch->new('USMARC', $ARGV[0]);
my $dbh = DBI->connect("dbi:mysql:dbname=rvm;", "rvm", "rvm")
    or die "Can't connect to RVM database";
$dbh->{'mysql_enable_utf8'} = 1;
$dbh->do('SET NAMES utf8');

my $out_filename = $ARGV[0];
$out_filename =~ s/\..*$//;

open(OUT, ">".$out_filename."_rvm_out.marc") or die $!;
open(MISSED, ">".$out_filename."_rvm_no_match.txt") or die $!;
binmode OUT, ":utf8";

# Cycle through each MARC bib record and add French subject headings
while (my $record = $batch->next()) {
    my @subjects = $record->field('65.');

    # RVM covers CSH (ind2 = 5) and LCSH (ind2 = 0)
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

            # Strip out |v (Form) and |z (Geographic) subheadings
            # Should I strip out |y (Chronological) as well?
            if (@$subf[0] =~ /[vz]/) {
                push @divisions, ["|".@$subf[0], @$subf[1]];
            } else {
                $heading2 .= "|".@$subf[0].@$subf[1];
            }
        }

        # Remove trailing period
        $heading =~ s/\.$//;

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
                print MISSED "=========================================\n";
                print MISSED "No Match for headings in bib record:\n";
                print MISSED "(TITLE)" . $record->field('245')->as_formatted() . "\n\n";
                print MISSED "Unmatched subjects:\n";
                foreach my $subject (@subjects) { 
                    print MISSED "\t" . $subject->as_formatted() . "\n";
                }

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

            insert_headings($stmt, $record, $subject, $divisions2);


            
        } else {

            insert_headings($stmt, $record, $subject);

        }
        
    }

    print OUT $record->as_usmarc();
}

$dbh->disconnect();
close OUT;
close MISSED;


sub insert_headings {
    my ($stmt, $record, $orig_subject, $divisions) = @_;


    if ($opt_debug || $opt_ctrlfreak) {
        print "============================================\n";
        print "Original:\n".$orig_subject->as_formatted()."\n";
        print "Translation: \n";
    }

    my $ref = $stmt->fetchrow_hashref();

    do {
        my @new_subf;
        foreach my $nsf (split('\|', $ref->{'heading'}.$divisions)) {

#                    $nsf = decode("UTF-8", $nsf);

            if (length($nsf) > 0) {
                push (@new_subf, substr($nsf,0,1), substr($nsf, 1));
            }
        }
        my $nmf = MARC::Field->new($orig_subject->tag(),
                '', '6', @new_subf);

        if ($opt_debug || $opt_ctrlfreak) {
            print $nmf->as_formatted()."\n";
        }
        if ($opt_ctrlfreak) {
            print "\nAdd translated headings to record?\n";
            print "([Y]es / [n]o / [s]top bugging me!)\n";
            my $answer = <STDIN>;
            $answer = lc(substr($answer, 0, 1));
            if ($answer eq 's') {
                $opt_ctrlfreak = '';
            }
            print "\n";
        }

        $record->insert_grouped_field($nmf);
    } while ($opt_all && !$opt_first && ($ref = $stmt->fetchrow_hashref()));


    if ($opt_debug || $opt_ctrlfreak) {
        print "============================================\n";
        print "\n";
    }
}


