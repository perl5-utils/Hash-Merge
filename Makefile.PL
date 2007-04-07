use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'		   => 'Hash::Merge',
    'VERSION_FROM' => 'Merge.pm', 
    'PREREQ_PM'	   => { 
        'Test::More' => 0.33,
        'Clone'      => 0, # still require it here, just not when using the module without clone on
    }, 
    ($] >= 5.005 ?   
      (ABSTRACT_FROM => 'Merge.pm', 
       AUTHOR     => 'Michael K. Neylon <mneylon-pm@masemware.com') : ()),
);
