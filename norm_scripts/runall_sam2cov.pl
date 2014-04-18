if (@ARGV<4){
  $USAGE = "\nUsage: runall_sam2cov.pl <sample dirs> <loc> <fai file> <sam2cov> [options]

<sample dirs> is  a file of sample directories with alignment output without path
<loc> is where the sample directories are
<fai file> fai file (full path)
<sam2cov> is full path of sam2cov

***Sam files produced by aligners other than STAR and RUM are currently not supported***

option:  
 -u  :  set this if you want to use only unique mappers to generate coverage files, 
        otherwise by default it will use merged(unique+non-unique) mappers.

 -nu  :  set this if you want to use only non-unique mappers to generate coverage files,
         otherwise by default it will use merged(unique+non-unique) mappers.

 -rum  :  set this if you used RUM to align your reads 

 -star  : set this if you used STAR to align your reads 

 -pmacs : set this if you want to submit batch jobs to PMACS cluster (LSF).

 -pgfi : set this if you want to submit batch jobs to PGFI cluster (Sun Grid Engine).

 -other <submit> <jobname_option> <request_memory_option> <queue_name_for_15G>:
        set this if you're not on PMACS (LSF) or PGFI (SGE) cluster.

        <submit> : is command for submitting batch jobs from current working directory (e.g. bsub, qsub -cwd)
        <jobname_option> : is option for setting jobname for batch job submission command (e.g. -J, -N)
        <request_memory_option> : is option for requesting resources for batch job submission command
                                  (e.g. -q, -l h_vmem=)
        <queue_name_for_15G> : is queue name for 15G (e.g. max_mem30, 15G)

 -mem <s> : set this if your job requires more memory.
            <s> is the queue name for required mem.
            Default: 15G

 -h : print usage

";
  die $USAGE;
}
$numargs_a = 0;
$numargs_u_nu = 0;
$U = "true";
$NU = "true";
$star = "false";
$rum = "false";

$replace_mem = "false";
$numargs = 0;
$submit = "";
$jobname_option = "";
$request_memory_option = "";
$mem = "";
$help = "false";
for ($i=4; $i<@ARGV; $i++){
    $option_found = "false";
    if($ARGV[$i] eq '-nu') {
        $U = "false";
	$numargs_u_nu++;
        $option_found = "true";
    }
    if($ARGV[$i] eq '-u') {
        $NU = "false";
        $numargs_u_nu++;
        $option_found = "true";
    }
    if ($ARGV[$i] eq '-star'){
        $star = "true";
        $numargs_a++;
        $option_found = "true";
    }
    if ($ARGV[$i] eq '-rum'){
        $rum = "true";
        $numargs_a++;
        $option_found = "true";
    }
    if ($ARGV[$i] eq '-h'){
        $option_found = "true";
        $help = "true";
    }
    if ($ARGV[$i] eq '-pmacs'){
        $numargs++;
        $option_found = "true";
        $submit = "bsub";
        $jobname_option = "-J";
	$request_memory_option = "-q";
        $mem = "max_mem30";
    }
    if ($ARGV[$i] eq '-pgfi'){
        $numargs++;
        $option_found = "true";
        $submit = "qsub -cwd";
        $jobname_option = "-N";
        $request_memory_option = "-l h_vmem=";
        $mem = "15G";
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
            die "please provide <submit>, <jobname_option>, and <request_memory_option> <queue_name_for_15G>\n";
        }
        if ($submit eq "-pmacs" | $submit eq "-pgfi"){
            die "you have to specify how you want to submit batch jobs. choose -pmacs, -pgfi, or -other <submit> <jobname_option> <request_memory_option> <queue_name_for_15G>.\n";
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
    if ($option_found eq "false"){
	die "option \"$ARGV[$i]\" was not recognized.\n";
    }
}
if ($help eq 'true'){
    die $USAGE;
}

if($numargs ne '1'){
    die "you have to specify how you want to submit batch jobs. choose -pmacs, -pgfi, or -other <submit> <jobname_option> <request_memory_option> <queue_name_for_15\
G>.\n
";
}

if ($replace_mem eq "true"){
    $mem = $new_mem;
}

if($numargs_u_nu > 1) {
    die "you cannot specify both -u and -nu\n.
";
}
if($numargs_a ne '1'){
    die "you have to specify which aligner was used to align your reads. sam2cov only works with sam files aligned with STAR or RUM\n
";
}


$LOC = $ARGV[1];
$LOC =~ s/\/$//;
@fields = split("/", $LOC);
$last_dir = $fields[@fields-1];
$study = $fields[@fields-2];
$study_dir = $LOC;
$study_dir =~ s/$last_dir//;
$shdir = $study_dir . "shell_scripts";
$logdir = $study_dir . "logs";
$norm_dir = $study_dir . "NORMALIZED_DATA";
$cov_dir = $norm_dir . "/COV";
unless (-d $cov_dir){
    `mkdir $cov_dir`;
}
$finalsam_dir = "$norm_dir/FINAL_SAM";
$final_U_dir = "$finalsam_dir/Unique";
$final_NU_dir = "$finalsam_dir/NU";
$final_M_dir = "$finalsam_dir/MERGED";
$fai_file = $ARGV[2]; # fai file
$sam2cov = $ARGV[3];

open(INFILE, $ARGV[0]) or die "cannot find file '$ARGV[0]'\n"; # dirnames
while($line =  <INFILE>){
    chomp($line);
    $dir = $line;
    $id = $dir;
    $id =~ s/Sample_//;
    if ($numargs_u_nu eq '0'){
	$filename = "$final_M_dir/$id.FINAL.norm.sam";
	unless (-d "$cov_dir/MERGED"){
	    `mkdir "$cov_dir/MERGED"`;
	}
	$prefix = "$cov_dir/MERGED/$id.FINAL.norm.sam";
	$prefix =~ s/norm.sam//;
    }
    else {
	if ($U eq 'true'){
	    $filename = "$final_U_dir/$id.FINAL.norm_u.sam";
	    unless (-d "$cov_dir/Unique"){
		`mkdir "$cov_dir/Unique"`;
	    }
	    $prefix = "$cov_dir/Unique/$id.FINAL.norm_u.sam";
	    $prefix =~ s/norm_u.sam//;
	}
	if ($NU eq 'true'){
	    $filename = "$final_NU_dir/$id.FINAL.norm_nu.sam";
	    unless (-d "$cov_dir/NU"){
		`mkdir "$cov_dir/NU"`;
	    }
	    $prefix = "$cov_dir/NU/$id.FINAL.norm_nu.sam";
	    $prefix =~ s/norm_nu.sam//;
	}
    }
    $shfile = "C.$id.sam2cov.sh";
    $jobname = "$study.sam2cov";
    $logname = "$logdir/sam2cov.$id";
    open(OUTFILE, ">$shdir/$shfile");
    if ($rum eq 'true'){
	print OUTFILE "$sam2cov -r 1 -e 0 -u -p $prefix $fai_file $filename"; 
    }
    if ($star eq 'true'){
	print OUTFILE "$sam2cov -u -e 0 -p $prefix $fai_file $filename"; 
    }
    close(OUTFILE);
    `$submit $jobname_option $jobname $request_memory_option$mem -o $logname.out -e $logname.err < $shdir/$shfile`;
}
close(INFILE);

