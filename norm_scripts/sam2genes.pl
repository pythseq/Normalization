use strict;
use warnings;

my $USAGE = "perl sam2genes.pl <samfile> <ensGene file> <outfile>

";

if (@ARGV < 3){
    die $USAGE;
}

my $samfile = $ARGV[0];
my $ens_file = $ARGV[1];
my $outfile = $ARGV[2];
my (%txHASH, %exSTARTS, %exENDS, %geneHASH, %geneSYMBOL);

open(ENS, $ens_file) or die "cannot find file \"$ens_file\"\n";
my $header = <ENS>;
chomp($header);
my @ENSHEADER = split(/\t/, $header);
my ($txnamecol, $txchrcol, $txstartcol, $txendcol, $exstartscol, $exendscol, $genenamecol, $genesymbolcol);
for(my $i=0; $i<@ENSHEADER; $i++){
    if ($ENSHEADER[$i] =~ /.name$/){
	$txnamecol = $i;
    }
    if ($ENSHEADER[$i] =~ /.chrom$/){
	$txchrcol = $i;
    }
    if ($ENSHEADER[$i] =~ /.txStart$/){
	$txstartcol = $i;
    }
    if ($ENSHEADER[$i] =~ /.txEnd$/){
	$txendcol = $i;
    }
    if ($ENSHEADER[$i] =~ /.exonStarts$/){
        $exstartscol = $i;
    }
    if ($ENSHEADER[$i] =~ /.exonEnds$/){
        $exendscol = $i;
    }
    if ($ENSHEADER[$i] =~ /.name2$/){
        $genenamecol = $i;
    }
    if ($ENSHEADER[$i] =~ /.ensemblToGeneName.value$/){
	$genesymbolcol = $i;
    }
}

if (!defined($txnamecol) || !defined($txchrcol) || !defined($txstartcol) || !defined($txendcol) || !defined($exstartscol) || !defined($exendscol) || !defined($genenamecol) || !defined($genesymbolcol)){
    die "Your header must contain columns with the following suffixes: name, chrom, txStart, txEnd, exonStarts, exonEnds, name2, ensemblToGeneName.value\n";
}

while(my $line = <ENS>){
    chomp($line);
    my @a = split(/\t/, $line);
    my $tx_id = $a[$txnamecol];
    my $tx_chr = $a[$txchrcol];
    my $tx_start_loc = $a[$txstartcol] + 1;
    my $tx_end_loc = $a[$txendcol];
    my $tx_exonStarts = $a[$exstartscol];
    my $tx_exonEnds = $a[$exendscol];
    my $gene_id = $a[$genenamecol];
    my $gene_symbol = $a[$genesymbolcol];
    #index by chr and first 1-3 digits of txStart and txEnd
    my $index_st = int($tx_start_loc/1000000);
    my $index_end = int($tx_end_loc/1000000);
    for (my $index = $index_st; $index <= $index_end; $index++){
	push (@{$txHASH{$tx_chr}[$index]}, $tx_id);
    }
    #exStarts and exEnds into HASH
    my @tx_starts = split(",", $tx_exonStarts);
    for (my $i = 0; $i<@tx_starts; $i++){
	$tx_starts[$i] = $tx_starts[$i] + 1;
    }
    my @tx_ends = split(",", $tx_exonEnds);
    $exSTARTS{$tx_id} = \@tx_starts;
    $exENDS{$tx_id} = \@tx_ends;
    #genehash with tx_id as key
    $geneHASH{$tx_id} = $gene_id;
    $geneSYMBOL{$gene_id} = $gene_symbol;
}
close(ENS);

