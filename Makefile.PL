use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Hash::Merge',
    'VERSION_FROM'	=> 'Merge.pm', # finds $VERSION
    'PREREQ_PM'		=> { Test::More => 0.33 }, 
    ($] >= 5.005 ?   
      (ABSTRACT_FROM => 'Merge.pm', 
       AUTHOR     => 'Michael K. Neylon <mneylon-pm@masemware.com') : ()),
);
