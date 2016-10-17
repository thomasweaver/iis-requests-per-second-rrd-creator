# iis-requests-per-second-rrd-creator

RRD Requests Per Second Creator
===============================

This script will parse your log file count the number of requests in each second and then add the results to an RRD file and produce a graph from that RRD file.

For this script to work the log file needs to be in the W3c standard format and so each line needs to start with a timestamp in the format yyyy-mm-dd hh:MM:ss.


Example:
========

The below example will parse the log file “iislog.log”, create a graph named test.png. The –createRRD is specified and so the test.rrd file will be created with a start time of  1320859514. The graph will be 500px wide and 300px high with a title of “Requests Per Second”
./request.pl --logfile iislog.log --imageFileName test.png --rrdfile "test.rrd" --rrdGraphOptions "\-\-width 500 \-\-height 300 \-\-title 'Requests Per Second'" --createRRD --startEPOCH 1320859514
