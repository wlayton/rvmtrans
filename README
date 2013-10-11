RVM Subject Translator
======================

Two simple programs are included:

* rvm2loaddata.pl loads the RVM authority file (in MARC format) into a MySQL
  database.
    `rvm2loaddata.pl rvm_all.marc`
    (where "rvm_all.marc" is the full RVM file)

  This will create the following two files, which can be loaded into MySQL:
    * rvm_eng_load_data.txt
    * rvm_fre_load_data.txt
  
  See README.mysql for details on how to load the data into MySQL

* rvmtrans.pl takes a MARC file as input and looks up any subjects from the
  Library of Congress Subject Headings (LCSH) in the RVM database (created
  using the previous command). If it finds a match, it will insert the French
  translation of the subject heading in a new 650 field.
  
  Run as:
    rvmtrans.pl <original_marc_file>

  It will output to a separate MARC file, which is named like the original but
  has "_rvm_out" appended to the filename. For example:

    rvmtrans.pl sample_records.marc

  ...will output to sample_records_rvm_out.marc (leaving the original file
  untouched).

Disclaimer
----------

When I initially wrote these programs, it had been five years since I had
programmed anything in a professional capacity. Suggestions or patches
are welcome, especially if you know of a better way to do this.

The RVM authority file is distributed by Laval University. Please obtain a
license from them to obtain this file.

These programs, however, are not governed by the RVM license. Instead, they
are covered by the GNU General Public License, version 2 or later. This
means that you are free to share and change the programs as you wish.
Please see the COPYING file for further details.

Dependencies
------------
* Perl
* MySQL
* RVM authority file
