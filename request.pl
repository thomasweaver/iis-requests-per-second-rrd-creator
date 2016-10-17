#!/usr/bin/perl
use DateTime;
use Getopt::Long;

$rrdtool = "/usr/bin/rrdtool";
$createOptions = "";
$rrdGraphOptions = "";
$startEpoch = "1352417451";

#Get the options
GetOptions (
		"logFile=s" => \$logFile,
		"imageFileName=s" => \$imageFileName,
		"rrdfile=s" => \$rrdfile,
		"rrdtool:s" => \$rrdTool,
		"createOptions:s" => \$createOptions,
		"rrdGraphOptions:s" => \$rrdGraphOptions,
		"createRRD"	=> \$createRRD,
		"startEPOCH:i" => \$startEpoch
) or die("Error in command line arguements\n");

#print help if required values aren't given
if($logFile eq "" || $imageFileName eq "" || $rrdfile eq "") {
	print "You must specify logfile, imageFileName and rrdfile \n";
	print "Create an rrd file and graph of requests per second from an IIS logfile

OPTIONS:
	REQUIRED:
		logFile - Specify the IIS log file to Parse
		imageFileName - Specify the name of the output graph image
		rrdfile - The RRD filename to use
	
	OPTIONAL:
		rrdtool - The full path for your rrdtool (DEFAULT: /usr/bin/rrdtool)
		createOptions - Specify any additional options to use during the RRD creation
		rrdGraphOptions - Specify any extra options to pass to RRD graph command
		createRRD - Specify to create an RRD file.
		startEPOCH - Specify an epoch date time the RRD file should start at

EXAMPLES:

	./request.pl --logFile iislog.log --imageFileName test1.png --rrdfile test1.rrd
";
	exit(2);
}

#Open Log File
open(MYFILE, $logFile);

if($createRRD){
	#Create RRD file if requested. with the start epoch and default values. Default keep 1 years worth of data	
	my $result = system("$rrdtool create $rrdfile --start $startEpoch $createOptions --step 1 DS:requestsPerSec:ABSOLUTE:100:0:U RRA:MAX:0.9:1:31557600");
}
my %times;

#Parse log file
while(<MYFILE>) {
	chome;

	#get date in format yyyy-mm-dd hh:mm:ss
	$_ =~ /^([0-9]{4}-[0-9]{2}-[0-9]{2} \d{2}:\d{2}:\d{2})/;

	$time =$1;
	#replace : in time
	$time =~ s/://g;

	if(exists($times{$time})) {
		#If we have seen this second before then increment it by 1
		$times{$time}++;
	}
	else {
		#If we haven't seen this before then requests are 1
		$times{$time} = 1;
	}
}
close(MYFILE);


foreach $key (sort(keys %times)) {
	#Loop through the new hash table and convert time to epoch time
	$hour= "";
	$minute = "";
	$seconds ="";

	#Split up timestamp into year, month, day, hour, minutes, seconds
	$key =~ /([0-9]{4})-([0-9]{2})-([0-9]{2}) (\d{2})(\d{2})(\d{2})/;
		
	$year = $1;
	$month = $2;
	$day = $3;
	$hour = $4;
	$minute = $5;
	$seconds = $6;

	#Check to make sure its a valid time
	if($seconds > 60) {
		print "Seconds is over 60 " . $seconds . " " . $key."\n";
		$hour = ""; 
	}

	#We can only create a date time object if we have all the sections of the timestamp
	if($hour ne "" && $minute ne "" && $seconds ne "") {
		#Create date time object so we can convert it to epoch
		$dt = DateTime->new(
				year	=> $year,
				month	=> $month,
				day		=> $day,
				hour	=> $hour,
				minute	=> $minute,
				second	=> $seconds,
				nanosecond	=> 0,
				time_zone	=> 'Europe/London',
			);
		$time = $dt->epoch();
		$value = $times{$key};

		#Build new hash tbale with epoch times
		$newTimes{$time} = $value;
	}
	else {
		print "$hour $minute $seconds skipped \n";
	}

}

#GEt the epoch keys
my @keys = sort(keys %newTimes);

#Get first and last epoch time
$startTime = $keys[1];
$endTime = $keys[-1];

#Loop through and replace any missing epochs as this means we had no requests in this second.
#This produces nicer graphs and means the RRD file is fully populated 
for($i=0; $i < ($endTime - $startTime +1); $i++) {
	$thisTime = $startTime + $i;

	#If this epoch doesn't exists in the hash table then we received 0 requests in this second
	if(!exists($newTimes{$thisTime})) {
		$value =0;
	}
	else {
		$value = $newTimes{$thisTime};
	}

	#Add the value to the RRD file using the epoch
    $command = "$rrdtool update $rrdfile $thisTime:$value";
    $result = system($command);
}

#Build graph RRD Tool command
$graphCommand = "$rrdtool graph $imageFileName $rrdGraphOptions --start $startTime --end $endTime DEF:ds0=$rrdfile:requestsPerSec:MAX:step=1 AREA:ds0#ffff00:\"Requests Per Second\l\" LINE3:ds0#000000 VDEF:ds0max=ds0,MAXIMUM VDEF:ds0min=ds0,MINIMUM VDEF:ds0avg=ds0,AVERAGE GPRINT:ds0avg:\"AVG %6.0lf\" GPRINT:ds0min:\"MIN %6.0lf\" GPRINT:ds0max:\"MAX %6.0lf\"";

#Perform command 
system($graphCommand);