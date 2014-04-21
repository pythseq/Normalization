#!/usr/bin/env perl

$USAGE = "\nUsage: runall_quantify_exons.pl <sample dir> <loc> <exons> <output sam?> [options]

where:
<sample dirs> is a file with the names of the sample directories
<loc> is the directory with the sample directories
<exons> is the name (with full path) of a file with exons, one per line as chr:start-end
<output sam?> is \"true\" or \"false\" depending on whether you want to output the
sam files of exon mappers, etc...

option:
 -NU-only

 -depth <n> : by default, it will output 20 exonmappers

 -se  :  set this if the data is single end, otherwise by default it will assume it's a paired end data 

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
$nuonly = 'false';
$pe = "true";
$i_exon = 20;

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
	$i_exon = $ARGV[$i+1];
	$i++;
	$option_found = "true";
    }
    if ($ARGV[$i] eq '-se'){
	$pe = "false";
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
	die "option \"$ARGV[$i]\" not recognized.\n";
    }
}
if($numargs ne '1'){
    die "you have to specify how you want to submit batch jobs. choose -lsf, -sge, or -other <submit> <jobname_option> <request_memory_option> <queue_name_for_4G>.\n";
}
if ($replace_mem eq "true"){
    $mem = $new_mem;
}


$path = abs_path($0);
$path =~ s/runall_//;

open(INFILE, $ARGV[0]) or die "cannot find file '$ARGV[0]'\n";
$LOC = $ARGV[1];
$LOC =~ s/\/$//;
$LOC =~ s/\/$//;
@fields = split("/", $LOC);
$study = $fields[@fields-2];
$last_dir = $fields[@fields-1];
$study_dir = $LOC;
$study_dir =~ s/$last_dir//;
$shdir = $study_dir . "shell_scripts";
$logdir = $study_dir . "logs";
unless (-d $shdir){
    `mkdir $shdir`;}
unless (-d $logdir){
    `mkdir $logdir`;}

$exons = $ARGV[2];
unless (-e $exons){
    die "ERROR: cannot find file $exons \n";} 
$outputsam = $ARGV[3];
while($line = <INFILE>) {
    chomp($line);
    $dir = $line;
    $id = $line;
    $id =~ s/Sample_//;
    if($outputsam eq "true"){
	$filename = "$id.filtered.sam";
	if ($nuonly eq "true"){
	    $filename =~ s/.sam$/_nu.sam/;
	    $dir = $dir . "/NU";
	}
	if ($nuonly eq "false"){
	    $filename =~ s/.sam$/_u.sam/;
	    $dir = $dir . "/Unique";
	}
    }
    if($outputsam eq "false"){
	$filename = "$id.exonmappers.norm.sam";
	@fields = split("/", $LOC);
	$last_dir = $fields[@fields-1];
	$norm_dir = $LOC;
	$norm_dir =~ s/$last_dir//;
	$norm_dir = $norm_dir . "NORMALIZED_DATA";
	$exon_dir = $norm_dir . "/exonmappers";
	$merged_exon_dir = $exon_dir . "/MERGED";
	$unique_exon_dir = $exon_dir . "/Unique";
	$nu_exon_dir = $exon_dir . "/NU";
	if ($nuonly eq "false"){
	    if (-d $merged_exon_dir){
		$final_exon_dir = $merged_exon_dir;
	    }	
	    else{
		if (-d $unique_exon_dir){
		    $final_exon_dir = $unique_exon_dir;
		    $filename =~ s/.sam$/_u.sam/;
		}
		else {
		    $filename = "$id.filtered.sam";
		    $filename =~ s/.sam$/_u.sam/;
		    $final_exon_dir = "$LOC/$dir/Unique";
		}
	    }
	}
	if ($nuonly eq "true"){
	    if (-d $nu_exon_dir){
		$final_exon_dir = $nu_exon_dir;
		$filename =~ s/.sam$/_nu.sam/;
	    }
	    else{
		$filename = "$id.filtered.sam";
                $filename =~ s/.sam$/_nu.sam/;
		$final_exon_dir = "$LOC/$dir/NU";
	    }
	}
    }

    $shfile = "EQ" . $filename . ".sh";
    $shfile2 = "EQ" . $filename . ".2.sh";
    $jobname = "$study.quantifyexons";
    $jobname2 = "$study.quantifyexons2";
    $logname = "$logdir/quantifyexons.$id";
    $logname2 = "$logdir/quantifyexons2.$id";
    $outfile = $filename;
    $outfile =~ s/.sam/_exonquants/;
    $exonsamoutfile = $filename;
    $exonsamoutfile =~ s/.sam/_exonmappers.sam/;
    $intronsamoutfile = $filename;
    $intronsamoutfile =~ s/.sam/_notexonmappers.sam/;
    if($outputsam eq "true") {
	open(OUTFILE, ">$shdir/$shfile");
		if($nuonly eq 'false') {
		    if ($pe eq "true"){
			print OUTFILE "perl $path $exons $LOC/$dir/$filename $LOC/$dir/$outfile $LOC/$dir/$exonsamoutfile $LOC/$dir/$intronsamoutfile -depth $i_exon\n";
		    }
		    else {
			print OUTFILE "perl $path $exons $LOC/$dir/$filename $LOC/$dir/$outfile $LOC/$dir/$exonsamoutfile $LOC/$dir/$intronsamoutfile -rpf -depth $i_exon\n";
		    }
		} else {
		    if ($pe eq "true"){
			print OUTFILE "perl $path $exons $LOC/$dir/$filename $LOC/$dir/$outfile $LOC/$dir/$exonsamoutfile $LOC/$dir/$intronsamoutfile -NU-only -depth $i_exon\n";
		    }
		    else{
			print OUTFILE "perl $path $exons $LOC/$dir/$filename $LOC/$dir/$outfile $LOC/$dir/$exonsamoutfile $LOC/$dir/$intronsamoutfile -NU-only -rpf -depth $i_exon\n";
		    }
		}
    } 
    else {
	open(OUTFILE, ">$shdir/$shfile2");
	if($nuonly eq 'false') {
	    if ($pe eq "true"){
		print OUTFILE "perl $path $exons $final_exon_dir/$filename $final_exon_dir/$outfile none none\n";
	    }
	    else {
		print OUTFILE "perl $path $exons $final_exon_dir/$filename $final_exon_dir/$outfile none none -rpf\n";
	    }
	}
	else{
	    if ($pe eq "true"){
		print OUTFILE "perl $path $exons $final_exon_dir/$filename $final_exon_dir/$outfile none none -NU-only\n";
	    }
	    else{
		print OUTFILE "perl $path $exons $final_exon_dir/$filename $final_exon_dir/$outfile none none -NU-only -rpf\n";
	    }
	}
    }
    close(OUTFILE);
    if($outputsam eq "true") {
	`$submit $jobname_option $jobname $request_memory_option$mem -o $logname.out -e $logname.err < $shdir/$shfile`;
    }
    if($outputsam eq "false") {
	`$submit $jobname_option $jobname2 $request_memory_option$mem -o $logname2.out -e $logname2.err < $shdir/$shfile2`;
    }
}
close(INFILE);
