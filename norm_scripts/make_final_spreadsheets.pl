#!/usr/bin/env perl

$USAGE = "\nUsage: perl make_final_spreadsheets.pl <sample dirs> <loc> [options]

where:
<sample dirs> is the name of a file with the names of the sample directories (no paths)
<loc> is the path to the sample directories.

options:
 -u  :  set this if you want to return only unique, otherwise by default
         it will use merged files and return min and max files.

 -nu :  set this if you want to return only non-unique, otherwise by default
         it will use merged files and return min and max files.

 -lsf : set this if you want to submit batch jobs to LSF (PMACS cluster).

 -sge : set this if you want to submit batch jobs to Sun Grid Engine (PGFI cluster).

 -other <submit> <jobname_option> <request_memory_option> <queue_name_for_6G> <queue_name_for_10G>:
        set this if you're not on LSF (PMACS) or SGE (PGFI) cluster.

        <submit> : is command for submitting batch jobs from current working directory (e.g. bsub, qsub -cwd)
        <jobname_option> : is option for setting jobname for batch job submission command (e.g. -J, -N)
        <request_memory_option> : is option for requesting resources for batch job submission command
                                  (e.g. -q, -l h_vmem=)
        <queue_name_for_6G> : is queue name for 6G (e.g. plus, 6G)
        <queue_name_for_10G> : is queue name for 10G (e.g. max_mem30, 10G)

 -mem <s> : set this if your job requires more memory. this will replace queue name of both 6G and 10G
            <s> is the queue name for required mem.
            Default: 6G, 10G

 -h : print usage

";
if(@ARGV<2) {
    die $USAGE;
}

$U = "true";
$NU = "true";
$numargs = 0;

$numargs_c = 0;
$replace_mem = "false";
$submit = "";
$jobname_option = "";
$request_memory_option = "";
$mem6 = "";
$mem10 = "";
for($i=2; $i<@ARGV; $i++) {
    $option_found = "false";
    if($ARGV[$i] eq '-nu') {
        $U = "false";
	$numargs++;
        $option_found = "true";
    }
    if($ARGV[$i] eq '-u') {
        $NU = "false";
        $numargs++;
        $option_found = "true";
    }
    if ($ARGV[$i] eq '-lsf'){
        $numargs_c++;
        $option_found = "true";
        $submit = "bsub";
        $jobname_option = "-J";
        $request_memory_option = "-q";
        $mem6 = "plus";
	$mem10 = "max_mem30";
    }
    if ($ARGV[$i] eq '-sge'){
        $numargs_c++;
        $option_found = "true";
        $submit = "qsub -cwd";
	$jobname_option = "-N";
        $request_memory_option = "-l h_vmem=";
        $mem6 = "6G";
	$mem10 = "10G";
    }
    if ($ARGV[$i] eq '-h'){
        $option_found = "true";
	die $USAGE;
    }
    if ($ARGV[$i] eq '-other'){
        $numargs_c++;
        $option_found = "true";
        $submit = $ARGV[$i+1];
        $jobname_option = $ARGV[$i+2];
        $request_memory_option = $ARGV[$i+3];
        $mem6 = $ARGV[$i+4];
	$mem10 = $ARGV[$i+5];
        $i++;
        $i++;
        $i++;
        $i++;
	$i++;
        if ($submit eq "-mem" | $submit eq "" | $jobname_option eq "" | $request_memory_option eq "" | $mem6 eq "" | $mem10 eq ""){
            die "please provide <submit>, <jobname_option>, and <request_memory_option> <queue_name_for_6G> <queue_name_for_10G>\n";
        }
        if ($submit eq "-lsf" | $submit eq "-sge"){
	    die "you have to specify how you want to submit batch jobs. choose -lsf, -sge, or -other <submit> <jobname_option> <request_memory_option> <queue_name_for_6G> <queue_name_for_10G>.\n";
        }
    }
    if ($ARGV[$i] eq '-mem'){
        $option_found = "true";
        $new_mem = $ARGV[$i+1];
        $replace_mem = "true";
        $i++;
        if ($new_mem eq ""){
            die "please provide a queue name.\n";
        }
    }
    if($option_found eq "false") {
        die "option \"$ARGV[$i]\" was not recognized.\n";
    }
}
if($numargs > 1) {
    die "you cannot specify both -u and -nu, it will use merged files and return min and max files by default so if that's what you want don't use either arg -u or -nu.
";
}
if($numargs_c ne '1'){
    die "you have to specify how you want to submit batch jobs. choose -lsf, -sge, or -other <submit> <jobname_option> <reque\
st_memory_option> <queue_name_for_6G> <queue_name_for_10G>.\n";
}
if ($replace_mem eq "true"){
    $mem6 = $new_mem;
    $mem10 = $new_mem;
}

use Cwd 'abs_path';
$path = abs_path($0);
$path =~ s/\/make_final_spreadsheets.pl//;
$LOC = $ARGV[1];
$LOC =~ s/\/$//;
@fields = split("/", $LOC);
$last_dir = $fields[@fields-1];
$study = $fields[@fields-2];
$study_dir = $LOC;
$study_dir =~ s/$last_dir//;
$shdir = $study_dir . "shell_scripts";
$logdir = $study_dir . "logs";
unless (-d $shdir){
    `mkdir $shdir`;}
