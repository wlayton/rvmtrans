#!/usr/bin/perl

##
# Invoke as `rvm2sql.pl <RVM MARC authority file>`
#
#

use strict;
use warnings;
use utf8;
use MARC::Batch;

my $batch = MARC::Batch->new('USMARC', $ARGV[0]);

open RVME,">rvm_eng_load_data.txt" or die "Can't open output file";
open RVMF,">rvm_fre_load_data.txt" or die "Can't open output file";
binmode STDOUT, ':utf8';
binmode RVME, ':utf8';
binmode RVMF, ':utf8';

my $id = 1;

while (my $record = $batch->next()) {

    $record->encoding('UTF-8');
 
    my $field = $record->field('1..');
    my @subfields = $field->subfields();
    my $fr_heading;
    
    foreach my $subfield (@subfields) {
        $fr_heading .= "|".@$subfield[0].@$subfield[1];
    }

    my @headings = $record->field('7..');

    if (((scalar @headings) == 0) || (!defined($fr_heading))) {
        next;
    }

    print RVMF "$id;".$field->tag().";$fr_heading\n";
    
    foreach my $heading (@headings) {
        if (defined($heading->subfield('a'))
                && ($heading->indicator(2) ne '7')) {

            @subfields = $heading->subfields();
            my $hd_sub;

            foreach my $subhdr (@subfields) {
                if (@$subhdr[0] =~/[a-zA-Z]/) {
                    $hd_sub .= "|".@$subhdr[0].@$subhdr[1];
                }
            }

            print RVME "$id;".$heading->indicator(2).";".$heading->tag().";$hd_sub\n";
        }
    }

    $id++;
}

close RVME;
close RVMF;
