#!/usr/bin/env perl

$USAGE =  "\nUsage: runall_quantify_introns.pl <sample dirs> <loc> <introns> <output sam?> [options]

where:
<sample dirs> is the name of a file with the names of the sample directories (no paths)
<loc> is the path to the dir with the sample dirs
<introns> is the name (with full path) of a file with introns, one per line as chr:start-end
<output sam?> = true if you want it to output two sam files, one of things that map to introns 
 
option:
 -NU-only

 -depth <n> : by default, it will output 10 intronmappers

 -lsf : set this if you want to submit batch jobs to LSF (PMACS cluster).

 -sge : set this if you want to submit batch jobs to Sun Grid Engine (PGFI cluster).

 -other <submit> <jobname_option> <request_memory_option> <queue_name_for_4G>:
        set this if you're not on LSF (PMACS) or SGE (PGFI) cluster.

        <submit> : is command for submitting batch jobs from current working directory (e.g. bsub, qsub -cwd)
        <jobname_option> : is option for setting jobname for batch job submission command (e.g. -J, -N)
        <request_memory_option> : is option for requesting resources for batch job submission command
                                  (e.g. -q, -l h_vmem=)
        <queue_name_for_4G> : is queue name for 4G (e.g. plus, 4G)

 -mem <s> : set this if your job requires more memory.
            <s> is the queue name for required mem.
            Default: 4G

 -h : print usage
 
";

if(@ARGV<4) {
    die $USAGE;
}

use Cwd 'abs_path';
$path = abs_path($0);
$path =~ s/runall_//;

$nuonly = 'false';
$i_intron = 10;

$replace_mem = "false";
$submit = "";
$jobname_option = "";
$request_memory_option = "";
$mem = "";
$numargs = 0;
for($i=4; $i<@ARGV; $i++) {
    $option_found = 'false';
    if($ARGV[$i] eq '-NU-only') {
        $nuonly = 'true';
        $option_found = 'true';
    }
    if ($ARGV[$i] eq '-depth'){
	$i_intron = $ARGV[$i+1];
	$i++;
	$option_found = "true";
    }
    if ($ARGV[$i] eq '-h'){
        $option_found = "true";
	die $USAGE;
    }
    if ($ARGV[$i] eq '-lsf'){
        $numargs++;
        $option_found = "true";
        $submit = "bsub";
        $jobname_option = "-J";
        $request_memory_option = "-q";
        $mem = "plus";
    }
    if ($ARGV[$i] eq '-sge'){
	$numargs++;
        $option_found = "true";
        $submit = "qsub -cwd";
	$jobname_option = "-N";
        $request_memory_option = "-l h_vmem=";
        $mem = "4G";
    }
    if ($ARGV[$i] eq '-other'){
        $numargs++;
        $option_found = "true";
        $submit = $ARGV[$i+1];
        $jobname_option = $ARGV[$i+2];
        $request_memory_option = $ARGV[$i+3];
        $mem = $ARGV[$i+4];
        $i++;
        $i++;
        $i++;
        $i++;
        if ($submit eq "-mem" | $submit eq "" | $jobname_option eq "" | $request_memory_option eq "" | $mem eq ""){
	    die "please provide <submit>, <jobname_option>, and <request_memory_option> <queue_name_for_4G>\n";
        }
        if ($submit eq "-lsf" | $submit eq "-sge"){
	    die "you have to specify how you want to submit batch jobs. choose -lsf, -sge, or -other <submit> <jobname_option> <request_memory_option> <queue_name_for_4G>.\n";
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
    if($option_found eq 'false') {
        die "arg \"$ARGV[$i]\" not recognized.\n";
    }
}
if($numargs ne '1'){
    die "you have to specify how you want to submit batch jobs. choose -lsf, -sge, or -other <submit> <jobname_option> <request_memory_option> <queue_name_for_4G>.\n";
}
if ($replace_mem eq "true"){
    $mem = $new_mem;
}


open(INFILE, $ARGV[0]) or die "cannot find file '$ARGV[0]'\n";
$LOC = $ARGV[1];
$LOC =~ s/\/$//;
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

$introns = $ARGV[2];
$outputsam = $ARGV[3];
while($line = <INFILE>) {
    chomp($line);
    $dir = $line;
    $id = $line;
    $id =~ s/Sample_//;
    if($outputsam eq "true"){
	$filename = "$id.filtered_u_notexonmappers.sam";
	if ($nuonly eq "true"){
	    $filename =~ s/u_notexonmappers.sam$/nu_notexonmappers.sam/;
	    $dir = $dir . "/NU";
	}
	if ($nuonly eq "false"){
	    $dir = $dir . "/Unique";
	}
    }
    if($outputsam eq "false"){
	$filename = "$id.intronmappers.norm_u.sam";
	@fields = split("/", $LOC);
        $last_dir = $fields[@fields-1];
        $norm_dir = $LOC;
        $norm_dir =~ s/$last_dir//;
        $norm_dir = $norm_dir . "NORMALIZED_DATA";
        $nexon_dir = $norm_dir . "/notexonmappers";
        $unique_nexon_dir = $nexon_dir . "/Unique";
        $nu_nexon_dir = $nexon_dir . "/NU";
	$final_nexon_dir = $unique_nexon_dir;
	if ($nuonly eq "true"){
	    $filename =~ s/norm_u.sam$/norm_nu.sam/;
	    $final_nexon_dir = $nu_nexon_dir;
	}
    }

    $shfile = "IQ" . $filename . ".sh";
    $shfile2 = "IQ" . $filename . ".2.sh";
    $jobname = "$study.quantifyintrons";
    $jobname2 = "$study.quantifyintrons2";
    $logname = "$logdir/quantifyintrons.$id";
    $logname2 = "$logdir/quantifyintrons2.$id";
    $outfile = $filename;
    $outfile =~ s/.sam/_intronquants/;
    if($outputsam eq "true") {
	open(OUTFILE, ">$shdir/$shfile");
	print OUTFILE "perl $path $introns $LOC/$dir/$filename $LOC/$dir/$outfile true -depth $i_intron\n";
	close(OUTFILE);
    } 
    else {
	open(OUTFILE, ">$shdir/$shfile2");
	print OUTFILE "perl $path $introns $final_nexon_dir/$filename $final_nexon_dir/$outfile false\n";
	close(OUTFILE);
    }
    if($outputsam eq "true") {
        `$submit $jobname_option $jobname $request_memory_option$mem -o $logname.out -e $logname.err < $shdir/$shfile`;
    }
    if ($outputsam eq "false") {
        `$submit $jobname_option $jobname2 $request_memory_option$mem -o $logname2.out -e $logname2.err < $shdir/$shfile2`;
    }
}
close(INFILE);