unless (-d $logdir){
    `mkdir $logdir`;}
$norm_dir = $study_dir . "NORMALIZED_DATA";
$spread_dir = $norm_dir . "/SPREADSHEETS";
unless (-d $spread_dir){
    `mkdir $spread_dir`;
}
$FILE = $ARGV[0];

if ($numargs eq "0"){
    $sh_exon = "$shdir/exonquants2spreadsheet_min_max.sh";
    open(OUTexon, ">$sh_exon");
    print OUTexon "perl $path/quants2spreadsheet_min_max.pl $FILE $LOC exonquants";
    close(OUTexon);
    $sh_intron = "$shdir/intronquants2spreadsheet_min_max.sh";
    open(OUTintron, ">$sh_intron");
    print OUTintron "perl $path/quants2spreadsheet_min_max.pl $FILE $LOC intronquants";
    close(OUTintron);
    $sh_junctions = "$shdir/juncs2spreadsheet_min_max.sh";
    open(OUTjunctions, ">$sh_junctions");
    print OUTjunctions "perl $path/juncs2spreadsheet_min_max.pl $FILE $LOC";
    close(OUTjunctions);
    $jobname = "$study.final_spreadsheet";
    $lognameE = "$logdir/exonquants2spreadsheet_min_max";
    $lognameI = "$logdir/intronquants2spreadsheet_min_max";
    $lognameJ = "$logdir/juncs2spreadsheet_min_max";
    `$submit $jobname_option $jobname $request_memory_option$mem10 -o $lognameE.out -e $lognameE.err < $sh_exon`;
    `$submit $jobname_option $jobname $request_memory_option$mem10 -o $lognameI.out -e $lognameI.err < $sh_intron`;
    `$submit $jobname_option $jobname $request_memory_option$mem6 -o $lognameJ.out -e $lognameJ.err < $sh_junctions`;
}
else{
    if ($U eq "true"){
	$sh_exon = "$shdir/exonquants2spreadsheet.u.sh";
	open(OUTexon, ">$sh_exon");
	print OUTexon "perl $path/quants2spreadsheet.1.pl $FILE $LOC exonquants";
	close(OUTexon);
	$sh_intron = "$shdir/intronquants2spreadsheet.u.sh";
	open(OUTintron, ">$sh_intron");
	print OUTintron "perl $path/quants2spreadsheet.1.pl $FILE $LOC intronquants";
	close(OUTintron);
	$sh_junctions = "$shdir/juncs2spreadsheet.u.sh";
	open(OUTjunctions, ">$sh_junctions");
	print OUTjunctions "perl $path/juncs2spreadsheet.1.pl $FILE $LOC";
	close(OUTjunctions);
	$jobname = "$study.final_spreadsheet";
	$lognameE ="$logdir/exonquants2spreadsheet.u";
	$lognameI ="$logdir/intronquants2spreadsheet.u";
	$lognameJ ="$logdir/juncs2spreadsheet.u";
	`$submit $jobname_option $jobname $request_memory_option$mem10 -o $lognameE.out -e $lognameE.err < $sh_exon`;
	`$submit $jobname_option $jobname $request_memory_option$mem10 -o $lognameI.out -e $lognameI.err < $sh_intron`;
	`$submit $jobname_option $jobname $request_memory_option$mem6 -o $lognameJ.out -e $lognameJ.err < $sh_junctions`;
    }
    if ($NU eq "true"){
        $sh_exon = "$shdir/exonquants2spreadsheet.nu.sh";
        open(OUTexon, ">$sh_exon");
        print OUTexon "perl $path/quants2spreadsheet.1.pl $FILE $LOC exonquants -NU";
        close(OUTexon);
        $sh_intron = "$shdir/intronquants2spreadsheet.nu.sh";
        open(OUTintron, ">$sh_intron");
        print OUTintron "perl $path/quants2spreadsheet.1.pl $FILE $LOC intronquants -NU";
        close(OUTintron);
        $sh_junctions = "$shdir/juncs2spreadsheet.nu.sh";
        open(OUTjunctions, ">$sh_junctions");
        print OUTjunctions "perl $path/juncs2spreadsheet.1.pl $FILE $LOC -NU";
        close(OUTjunctions);
        $jobname = "$study.final_spreadsheet";
        $lognameE ="$logdir/exonquants2spreadsheet.nu";
        $lognameI ="$logdir/intronquants2spreadsheet.nu";
        $lognameJ ="$logdir/juncs2spreadsheet.nu";
        `$submit $jobname_option $jobname $request_memory_option$mem10 -o $lognameE.out -e $lognameE.err < $sh_exon`;
        `$submit $jobname_option $jobname $request_memory_option$mem10 -o $lognameI.out -e $lognameI.err < $sh_intron`;
        `$submit $jobname_option $jobname $request_memory_option$mem6 -o $lognameJ.out -e $lognameJ.err < $sh_junctions`;
    }
}