open(SAM, $samfile) or die "cannot fine file \"$samfile\"\n";
open(OUT, ">$outfile");
print OUT "readID\ttranscriptIDs\tgeneIDs\tgeneSymbols\tIndex\n";
while(my $line = <SAM>){
    chomp($line);
    if ($line =~ /^@/){
	next;
    }
    $line =~ /HI:i:(\d+)/;
    my $a_index = $1;
    my @readStarts = ();
    my @readEnds = ();
    my $txID_list = "";
    my @a = split(/\t/, $line);
    my $read_id = $a[0];
    my $flag = $a[1];
    my $chr = $a[2];
    my $readSt = $a[3];
    my $index = int($readSt/1000000);
    my $cigar = $a[5];
    my $spans = &cigar2spans($readSt, $cigar);
    my @b = split (",", $spans);
    for (my $i=0; $i<@b; $i++){
	my @c = split("-", $b[$i]);
	my $read_st = $c[0];
	$read_st =~ s/^\s*(.*?)\s*$/$1/;
	my $read_end = $c[1];
	$read_end =~ s/^\s*(.*?)\s*$/$1/;
	push (@readStarts, $read_st);
	push (@readEnds, $read_end);
    }
    if (exists $txHASH{$chr}[$index]){
	my $hashsize = @{$txHASH{$chr}[$index]};
	for (my $j=0; $j<$hashsize; $j++){
	    my $tx_id = $txHASH{$chr}[$index][$j];
	    my $check = &checkCompatibility($chr, $exSTARTS{$tx_id}, $exENDS{$tx_id}, $chr, \@readStarts, \@readEnds);
	    if ($check eq "1"){
		$txID_list = $txID_list . "$tx_id,";
	    }
	}
    }
    my @geneIDs = ();
    my @ids = split(",", $txID_list);
    for(my $i=0; $i<@ids; $i++){
	push (@geneIDs, $geneHASH{$ids[$i]});
    }
    my @unique_gene_ids = &uniq(@geneIDs);
    my $array_size = @unique_gene_ids;
    my $geneID_list = "";
    my $symbol_list = "";
    if ($array_size == 1){
	$geneID_list = $unique_gene_ids[0];
	$symbol_list = $geneSYMBOL{$unique_gene_ids[0]};
    }
    elsif ($array_size > 1){
	for(my $i=0; $i<$array_size;$i++){
	    $geneID_list = $geneID_list . "$unique_gene_ids[$i],";
	    $symbol_list = $symbol_list . "$geneSYMBOL{$unique_gene_ids[$i]},";
	}
    }
    print OUT "$read_id\t$txID_list\t$geneID_list\t$symbol_list\t$a_index\n";
}
close(SAM);
close(OUT);
print "got here\n";
sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}

sub cigar2spans {
    my ($start, $matchstring) = @_;
    my $spans = "";
    my $current_loc = $start;
    if($matchstring =~ /^(\d+)S/) {
        $matchstring =~ s/^(\d+)S//;
    }
    if($matchstring =~ /(\d+)S$/) {
        $matchstring =~ s/(\d+)S$//;
    }
    if($matchstring =~ /D/) {
        $matchstring =~ /(\d+)M(\d+)D(\d+)M/;
        my $l1 = $1;
        my $l2 = $2;
        my $l3 = $3;
        my $L = $1 + $2 + $3;
        $L = $L . "M";
        $matchstring =~ s/\d+M\d+D\d+M/$L/;

    }
    while($matchstring =~ /^(\d+)([^\d])/) {
        my $num = $1;
        my $type = $2;
        if($type eq 'M') {
            my $E = $current_loc + $num - 1;
            if($spans =~ /\S/) {
                $spans = $spans . ", " .  $current_loc . "-" . $E;
            } else {
                $spans = $current_loc . "-" . $E;
            }
            $current_loc = $E;
        }
        if($type eq 'D' || $type eq 'N') {
            $current_loc = $current_loc + $num + 1;
        }
        if($type eq 'I') {
            $current_loc++;
        }
        $matchstring =~ s/^\d+[^\d]//;
    }
    my $spans2 = "";
    while($spans2 ne $spans) {
        $spans2 = $spans;
        my @b = split(/, /, $spans);
        for(my $i=0; $i<@b-1; $i++) {
            my @c1 = split(/-/, $b[$i]);
            my @c2 = split(/-/, $b[$i+1]);
            if($c1[1] + 1 >= $c2[0]) {
                my $str = "-$c1[1], $c2[0]";
                $spans =~ s/$str//;
            }
        }
    }
    return $spans;
}

# The *Starts and *Ends variables are references to arrays of starts and ends
# for one transcript and one read respectively. 
# Coordinates are assumed to be 1-based/right closed.
sub checkCompatibility {
  my ($txChr, $txStarts, $txEnds, $readChr, $readStarts, $readEnds) = @_;
  my $singleSegment  = scalar(@{$readStarts})==1 ? 1: 0;
  my $singleExon = scalar(@{$txStarts})==1 ? 1 : 0;

  # Check whether read overlaps transcript
  if ($txChr ne $readChr || $readEnds->[scalar(@{$readEnds})-1]<$txStarts->[0] || $readStarts->[0]>$txEnds->[scalar(@{$txEnds})-1]) {
#    print STDERR  "Read does not overlap transcript\n";
    return(0);
  }
  
  # Check whether read stradles transcript
  elsif (!$singleSegment) {
    my $stradle;
    for (my $i=0; $i<scalar(@{$readStarts})-1; $i++) {
      if ($readEnds->[$i]<$txStarts->[0] && $readStarts->[$i+1]>$txEnds->[scalar(@{$txEnds})-1]) {
	$stradle = 1;
	last;
      }
    }
    if ($stradle) {
#      print STDERR  "Read stradles transcript\n";
      return(0);
    }
    elsif ($singleExon) {
#      print STDERR "Transcript has one exon but read has more than one segment\n";
      return(0);
    }
    else {
      my $readJunctions = &getJunctions($readStarts, $readEnds);
      my $txJunctions = &getJunctions($txStarts, $txEnds);
      my ($intronStarts, $intronEnds) = &getIntrons($txStarts, $txEnds);
      my $intron = &overlaps($readStarts, $readEnds, $intronStarts, $intronEnds );
      my $compatible = &compareJunctions($txJunctions, $readJunctions);
      if (!$intron && $compatible) {
#	print STDERR "Read is compatible with transcript\n";
	return(1);
      }
      else{
#	print STDERR "Read overlaps intron(s) or is incompatible with junctions\n";
	return(0);
      }
    }
  }
  else {
    my $intron = 0;
    if (!$singleExon) {
      my ($intronStarts, $intronEnds) = &getIntrons($txStarts, $txEnds);
      $intron = &overlaps($readStarts, $readEnds, $intronStarts, $intronEnds ); 
    }
    my $compatible = &compareSegments($txStarts, $txEnds, $readStarts->[0], $readEnds->[0]);
    if (!$intron && $compatible) {
#      print STDERR "Read is compatible with transcript\n";
      return(1);
    }
    else{
#      print STDERR "Read overlaps intron(s) or is incompatible with junctions\n";
      return(0);
    }
  }
}

sub getJunctions {
  my ($starts, $ends) = @_;
  my $junctions = "s: $ends->[0], e: $starts->[1]";
  for (my $i=1; $i<@{$ends}-1; $i++) {
    $junctions .= ", s: $ends->[$i], e: $starts->[$i+1]";
  }
  return($junctions);
}

sub getIntrons {
  my ($txStarts, $txEnds) = @_;
  my ($intronStarts, $intronEnds);
  for (my $i=0; $i<@{$txStarts}-1; $i++) {
    push(@{$intronStarts}, $txEnds->[$i]+1);
    push(@{$intronEnds}, $txStarts->[$i+1]-1);
  }
  return($intronStarts, $intronEnds);
}

sub overlaps {
  my ($starts1, $ends1, $starts2, $ends2) = @_;
  my $overlap = 0;

  if (!($ends1->[@{$ends1}-1]<$starts2->[0]) && !($ends2->[@{$ends2}-1]<$starts1->[0])) {
    for (my $i=0; $i<@{$starts1}; $i++) {
      for (my $j=0; $j<@{$starts2}; $j++) {
	if ($starts1->[$i]<$ends2->[$j] && $starts2->[$j]<$ends1->[$i]) {
	  $overlap =  1;
	  last;
	}
      }
    }
  }
  return($overlap);
}

sub compareJunctions {
  my ($txJunctions, $readJunctions) = @_;
  my $compatible = 0; 
  if (index($txJunctions, $readJunctions)!=-1) {
    $compatible = 1;
  } 
  return($compatible);
}

sub compareSegments {
  my ($txStarts, $txEnds, $readStart, $readEnd) = @_;
  my $compatible = 0;
  for (my $i=0; $i<scalar(@{$txStarts}); $i++) {
    if ($readStart>=$txStarts->[$i] && $readEnd<=$txEnds->[$i] ) {
      $compatible = 1;
      last;
    }
  }
  return($compatible);
}
